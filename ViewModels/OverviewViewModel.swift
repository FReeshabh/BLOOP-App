import Foundation
import SwiftUI
import SwiftData

@MainActor
final class OverviewViewModel: ObservableObject {

    // MARK: - Published State

    @Published var recoveryScore: RecoveryScore?
    @Published var sleepData: SleepData?
    @Published var strainData: StrainData?

    // Overview metric cards
    @Published var currentHeartRate: Double?
    @Published var restingHeartRate: Double?
    @Published var todaySteps: Int = 0
    @Published var activeZoneMinutes: Double = 0
    @Published var stressLevel: Double = 0  // 0–100 estimated from strain

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Historical sync
    @Published var isSyncingHistoricalData: Bool = false
    @Published var showHistoricalSyncPrompt: Bool = false
    @Published var historicalSyncProgress: Double = 0.0

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

    /// Readiness / Recovery 0–100.
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

            let now = Date()
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: now)
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            let startOfYesterday = calendar.startOfDay(for: yesterday)
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!

            // Fetch everything concurrently - biometric baselines require 30 days of data
            async let fetchHRV   = healthService.fetchDataPoints(for: .dailyHeartRateVariability, from: thirtyDaysAgo, to: now)
            async let fetchRHR   = healthService.fetchDataPoints(for: .dailyRestingHeartRate, from: thirtyDaysAgo, to: now)
            async let fetchResp  = healthService.fetchDataPoints(for: .respiratoryRate, from: thirtyDaysAgo, to: now)
            async let fetchHR    = healthService.fetchDataPoints(for: .heartRate, from: startOfDay, to: now)
            async let fetchSteps = healthService.fetchDataPoints(for: .steps, from: startOfDay, to: now)
            async let fetchDist  = healthService.fetchDataPoints(for: .distance, from: startOfDay, to: now)
            async let fetchAZM   = healthService.fetchDataPoints(for: .activeZoneMinutes, from: startOfDay, to: now)
            async let fetchCal   = healthService.fetchDataPoints(for: .activeEnergyBurned, from: startOfDay, to: now)
            async let fetchSleep = healthService.fetchSleepData(from: startOfYesterday, to: now)

            let (hrvData, rhrData, respData, hrData, stepsData, distData, azmData, calData, sleepResult) =
                try await (fetchHRV, fetchRHR, fetchResp, fetchHR, fetchSteps, fetchDist, fetchAZM, fetchCal, fetchSleep)

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
            self.sleepData = sleepResult

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
                date: now,
                dayStrain: dayStrain,
                // HR zone minutes require continuous zone-tagged HR data which the Google Health
                // API doesn't surface via the active-zone-minutes endpoint — left as 0 for now.
                zone1Minutes: 0, zone2Minutes: 0, zone3Minutes: 0,
                zone4Minutes: 0, zone5Minutes: 0,
                caloriesBurned: todayCalories,
                steps: Int(todayStepsVal),
                distance: distanceMiles,
                activeZoneMinutes: todayAZM,
                activities: []
            )

            // --- Overview cards ---
            self.currentHeartRate = hrData.filter { calendar.isDateInToday($0.startTime) }.first?.value
            self.restingHeartRate = currentRHR
            self.todaySteps       = Int(todayStepsVal)
            self.activeZoneMinutes = todayAZM
            self.stressLevel      = estimatedStress

        } catch let GoogleHealthError.apiError(message) where message.contains("403") || message.contains("401") {
            authManager.signOut()
            self.errorMessage = "Session expired. Please sign in again."
        } catch let GoogleHealthError.apiError(message) {
            self.errorMessage = "API Error: \(message)"
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
            for i in 1...5 {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                historicalSyncProgress = Double(i) / 5.0
            }
        } catch {
            print("Error syncing historical data: \(error)")
        }

        isSyncingHistoricalData = false
    }

    // MARK: - Helpers

    private func computeBaseline(_ points: [HealthDataPoint], fallbackMean: Double, fallbackSD: Double) -> (mean: Double, sd: Double) {
        guard points.count >= 3 else { return (mean: fallbackMean, sd: fallbackSD) }
        let values = points.map(\.value)
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let sd = max(0.5, sqrt(variance))
        return (mean: mean, sd: sd)
    }
}
