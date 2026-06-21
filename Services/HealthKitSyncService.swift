import Foundation

@MainActor
final class HealthKitSyncService {
    static let shared = HealthKitSyncService()
    
    private init() {}
    
    func syncEnabledMetricsToAppleHealth(healthService: HealthDataProvider, forceBackfill: Bool = false) async {
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
