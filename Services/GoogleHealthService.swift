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

        var url = URL(string: "\(baseURL)/\(dataType.rawValue)/dataPoints")!
        let filter = filterString(for: dataType, from: startDate, to: endDate)
        
        var rawPoints = try await fetchAllPages(for: url, token: token, filter: filter)

        // Fallback for HRV: if daily-heart-rate-variability returns nothing, try heart-rate-variability
        if dataType == .dailyHeartRateVariability && rawPoints.isEmpty {
            print("⚠️ daily-heart-rate-variability returned 0 points. Trying fallback to heart-rate-variability...")
            let fallbackRaw = "heart-rate-variability"
            if let fallbackURL = URL(string: "\(baseURL)/\(fallbackRaw)/dataPoints") {
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime]
                let startDateStr = isoFormatter.string(from: startDate)
                let endDateStr = isoFormatter.string(from: endDate)
                let fallbackFilter = "heart_rate_variability.sample_time.physical_time >= \"\(startDateStr)\" AND heart_rate_variability.sample_time.physical_time < \"\(endDateStr)\""
                
                do {
                    let fallbackPoints = try await fetchAllPages(for: fallbackURL, token: token, filter: fallbackFilter)
                    if !fallbackPoints.isEmpty {
                        rawPoints = fallbackPoints
                        print("✅ Found \(rawPoints.count) raw points from heart-rate-variability")
                    }
                } catch {
                    print("⚠️ Fallback to heart-rate-variability failed: \(error.localizedDescription)")
                }
            }
        }

        // --- VERBOSE LOGGING ---
        let ignoreList: [HealthDataType] = [.dailyRestingHeartRate, .respiratoryRate]
        if !ignoreList.contains(dataType) {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📡 [GoogleHealthService] \(dataType.rawValue)")
            print("📦 Raw Response: Received \(rawPoints.count) raw data points")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
        // --- END VERBOSE LOGGING ---

            // Special handling for intraday heartRate: no daily averaging or grouping
            if dataType == .heartRate {
                var hrPoints: [HealthDataPoint] = []
                for raw in rawPoints {
                    guard let (value, date) = extractValue(from: raw, for: dataType) else { continue }
                    let src = raw["dataSource"] as? [String: Any]
                    let isFitbit = (src?["platform"] as? String) == "FITBIT"
                    guard isFitbit else { continue }
                    
                    hrPoints.append(HealthDataPoint(
                        type: dataType,
                        value: value,
                        startTime: date,
                        endTime: date,
                        source: "Fitbit"
                    ))
                }
                // Sort newest first (descending)
                let sortedPoints = hrPoints.sorted { $0.startTime > $1.startTime }
                print("✅ [\(dataType.rawValue)] \(sortedPoints.count) raw point(s)")
                return sortedPoints
            }

            // Cumulative types: the API sends per-minute granular rows that must be summed by day.
            // Averaged types: per-minute readings that should be averaged (e.g., resting heart rate / other aggregates if any).
            // Scalar types: each data point is already a daily aggregate; keep the best (Fitbit preferred).
            let cumulativeTypes: Set<HealthDataType> = [
                .activeEnergyBurned, .steps, .distance, .activeZoneMinutes
            ]
            let averagedTypes: Set<HealthDataType> = [] // heartRate removed to support raw intraday values
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
                guard isFitbit else { continue }
                
                let sourceLabel = "Fitbit"
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
                        finalValue = total / Double(count)
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
    }

    func fetchReconciledDataPoints(for dataType: HealthDataType, from startDate: Date, to endDate: Date) async throws -> [HealthDataPoint] {
        return []
    }

    func fetchSleepData(from startDate: Date, to endDate: Date) async throws -> SleepData? {
        print("📡 Fetching sleep data...")
        let rawPoints = try await fetchRawSleepPoints(from: startDate, to: endDate)

        // Filter sleep points to only those that represent a nocturnal/main sleep (duration >= 3 hours).
        let sleepSessions = rawPoints
            .filter { isFitbitDerived($0) }
            .compactMap { parseSleepData(from: $0) }
            .filter { Self.sleepSession($0, overlapsStart: startDate, end: endDate) }
        let validSessions = sleepSessions.filter { $0.totalTimeAsleep >= 10800 } // 3 hours
        
        // Pick the one with the maximum duration (longest sleep)
        return validSessions.max(by: { $0.totalTimeAsleep < $1.totalTimeAsleep })
    }

    func fetchAllSleepSessions(from startDate: Date, to endDate: Date) async throws -> [SleepData] {
        print("📡 Fetching all sleep sessions...")
        let rawPoints = try await fetchRawSleepPoints(from: startDate, to: endDate)
        return rawPoints
            .filter { isFitbitDerived($0) }
            .compactMap { parseSleepData(from: $0) }
            .filter { Self.sleepSession($0, overlapsStart: startDate, end: endDate) }
    }

    func fetchExerciseSessions(from startDate: Date, to endDate: Date) async throws -> [ActivitySession] {
        print("📡 Fetching exercise sessions...")
        guard let token = try await authManager.getAccessToken() else {
            throw GoogleHealthError.authenticationRequired
        }
        
        let url = URL(string: "\(baseURL)/exercise/dataPoints")!
        let filter = filterString(for: .exercise, from: startDate, to: endDate)
        let rawPoints = try await fetchAllPages(for: url, token: token, filter: filter)
        
        var activities: [ActivitySession] = []
        for raw in rawPoints {
            guard let exerciseNode = raw["exercise"] as? [String: Any],
                  let interval = exerciseNode["interval"] as? [String: Any],
                  let name = exerciseNode["exerciseType"] as? String else { continue }
            
            let start = parseIntervalDate(from: interval) ?? Date()
            
            var duration: TimeInterval = 0
            if let endStr = interval["endTime"] as? String, let end = parseISO8601(endStr) {
                duration = end.timeIntervalSince(start)
            } else if let endStr = interval["physicalEndTime"] as? String, let end = parseISO8601(endStr) {
                duration = end.timeIntervalSince(start)
            }
            
            let calories = doubleFromStringOrNumber(exerciseNode["caloriesBurned"]) ?? 0
            let avgHR = doubleFromStringOrNumber(exerciseNode["averageHeartRate"]) ?? 0
            let maxHR = doubleFromStringOrNumber(exerciseNode["maxHeartRate"]) ?? 0
            
            // Generate arbitrary activity strain for visual purposes or real computation later
            let strain = (duration / 60) * 0.2 + (avgHR > 100 ? (avgHR - 100) * 0.1 : 0)
            
            activities.append(ActivitySession(
                name: name.capitalized.replacingOccurrences(of: "_", with: " "),
                startTime: start,
                duration: duration,
                activityStrain: min(21.0, strain),
                caloriesBurned: calories,
                averageHR: avgHR,
                maxHR: maxHR
            ))
        }
        
        return activities.sorted { $0.startTime > $1.startTime }
    }

    func fetchSleepDataPoints(from startDate: Date, to endDate: Date) async throws -> [HealthDataPoint] {
        print("📡 Fetching sleep data points for trends...")
        let rawPoints = try await fetchRawSleepPoints(from: startDate, to: endDate)

        // Group by wake-day key
        var bestByDay: [String: (sleep: SleepData, source: String)] = [:]
        for raw in rawPoints {
            guard isFitbitDerived(raw) else { continue }
            guard let parsed = parseSleepDataAndSource(from: raw) else { continue }
            guard Self.sleepSession(parsed.sleep, overlapsStart: startDate, end: endDate) else { continue }
            // Filter out naps (less than 3 hours)
            guard parsed.sleep.totalTimeAsleep >= 10800 else { continue }
            
            let dayKey = Self.calendarKey(for: parsed.sleep.date)
            if let existing = bestByDay[dayKey] {
                // Pick the longer sleep session
                if parsed.sleep.totalTimeAsleep > existing.sleep.totalTimeAsleep {
                    bestByDay[dayKey] = parsed
                }
            } else {
                bestByDay[dayKey] = parsed
            }
        }

        return bestByDay.values.map { item in
            HealthDataPoint(
                type: .sleep,
                value: item.sleep.totalTimeAsleep,
                startTime: item.sleep.date,
                endTime: item.sleep.wakeTime,
                source: item.source
            )
        }.sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Sleep Shared Helpers

    /// Fetches raw sleep dataPoints starting from startDate from the Google Health API.
    private func fetchRawSleepPoints(from startDate: Date, to endDate: Date) async throws -> [[String: Any]] {
        guard let token = try await authManager.getAccessToken() else {
            throw GoogleHealthError.authenticationRequired
        }
        let url = URL(string: "\(baseURL)/sleep/dataPoints")!

        // Google Health does not currently support filtering sleep by interval members.
        // Fetch the page set and constrain the requested range after parsing.
        let filter = sleepFilterString(from: startDate, to: endDate)
        return try await fetchAllPages(for: url, token: token, filter: filter)
    }

    /// Fetches all pages recursively for a Google Health API endpoint.
    private func fetchAllPages(for url: URL, token: String, filter: String?) async throws -> [[String: Any]] {
        var allPoints: [[String: Any]] = []
        var nextPageToken: String? = nil
        
        repeat {
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)!
            var queryItems = [
                URLQueryItem(name: "pageSize", value: "1000")
            ]
            if let filter {
                queryItems.insert(URLQueryItem(name: "filter", value: filter), at: 0)
            }
            if let pageToken = nextPageToken {
                queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
            urlComponents.queryItems = queryItems
            
            guard let requestURL = urlComponents.url else { throw GoogleHealthError.invalidURL }
            var request = URLRequest(url: requestURL)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GoogleHealthError.apiError("Invalid response")
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "No body"
                throw GoogleHealthError.apiError("HTTP \(httpResponse.statusCode): \(body)")
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw GoogleHealthError.decodingFailed
            }
            
            if let points = json["dataPoints"] as? [[String: Any]] {
                allPoints.append(contentsOf: points)
            }
            
            nextPageToken = json["nextPageToken"] as? String
        } while nextPageToken != nil
        
        return allPoints
    }

    /// Helper to format the AIP-160 filter parameter string for a specific data type and start date.
    private func filterString(for dataType: HealthDataType, from startDate: Date, to endDate: Date) -> String? {
        let snakeCaseName = dataType.rawValue.replacingOccurrences(of: "-", with: "_")
        
        if dataType == .heartRate ||
           dataType == .weight ||
           dataType == .bodyFat ||
           dataType == .vo2Max ||
           dataType == .coreBodyTemperature ||
           dataType == .skinTemperature ||
           dataType == .bloodPressure {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime]
            let startDateStr = isoFormatter.string(from: startDate)
            let endDateStr = isoFormatter.string(from: endDate)
            return "\(snakeCaseName).sample_time.physical_time >= \"\(startDateStr)\" AND \(snakeCaseName).sample_time.physical_time < \"\(endDateStr)\""
        } else if dataType.rawValue.hasPrefix("daily-") {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let startDateStr = dateFormatter.string(from: startDate)
            let endDateStr = dateFormatter.string(from: endDate)
            return "\(snakeCaseName).date >= \"\(startDateStr)\" AND \(snakeCaseName).date < \"\(endDateStr)\""
        } else if dataType == .exercise {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime]
            let startDateStr = isoFormatter.string(from: startDate)
            let endDateStr = isoFormatter.string(from: endDate)
            return "exercise.interval.end_time >= \"\(startDateStr)\" AND exercise.interval.end_time < \"\(endDateStr)\""
        } else {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime]
            let startDateStr = isoFormatter.string(from: startDate)
            let endDateStr = isoFormatter.string(from: endDate)
            return "\(snakeCaseName).interval.start_time >= \"\(startDateStr)\" AND \(snakeCaseName).interval.start_time < \"\(endDateStr)\""
        }
    }

    /// Google Health only supports sleep filtering by session end time.
    private func sleepFilterString(from startDate: Date, to endDate: Date) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let startDateStr = isoFormatter.string(from: startDate)
        let endDateStr = isoFormatter.string(from: endDate)
        return "sleep.interval.end_time >= \"\(startDateStr)\" AND sleep.interval.end_time < \"\(endDateStr)\""
    }

    /// Parses both SleepData and its source label.
    private func parseSleepDataAndSource(from raw: [String: Any]) -> (sleep: SleepData, source: String)? {
        guard let sleep = parseSleepData(from: raw) else { return nil }
        let source = isFitbitDerived(raw) ? "Fitbit" : "HealthKit"
        return (sleep, source)
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
        
        var apiScore: Int? = nil
        if let score = doubleFromStringOrNumber(sleepNode["sleepScore"]) ?? doubleFromStringOrNumber(summary["sleepScore"]) ?? doubleFromStringOrNumber(summary["score"]) {
            apiScore = Int(score)
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
            sleepNeed: 8 * 3600,
            apiScore: apiScore
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
            // Daily HRV can be returned as dailyHeartRateVariability, while legacy/sample HRV
            // responses use heartRateVariability.
            guard let hrv = (point["dailyHeartRateVariability"] as? [String: Any])
                    ?? (point["heartRateVariability"] as? [String: Any]) else { return nil }
            // Prefer RMSSD; fall back to SDNN if zero or missing
            let avgHrv = doubleFromStringOrNumber(hrv["averageHeartRateVariabilityMilliseconds"])
            let rmssd = doubleFromStringOrNumber(hrv["rootMeanSquareOfSuccessiveDifferencesMilliseconds"])
            let sdnn  = doubleFromStringOrNumber(hrv["standardDeviationMilliseconds"])
            let deepSleepRmssd = doubleFromStringOrNumber(hrv["deepSleepRootMeanSquareOfSuccessiveDifferencesMilliseconds"])
            
            guard let v = avgHrv ?? rmssd ?? sdnn ?? deepSleepRmssd, v > 0 else { return nil }
            guard let date = parseSimpleDate(hrv["date"] as? [String: Any])
                    ?? parseSampleTimeDate(hrv["sampleTime"] as? [String: Any]) else { return nil }
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
                  let date = parseIntervalDate(from: node["interval"] as? [String: Any]) else { return nil }
            return (kcal, date)

        case .steps:
            // Structure: { "steps": { "interval": { "civilStartTime": { "date": {...} } }, "count": 120 } }
            guard let node = point["steps"] as? [String: Any],
                  let count = doubleFromStringOrNumber(node["count"]),
                  let date = parseIntervalDate(from: node["interval"] as? [String: Any]) else { return nil }
            return (count, date)

        case .distance:
            // Structure: { "distance": { "interval": { "civilStartTime": { "date": {...} } }, "meters": 45.6 } }
            guard let node = point["distance"] as? [String: Any],
                  let meters = doubleFromStringOrNumber(node["meters"]),
                  let date = parseIntervalDate(from: node["interval"] as? [String: Any]) else { return nil }
            return (meters, date)

        case .heartRate:
            // Structure: { "heartRate": { "sampleTime": { "physicalTime": "..." }, "beatsPerMinute": 72 } }
            guard let node = point["heartRate"] as? [String: Any],
                  let bpm = doubleFromStringOrNumber(node["beatsPerMinute"]) ?? doubleFromStringOrNumber(node["bpm"]) else { return nil }

            let date = parseSampleTimeDate(node["sampleTime"] as? [String: Any])
                ?? parseIntervalDate(from: node["interval"] as? [String: Any])
            guard let date else { return nil }
            return (bpm, date)

        case .activeZoneMinutes:
            // Structure: { "activeZoneMinutes": { "interval": { "civilStartTime": { "date": {...} } }, "fatBurnActiveZoneMinutes": 5, "cardioActiveZoneMinutes": 10, "peakActiveZoneMinutes": 2 } }
            guard let node = point["activeZoneMinutes"] as? [String: Any],
                  let date = parseIntervalDate(from: node["interval"] as? [String: Any]) else { return nil }
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

    /// Extracts the best available start date from a Google Health interval.
    private func parseIntervalDate(from interval: [String: Any]?) -> Date? {
        if let civilDate = parseCivilDate(from: interval) {
            return civilDate
        }

        if let startTimeStr = interval?["startTime"] as? String,
           let date = parseISO8601(startTimeStr) {
            return date
        }

        if let startTimeStr = interval?["physicalStartTime"] as? String,
           let date = parseISO8601(startTimeStr) {
            return date
        }

        return nil
    }

    /// Walks top-level keys to find an `interval` dict and delegates to `parseCivilDate`.
    private func parseCivilDateFromAnyInterval(in point: [String: Any]) -> Date? {
        for value in point.values {
            if let nested = value as? [String: Any],
               let date = parseIntervalDate(from: nested["interval"] as? [String: Any]) {
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
        if let civilTime = sampleTime?["civilTime"] as? [String: Any],
           let dateDict  = civilTime["date"] as? [String: Any],
           let date = parseSimpleDate(dateDict) {
            return date
        }
        if let physicalTimeStr = sampleTime?["physicalTime"] as? String {
            return parseISO8601(physicalTimeStr)
        }
        return nil
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

    private static func sleepSession(_ sleep: SleepData, overlapsStart startDate: Date, end endDate: Date) -> Bool {
        sleep.wakeTime >= startDate && sleep.bedTime < endDate
    }
}
