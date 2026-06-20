import Foundation

enum GoogleHealthError: Error, LocalizedError {
    case invalidURL
    case authenticationRequired
    case decodingFailed
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL generated."
        case .authenticationRequired: return "Authentication is required."
        case .decodingFailed: return "Failed to decode the response from Google Health."
        case .apiError(let message): return "API Error: \(message)"
        }
    }
}

class GoogleHealthService: HealthDataProvider {
    private let baseURL = "https://health.googleapis.com/v4/users/me/dataTypes"
    private let authManager: AuthManager

    init(authManager: AuthManager = .shared) {
        self.authManager = authManager
    }

    func fetchDataPoints(for dataType: HealthDataType, from startDate: Date, to endDate: Date) async throws -> [HealthDataPoint] {
        print("📡 Fetching \(dataType.rawValue)...")

        guard let token = try await authManager.getAccessToken() else {
            throw GoogleHealthError.authenticationRequired
        }

        let urlComponents = URLComponents(string: "\(baseURL)/\(dataType.rawValue)/dataPoints")!
        guard let url = urlComponents.url else { throw GoogleHealthError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleHealthError.apiError("Invalid response")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "No body"
            throw GoogleHealthError.apiError("HTTP \(httpResponse.statusCode): \(body)")
        }

        // --- VERBOSE LOGGING ---
        let ignoreList: [HealthDataType] = [.dailyRestingHeartRate, .respiratoryRate, .dailyHeartRateVariability]
        if !ignoreList.contains(dataType) {
            let rawResponseString = String(data: data, encoding: .utf8) ?? "<unreadable>"
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📡 [GoogleHealthService] \(dataType.rawValue)")
            print("📦 Raw Response:")
            print(rawResponseString)
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
        // --- END VERBOSE LOGGING ---

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rawPoints = json["dataPoints"] as? [[String: Any]] else {
                print("⚠️ [\(dataType.rawValue)] No dataPoints array in response")
                return []
            }

            // Cumulative types: the API sends per-minute granular rows that must be summed by day.
            // Averaged types: per-minute readings that should be averaged (e.g., heart rate bpm).
            // Scalar types: each data point is already a daily aggregate; keep the best (Fitbit preferred).
            let cumulativeTypes: Set<HealthDataType> = [
                .activeEnergyBurned, .steps, .distance, .activeZoneMinutes
            ]
            let averagedTypes: Set<HealthDataType> = [.heartRate]
            let isCumulative = cumulativeTypes.contains(dataType)
            let isAveraged = averagedTypes.contains(dataType)

            // For cumulative/averaged types, accumulate values per day.
            var sumByDate: [String: Double] = [:]
            var countByDate: [String: Int] = [:]
            // For all types, store one representative point for date/source metadata.
            var bestByDate: [String: HealthDataPoint] = [:]

            for raw in rawPoints {
                guard let (value, date) = extractValue(from: raw, for: dataType) else { continue }

                let src = raw["dataSource"] as? [String: Any]
                let isFitbit = (src?["platform"] as? String) == "FITBIT"
                    && (src?["recordingMethod"] as? String) == "DERIVED"
                let sourceLabel = isFitbit ? "Fitbit" : "HealthKit"
                let key = Self.calendarKey(for: date)

                if isCumulative || isAveraged {
                    sumByDate[key, default: 0] += value
                    countByDate[key, default: 0] += 1
                    if bestByDate[key] == nil {
                        bestByDate[key] = HealthDataPoint(
                            type: dataType,
                            value: 0,  // placeholder; replaced in result-building step
                            startTime: date,
                            endTime: date,
                            source: sourceLabel
                        )
                    }
                } else {
                    let point = HealthDataPoint(
                        type: dataType,
                        value: value,
                        startTime: date,
                        endTime: date,
                        source: sourceLabel
                    )
                    if let existing = bestByDate[key] {
                        if existing.source != "Fitbit" && isFitbit {
                            bestByDate[key] = point
                        }
                    } else {
                        bestByDate[key] = point
                    }
                }
            }

            // Build final result array.
            var result: [HealthDataPoint]
            if isCumulative || isAveraged {
                result = sumByDate.compactMap { (key, total) -> HealthDataPoint? in
                    guard let meta = bestByDate[key] else { return nil }
                    let finalValue: Double
                    if isAveraged, let count = countByDate[key], count > 0 {
                        finalValue = total / Double(count)  // average for HR
                    } else {
                        finalValue = total  // sum for calories/steps/distance/AZM
                    }
                    return HealthDataPoint(
                        type: dataType,
                        value: finalValue,
                        startTime: meta.startTime,
                        endTime: meta.endTime,
                        source: meta.source
                    )
                }.sorted { $0.startTime > $1.startTime }
            } else {
                result = bestByDate.values.sorted { $0.startTime > $1.startTime }
            }

            let strategy = isCumulative ? "summed" : (isAveraged ? "averaged" : "best-per-day")
            print("✅ [\(dataType.rawValue)] \(result.count) daily point(s) | \(strategy)")
            return result

        } catch {
            print("❌ [\(dataType.rawValue)] Decode failed: \(error)")
            throw GoogleHealthError.decodingFailed
        }
    }

    func fetchReconciledDataPoints(for dataType: HealthDataType, from startDate: Date, to endDate: Date) async throws -> [HealthDataPoint] {
        return []
    }

    func fetchSleepData(from startDate: Date, to endDate: Date) async throws -> SleepData? {
        print("📡 Fetching sleep data...")
        let rawPoints = try await fetchRawSleepPoints()

        // Sort newest first and pick the best Fitbit-derived record, falling back to any record.
        let sorted = rawPoints.sorted { dict1, dict2 in
            let d1 = (dict1["sleep"] as? [String: Any])?["createTime"] as? String ?? ""
            let d2 = (dict2["sleep"] as? [String: Any])?["createTime"] as? String ?? ""
            return d1 > d2
        }
        guard let best = sorted.first(where: isFitbitDerived) ?? sorted.first else { return nil }
        return parseSleepData(from: best)
    }

    func fetchSleepDataPoints(from startDate: Date, to endDate: Date) async throws -> [HealthDataPoint] {
        print("📡 Fetching sleep data points for trends...")
        let rawPoints = try await fetchRawSleepPoints()

        // One SleepData per calendar day (wake-day), preferring Fitbit-derived records.
        var bestByDay: [String: [String: Any]] = [:]
        for raw in rawPoints {
            guard let sleepNode = raw["sleep"] as? [String: Any],
                  let interval = sleepNode["interval"] as? [String: Any],
                  let endTimeStr = interval["endTime"] as? String,
                  let wakeDate = parseISO8601(endTimeStr) else { continue }

            let dayKey = Self.calendarKey(for: wakeDate)
            if let existing = bestByDay[dayKey] {
                // Prefer Fitbit-derived over HealthKit
                if !isFitbitDerived(existing) && isFitbitDerived(raw) {
                    bestByDay[dayKey] = raw
                }
            } else {
                bestByDay[dayKey] = raw
            }
        }

        return bestByDay.values.compactMap { raw -> HealthDataPoint? in
            guard let sleep = parseSleepData(from: raw) else { return nil }
            return HealthDataPoint(
                type: .sleep,
                value: sleep.totalTimeAsleep,   // seconds; Trends formats as "Xh Ym"
                startTime: sleep.date,
                endTime: sleep.wakeTime,
                source: isFitbitDerived(raw) ? "Fitbit" : "HealthKit"
            )
        }.sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Sleep Shared Helpers

    /// Fetches all raw sleep dataPoints from the Google Health API.
    private func fetchRawSleepPoints() async throws -> [[String: Any]] {
        guard let token = try await authManager.getAccessToken() else {
            throw GoogleHealthError.authenticationRequired
        }
        let urlComponents = URLComponents(string: "\(baseURL)/sleep/dataPoints")!
        guard let url = urlComponents.url else { throw GoogleHealthError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else { return [] }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawPoints = json["dataPoints"] as? [[String: Any]] else { return [] }
        return rawPoints
    }

    /// Returns true if this raw data-point dict is from a Fitbit DERIVED source.
    private func isFitbitDerived(_ dict: [String: Any]) -> Bool {
        let src = dict["dataSource"] as? [String: Any]
        return (src?["platform"] as? String) == "FITBIT"
            && (src?["recordingMethod"] as? String) == "DERIVED"
    }

    /// Parses a single raw sleep data-point dict into a `SleepData` struct.
    private func parseSleepData(from raw: [String: Any]) -> SleepData? {
        guard let sleepNode = raw["sleep"] as? [String: Any],
              let summary  = sleepNode["summary"] as? [String: Any],
              let interval = sleepNode["interval"] as? [String: Any] else { return nil }

        let bedTime     = parseISO8601(interval["startTime"] as? String) ?? Date()
        let wakeTime    = parseISO8601(interval["endTime"] as? String) ?? Date()
        let sessionDate = Calendar.current.startOfDay(for: wakeTime)

        let minInBed   = doubleFromStringOrNumber(summary["minutesInSleepPeriod"]) ?? 0
        let minAsleep  = doubleFromStringOrNumber(summary["minutesAsleep"]) ?? 0
        let minAwake   = doubleFromStringOrNumber(summary["minutesAwake"]) ?? 0

        var lightMin = 0.0
        var deepMin  = 0.0
        var remMin   = 0.0

        if let stages = summary["stagesSummary"] as? [[String: Any]] {
            for stage in stages {
                let type = stage["type"] as? String ?? ""
                let min  = doubleFromStringOrNumber(stage["minutes"]) ?? 0
                switch type {
                case "LIGHT": lightMin = min
                case "DEEP":  deepMin  = min
                case "REM":   remMin   = min
                default: break
                }
            }
        }

        return SleepData(
            date: sessionDate,
            bedTime: bedTime,
            wakeTime: wakeTime,
            totalTimeInBed: minInBed * 60,
            totalTimeAsleep: minAsleep * 60,
            awakeTime: minAwake * 60,
            lightSleepTime: lightMin * 60,
            remSleepTime: remMin * 60,
            deepSleepTime: deepMin * 60,
            sleepNeed: 8 * 3600
        )
    }

    /// Parses an ISO 8601 timestamp string, handling both fractional-seconds and plain variants.
    private func parseISO8601(_ str: String?) -> Date? {
        guard let str = str else { return nil }
        let full = ISO8601DateFormatter()
        full.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = full.date(from: str) { return d }
        let basic = ISO8601DateFormatter()
        return basic.date(from: str)
    }

    // MARK: - Type-Specific Value Extraction

    /// Extracts the biometric value and its associated calendar date from a raw API data point dict.
    /// Each data type has its own JSON structure from the Google Health API.
    private func extractValue(from point: [String: Any], for dataType: HealthDataType) -> (value: Double, date: Date)? {
        switch dataType {

        case .dailyRestingHeartRate:
            // Structure: { "dailyRestingHeartRate": { "date": {...}, "beatsPerMinute": "70" } }
            // NOTE: beatsPerMinute is returned as a String by this API.
            guard let rhr = point["dailyRestingHeartRate"] as? [String: Any],
                  let date = parseSimpleDate(rhr["date"] as? [String: Any]) else { return nil }
            let bpm = doubleFromStringOrNumber(rhr["beatsPerMinute"])
            guard let v = bpm else { return nil }
            return (v, date)

        case .dailyHeartRateVariability:
            // Structure: { "heartRateVariability": { "sampleTime": {...}, "rootMeanSquareOfSuccessiveDifferencesMilliseconds": 46.7 } }
            guard let hrv = point["heartRateVariability"] as? [String: Any] else { return nil }
            // Prefer RMSSD; fall back to SDNN if zero or missing
            let rmssd = hrv["rootMeanSquareOfSuccessiveDifferencesMilliseconds"] as? Double
            let sdnn  = hrv["standardDeviationMilliseconds"] as? Double
            guard let v = (rmssd.flatMap { $0 > 0 ? $0 : nil }) ?? sdnn, v > 0 else { return nil }
            let date = parseSampleTimeDate(hrv["sampleTime"] as? [String: Any]) ?? Date()
            return (v, date)

        case .respiratoryRate:
            // Structure: { "dailyRespiratoryRate": { "date": {...}, "breathsPerMinute": 14.6 } }
            guard let resp = point["dailyRespiratoryRate"] as? [String: Any],
                  let date = parseSimpleDate(resp["date"] as? [String: Any]) else { return nil }
            let bpm = doubleFromStringOrNumber(resp["breathsPerMinute"])
            guard let v = bpm else { return nil }
            return (v, date)

        case .activeEnergyBurned:
            // Structure: { "activeEnergyBurned": { "interval": { "civilStartTime": { "date": {...} } }, "kcal": 1.89 } }
            guard let node = point["activeEnergyBurned"] as? [String: Any],
                  let kcal = doubleFromStringOrNumber(node["kcal"]),
                  let date = parseCivilDate(from: node["interval"] as? [String: Any]) else { return nil }
            return (kcal, date)

        case .steps:
            // Structure: { "steps": { "interval": { "civilStartTime": { "date": {...} } }, "count": 120 } }
            guard let node = point["steps"] as? [String: Any],
                  let count = doubleFromStringOrNumber(node["count"]),
                  let date = parseCivilDate(from: node["interval"] as? [String: Any]) else { return nil }
            return (count, date)

        case .distance:
            // Structure: { "distance": { "interval": { "civilStartTime": { "date": {...} } }, "meters": 45.6 } }
            guard let node = point["distance"] as? [String: Any],
                  let meters = doubleFromStringOrNumber(node["meters"]),
                  let date = parseCivilDate(from: node["interval"] as? [String: Any]) else { return nil }
            return (meters, date)

        case .heartRate:
            // Structure: { "heartRate": { "interval": { "civilStartTime": { "date": {...} } }, "bpm": 72 } }
            guard let node = point["heartRate"] as? [String: Any],
                  let bpm = doubleFromStringOrNumber(node["bpm"]),
                  let date = parseCivilDate(from: node["interval"] as? [String: Any]) else { return nil }
            return (bpm, date)

        case .activeZoneMinutes:
            // Structure: { "activeZoneMinutes": { "interval": { "civilStartTime": { "date": {...} } }, "fatBurnActiveZoneMinutes": 5, "cardioActiveZoneMinutes": 10, "peakActiveZoneMinutes": 2 } }
            guard let node = point["activeZoneMinutes"] as? [String: Any],
                  let date = parseCivilDate(from: node["interval"] as? [String: Any]) else { return nil }
            let fat     = doubleFromStringOrNumber(node["fatBurnActiveZoneMinutes"]) ?? 0
            let cardio  = doubleFromStringOrNumber(node["cardioActiveZoneMinutes"]) ?? 0
            let peak    = doubleFromStringOrNumber(node["peakActiveZoneMinutes"]) ?? 0
            let total   = fat + cardio + peak
            return (total, date)

        default:
            // Generic fallback for unmapped types: scan nested dicts for fpVal/intVal (legacy Google Fit format).
            if let value = findFpOrIntVal(in: point),
               let date = parseCivilDateFromAnyInterval(in: point) {
                return (value, date)
            }
            return nil
        }
    }

    /// Extracts the calendar date from `interval.civilStartTime.date` in a typed data-point node.
    private func parseCivilDate(from interval: [String: Any]?) -> Date? {
        guard let interval = interval,
              let civilStart = interval["civilStartTime"] as? [String: Any],
              let dateDict   = civilStart["date"] as? [String: Any] else { return nil }
        return parseSimpleDate(dateDict)
    }

    /// Walks top-level keys to find an `interval` dict and delegates to `parseCivilDate`.
    private func parseCivilDateFromAnyInterval(in point: [String: Any]) -> Date? {
        for value in point.values {
            if let nested = value as? [String: Any],
               let date = parseCivilDate(from: nested["interval"] as? [String: Any]) {
                return date
            }
        }
        return nil
    }

    private func findFpOrIntVal(in dict: [String: Any]) -> Double? {
        if let fpVal = dict["fpVal"] as? Double { return fpVal }
        if let intVal = dict["intVal"] as? Int { return Double(intVal) }

        for value in dict.values {
            if let nested = value as? [String: Any] {
                if let found = findFpOrIntVal(in: nested) {
                    return found
                }
            } else if let array = value as? [[String: Any]] {
                for item in array {
                    if let found = findFpOrIntVal(in: item) {
                        return found
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Date Parsing Helpers

    private func parseSimpleDate(_ dict: [String: Any]?) -> Date? {
        guard let d = dict,
              let year  = d["year"]  as? Int,
              let month = d["month"] as? Int,
              let day   = d["day"]   as? Int else { return nil }
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        return Calendar.current.date(from: comps)
    }

    private func parseSampleTimeDate(_ sampleTime: [String: Any]?) -> Date? {
        guard let civilTime = sampleTime?["civilTime"] as? [String: Any],
              let dateDict  = civilTime["date"] as? [String: Any] else { return nil }
        return parseSimpleDate(dateDict)
    }

    /// Safely converts a value that may be a String, Int, or Double to Double.
    private func doubleFromStringOrNumber(_ raw: Any?) -> Double? {
        if let d = raw as? Double  { return d }
        if let i = raw as? Int     { return Double(i) }
        if let s = raw as? String  { return Double(s) }
        return nil
    }

    private static func calendarKey(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}
