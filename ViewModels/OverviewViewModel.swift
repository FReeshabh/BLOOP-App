import Foundation
import SwiftUI
import SwiftData

@MainActor
final class OverviewViewModel: ObservableObject {

    // MARK: - Published State

    @Published var recoveryScore: RecoveryScore?
    @Published var sleepData: SleepData?
    @Published var todayNaps: [SleepData] = []
    @Published var strainData: StrainData?

    // Overview metric cards
    @Published var currentHeartRate: Double?
    @Published var todayHeartRateData: [HealthDataPoint] = []
    @Published var restingHeartRate: Double?
    @Published var todaySteps: Int = 0
    @Published var activeZoneMinutes: Double = 0
    @Published var stressLevel: Double = 0  // 0–100 estimated from strain

    // Insights
    @Published var insightHeadline: String = "Analyzing your data"
    @Published var insightExplanation: String = "Connect your account or wear your device to get daily insights."

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Historical sync
    @Published var isSyncingHistoricalData: Bool = false
    @Published var showHistoricalSyncPrompt: Bool = false
    @Published var historicalSyncProgress: Double = 0.0

    // Date Selection
    @Published var selectedDate: Date = Date() {
        didSet {
            Task {
                // When date changes, we need to load data but we don't have modelContext here directly
                // So the View will observe this and call loadData.
            }
        }
    }

    // MARK: - Dependencies

    private let healthService: HealthDataProvider
    private let authManager: AuthManager
    private let recoveryEngine: RecoveryScoreEngine

    init(healthService: HealthDataProvider = GoogleHealthService(),
         authManager: AuthManager = .shared,
         recoveryEngine: RecoveryScoreEngine = RecoveryScoreEngine()) {
        self.healthService = healthService
        self.authManager = authManager
        self.recoveryEngine = recoveryEngine
    }

    // MARK: - Computed Scores

    /// Sleep quality as a 0–100 percentage (from SleepData.sleepPerformance).
    var sleepScore: Int {
        sleepData?.sleepPerformance ?? 0
    }

    /// Readiness / Recovery 0–100. (Now presented as Resilience in UI)
    var readinessScore: Int {
        recoveryScore?.score ?? 0
    }

    /// Load normalized to 0–100 from the 0–21 WHOOP scale.
    var loadScore: Int {
        guard let strain = strainData else { return 0 }
        return min(100, Int(round(strain.dayStrain / 21.0 * 100.0)))
    }

    /// Optimal load range based on recovery.
    var optimalLoadRange: ClosedRange<Double> {
        guard let recovery = recoveryScore else { return 40...60 }
        let base = Double(recovery.score)
        let low  = max(0, base * 0.55)
        let high = min(100, base * 0.77)
        return low...high
    }

    /// Current load position within 0–100 scale.
    var currentLoadPosition: Double {
        Double(loadScore)
    }

    /// Estimated stress on a 0–100 scale (inverse of recovery, weighted by strain).
    var estimatedStress: Double {
        let recoveryFactor = 100.0 - Double(readinessScore)
        let strainFactor = strainData.map { $0.dayStrain / 21.0 * 100.0 } ?? 0
        return min(100, (recoveryFactor * 0.6 + strainFactor * 0.4))
    }

    /// Indicate if Readiness is calculating (we have some data but the algorithm doesn't have a score yet).
    /// Since we use an algorithm in `RecoveryScoreEngine`, we'll treat `recoveryScore == nil` when we have data as calculating.
    var isReadinessCalculating: Bool {
        return recoveryScore == nil && (currentHeartRate != nil || sleepData != nil)
    }

    private func updateInsights() {
        if recoveryScore == nil {
            insightHeadline = "Collecting Baseline"
            insightExplanation = "We're gathering more data to build your accurate resilience profile."
            return
        }
        
        let score = readinessScore
        if score >= 66 {
            insightHeadline = "Resilience is solid today."
            if estimatedStress > 50 {
                insightExplanation = "You're well-recovered, but watch your stress levels as the day goes on."
            } else {
                insightExplanation = "Your body is primed to take on more strain. Consider pushing harder."
            }
        } else if score >= 33 {
            insightHeadline = "Resilience is adequate."
            insightExplanation = "You're in a good spot, but don't overexert yourself. Keep things balanced."
        } else {
            insightHeadline = "Your body needs rest."
            insightExplanation = "Prioritize light movement and sleep tonight to bounce back."
        }
    }

    // MARK: - Data Loading

    func loadData(modelContext: ModelContext) async {
        isLoading = true
        errorMessage = nil

        do {
            if !authManager.isAuthenticated {
                try await authManager.signIn()
            }

            // Small delay to let auth settle
            try await Task.sleep(nanoseconds: 500_000_000)

            let calendar = Calendar.current
            
            // Adjust queries relative to `selectedDate` instead of `Date()`
            // Since `selectedDate` might be in the middle of the day, we query from start of that day
            // up to the end of that day (or current time if it's today)
            let isToday = calendar.isDateInToday(selectedDate)
            let endOfSelectedDay = isToday ? Date() : calendar.date(bySettingHour: 23, minute: 59, second: 59, of: selectedDate)!
            let startOfSelectedDay = calendar.startOfDay(for: selectedDate)
            
            let previousDay = calendar.date(byAdding: .day, value: -1, to: selectedDate)!
            let startOfPreviousDay = calendar.startOfDay(for: previousDay)
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: selectedDate)!

            // Fetch everything concurrently - biometric baselines require 30 days of data
            async let fetchHRV   = fetchOptionalPoints(for: .dailyHeartRateVariability, from: thirtyDaysAgo, to: endOfSelectedDay)
            async let fetchRHR   = fetchOptionalPoints(for: .dailyRestingHeartRate, from: thirtyDaysAgo, to: endOfSelectedDay)
            async let fetchResp  = fetchOptionalPoints(for: .respiratoryRate, from: thirtyDaysAgo, to: endOfSelectedDay)
            async let fetchHR    = fetchOptionalPoints(for: .heartRate, from: startOfSelectedDay, to: endOfSelectedDay)
            async let fetchSteps = fetchOptionalPoints(for: .steps, from: startOfSelectedDay, to: endOfSelectedDay)
            async let fetchDist  = fetchOptionalPoints(for: .distance, from: startOfSelectedDay, to: endOfSelectedDay)
            async let fetchAZM   = fetchOptionalPoints(for: .activeZoneMinutes, from: startOfSelectedDay, to: endOfSelectedDay)
            async let fetchCal   = fetchOptionalPoints(for: .activeEnergyBurned, from: startOfSelectedDay, to: endOfSelectedDay)
            async let fetchSleep = fetchOptionalSleepSessions(from: startOfPreviousDay, to: endOfSelectedDay)
            async let fetchExercises = fetchOptionalExerciseSessions(from: startOfSelectedDay, to: endOfSelectedDay)

            let (hrvData, rhrData, respData, hrData, stepsData, distData, azmData, calData, allSleeps, allExercises) =
                try await (fetchHRV, fetchRHR, fetchResp, fetchHR, fetchSteps, fetchDist, fetchAZM, fetchCal, fetchSleep, fetchExercises)

            // Scalar overnight metrics: take the most recent value (already sorted newest-first).
            // These are Fitbit nightly computations and may be stamped as yesterday or today.
            let currentHRV  = hrvData.first?.value
            let currentRHR  = rhrData.first?.value
            let currentResp = respData.first?.value

            if let hrv = currentHRV, let rhr = currentRHR, let resp = currentResp {
                let hrvHistory  = hrvData.filter  { $0.startTime >= thirtyDaysAgo && !calendar.isDateInToday($0.startTime) }
                let rhrHistory  = rhrData.filter  { $0.startTime >= thirtyDaysAgo && !calendar.isDateInToday($0.startTime) }
                let respHistory = respData.filter { $0.startTime >= thirtyDaysAgo && !calendar.isDateInToday($0.startTime) }

                let hrvBaseline  = computeBaseline(hrvHistory,  fallbackMean: 40.0, fallbackSD: 5.0)
                let rhrBaseline  = computeBaseline(rhrHistory,  fallbackMean: 70.0, fallbackSD: 5.0)
                let respBaseline = computeBaseline(respHistory, fallbackMean: 14.5, fallbackSD: 0.5)

                let newScore = recoveryEngine.calculateScore(
                    currentHRV: hrv,
                    currentRHR: rhr,
                    currentRespRate: resp,
                    hrvBaseline: hrvBaseline,
                    rhrBaseline: rhrBaseline,
                    respRateBaseline: respBaseline
                )
                self.recoveryScore = newScore

                // Cache to SwiftData
                let entity = RecoveryScoreEntity(
                    date: newScore.date,
                    score: newScore.score,
                    currentHRV: newScore.currentHRV,
                    currentRHR: newScore.currentRHR,
                    currentRespRate: newScore.currentRespRate,
                    baselineHRV: newScore.baselineHRV,
                    baselineRHR: newScore.baselineRHR,
                    baselineRespRate: newScore.baselineRespRate,
                    hrvZScore: newScore.hrvZScore,
                    rhrZScore: newScore.rhrZScore,
                    respiratoryRateZScore: newScore.respiratoryRateZScore,
                    bandRawValue: newScore.band.rawValue
                )
                modelContext.insert(entity)
                try modelContext.save()
            }

            // --- Sleep ---
            var sleepResult = allSleeps.filter { $0.totalTimeAsleep >= 10800 }.max(by: { $0.totalTimeAsleep < $1.totalTimeAsleep })
            if sleepResult != nil {
                // If HRV data is available for today, pass it to the sleep data for score calculation
                sleepResult!.deepSleepRMSSD = currentHRV
                let breakdown = SleepScoreEngine.calculateScoreBreakdown(for: sleepResult!)
                sleepResult!.scoreBreakdown = breakdown
                sleepResult!.computedScore = breakdown.compositeScore
            }
            self.sleepData = sleepResult
            self.todayNaps = allSleeps.filter { $0.totalTimeAsleep < 10800 }

            // --- Strain ---
            // Each aggregated HealthDataPoint for cumulative types already holds the daily sum
            // (from fetchDataPoints summing strategy). The .filter is a safety net in case the
            // API returns prior-day points within the query window.
            let todayStepsVal   = stepsData.filter { calendar.isDateInToday($0.startTime) }.map(\.value).reduce(0, +)
            let todayCalories   = calData.filter   { calendar.isDateInToday($0.startTime) }.map(\.value).reduce(0, +)
            let todayDistMeters = distData.filter  { calendar.isDateInToday($0.startTime) }.map(\.value).reduce(0, +)
            let todayAZM        = azmData.filter   { calendar.isDateInToday($0.startTime) }.map(\.value).reduce(0, +)
            let distanceMiles   = todayDistMeters * 0.000621371

            // Strain formula: combines steps (scaled down) and Active Zone Minutes (higher weight
            // because AZM represents elevated heart-rate effort). The composite "load" is fed into
            // a natural-log curve capped at 21 — matching WHOOP's 0–21 logarithmic strain scale.
            // Example: 10,000 steps + 30 AZM → load = 50 + 60 = 110 → strain ≈ 11.6 (moderate)
            let load = (todayStepsVal * 0.005) + (todayAZM * 2.0)
            let dayStrain = load > 0 ? min(21.0, max(0.0, 2.5 * log(load + 1))) : 0.0

            self.strainData = StrainData(
                date: selectedDate,
                dayStrain: dayStrain,
                // HR zone minutes require continuous zone-tagged HR data which the Google Health
                // API doesn't surface via the active-zone-minutes endpoint — left as 0 for now.
                zone1Minutes: 0, zone2Minutes: 0, zone3Minutes: 0,
                zone4Minutes: 0, zone5Minutes: 0,
                caloriesBurned: todayCalories,
                steps: Int(todayStepsVal),
                distance: distanceMiles,
                activeZoneMinutes: todayAZM,
                activities: allExercises
            )

            // --- Overview cards ---
            let todayHR = hrData.filter { calendar.isDateInToday($0.startTime) }
            self.todayHeartRateData = todayHR
            self.currentHeartRate = todayHR.first?.value
            self.restingHeartRate = currentRHR
            self.todaySteps       = Int(todayStepsVal)
            self.activeZoneMinutes = todayAZM
            self.stressLevel      = estimatedStress

            self.updateInsights()

            // Sync to Apple Health after successful data ingestion
            await self.syncEnabledMetricsToAppleHealth()

        } catch let GoogleHealthError.apiError(message) where message.contains("403") || message.contains("401") {
            authManager.signOut()
            self.errorMessage = "Session expired. Please sign in again."
        } catch let GoogleHealthError.apiError(message) {
            self.errorMessage = Self.userFacingAPIError(from: message)
        } catch {
            let nsError = error as NSError
            if nsError.code == -5 || nsError.localizedDescription.lowercased().contains("cancel") {
                self.errorMessage = "Sign-in was cancelled. Please authorize Google Health to view your data."
            } else {
                self.errorMessage = error.localizedDescription
            }
        }

        isLoading = false

        if authManager.isAuthenticated,
           !UserDefaults.standard.bool(forKey: "hasPromptedForHistoricalSync") {
            self.showHistoricalSyncPrompt = true
        }
    }

    // MARK: - Historical Sync

    func syncHistoricalData() async {
        showHistoricalSyncPrompt = false
        isSyncingHistoricalData = true
        historicalSyncProgress = 0.0
        UserDefaults.standard.set(true, forKey: "hasPromptedForHistoricalSync")

        do {
            let calendar = Calendar.current
            let now = Date()
            let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: now)!
            
            // Sync step 1: HRV baseline
            historicalSyncProgress = 0.05
            _ = try await healthService.fetchDataPoints(for: .dailyHeartRateVariability, from: sixtyDaysAgo, to: now)
            
            // Sync step 2: RHR baseline
            historicalSyncProgress = 0.20
            _ = try await healthService.fetchDataPoints(for: .dailyRestingHeartRate, from: sixtyDaysAgo, to: now)
            
            // Sync step 3: Respiratory Rate baseline
            historicalSyncProgress = 0.35
            _ = try await healthService.fetchDataPoints(for: .respiratoryRate, from: sixtyDaysAgo, to: now)
            
            // Sync step 4: Steps history
            historicalSyncProgress = 0.50
            _ = try await healthService.fetchDataPoints(for: .steps, from: sixtyDaysAgo, to: now)
            
            // Sync step 5: Distance history
            historicalSyncProgress = 0.65
            _ = try await healthService.fetchDataPoints(for: .distance, from: sixtyDaysAgo, to: now)
            
            // Sync step 6: Sleep history
            historicalSyncProgress = 0.80
            _ = try await healthService.fetchSleepDataPoints(from: sixtyDaysAgo, to: now)
            
            // Sync step 7: Complete
            historicalSyncProgress = 0.95
            try await Task.sleep(nanoseconds: 500_000_000)
            historicalSyncProgress = 1.0
            
        } catch {
            print("Error syncing historical data: \(error)")
        }

        isSyncingHistoricalData = false
    }

    // MARK: - Helpers

    private func fetchOptionalPoints(for dataType: HealthDataType, from startDate: Date, to endDate: Date) async throws -> [HealthDataPoint] {
        do {
            return try await healthService.fetchDataPoints(for: dataType, from: startDate, to: endDate)
        } catch GoogleHealthError.authenticationRequired {
            throw GoogleHealthError.authenticationRequired
        } catch let GoogleHealthError.apiError(message) where message.contains("401") || message.contains("403") {
            throw GoogleHealthError.apiError(message)
        } catch {
            print("⚠️ Skipping \(dataType.rawValue): \(error.localizedDescription)")
            return []
        }
    }

    private func fetchOptionalSleepSessions(from startDate: Date, to endDate: Date) async throws -> [SleepData] {
        do {
            return try await healthService.fetchAllSleepSessions(from: startDate, to: endDate)
        } catch GoogleHealthError.authenticationRequired {
            throw GoogleHealthError.authenticationRequired
        } catch let GoogleHealthError.apiError(message) where message.contains("401") || message.contains("403") {
            throw GoogleHealthError.apiError(message)
        } catch {
            print("⚠️ Skipping sleep: \(error.localizedDescription)")
            return []
        }
    }

    private func fetchOptionalExerciseSessions(from startDate: Date, to endDate: Date) async throws -> [ActivitySession] {
        do {
            if let service = healthService as? GoogleHealthService {
                return try await service.fetchExerciseSessions(from: startDate, to: endDate)
            }
            return []
        } catch GoogleHealthError.authenticationRequired {
            throw GoogleHealthError.authenticationRequired
        } catch let GoogleHealthError.apiError(message) where message.contains("401") || message.contains("403") {
            throw GoogleHealthError.apiError(message)
        } catch {
            print("⚠️ Skipping exercises: \(error.localizedDescription)")
            return []
        }
    }

    private static func userFacingAPIError(from message: String) -> String {
        if message.contains("INVALID_DATA_POINT_FILTER") {
            return "Google Health rejected one of the data filters. Try again after the app refreshes its health query settings."
        }
        if message.contains("PERMISSION_DENIED") || message.contains("insufficient") {
            return "Google Health permissions are incomplete. Please reconnect and approve all requested health permissions."
        }
        return "Google Health could not be reached. Please try again."
    }

    private func computeBaseline(_ points: [HealthDataPoint], fallbackMean: Double, fallbackSD: Double) -> (mean: Double, sd: Double) {
        guard points.count >= 3 else { return (mean: fallbackMean, sd: fallbackSD) }
        let values = points.map(\.value)
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let sd = max(0.5, sqrt(variance))
        return (mean: mean, sd: sd)
    }

    // MARK: - Apple Health Sync

    func syncEnabledMetricsToAppleHealth(forceBackfill: Bool = false) async {
        guard HealthKitManager.shared.isAvailable else { return }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate date range
        let lastSyncTime = UserDefaults.standard.double(forKey: "lastAppleHealthSync")
        let startDate: Date
        if forceBackfill || lastSyncTime == 0 {
            startDate = calendar.date(byAdding: .day, value: -60, to: now)!
        } else {
            startDate = Date(timeIntervalSince1970: lastSyncTime)
        }
        
        let sleepEnabled = UserDefaults.standard.bool(forKey: "appleHealthSyncSleep")
        let hrvEnabled = UserDefaults.standard.bool(forKey: "appleHealthSyncHRV")
        let rhrEnabled = UserDefaults.standard.bool(forKey: "appleHealthSyncRHR")
        let stepsEnabled = UserDefaults.standard.bool(forKey: "appleHealthSyncSteps")
        
        do {
            if sleepEnabled {
                let sleeps = try await healthService.fetchAllSleepSessions(from: startDate, to: now)
                for sleep in sleeps {
                    try await HealthKitManager.shared.writeSleep(sleep: sleep)
                }
            }
            
            if hrvEnabled {
                let hrvData = try await healthService.fetchDataPoints(for: .dailyHeartRateVariability, from: startDate, to: now)
                for point in hrvData {
                    try await HealthKitManager.shared.writeHRV(value: point.value, date: point.startTime)
                }
            }
            
            if rhrEnabled {
                let rhrData = try await healthService.fetchDataPoints(for: .dailyRestingHeartRate, from: startDate, to: now)
                for point in rhrData {
                    try await HealthKitManager.shared.writeRestingHeartRate(value: point.value, date: point.startTime)
                }
            }
            
            if stepsEnabled {
                let stepsData = try await healthService.fetchDataPoints(for: .steps, from: startDate, to: now)
                for point in stepsData {
                    try await HealthKitManager.shared.writeSteps(value: point.value, date: point.startTime)
                }
            }
            
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "lastAppleHealthSync")
        } catch {
            print("⚠️ Error syncing to Apple Health: \(error.localizedDescription)")
        }
    }
}
