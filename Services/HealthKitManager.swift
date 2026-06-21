import Foundation
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    let healthStore = HKHealthStore()
    
    // Mapping of our metrics to HealthKit types
    let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    let rhrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
    let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!
    
    private init() {}
    
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    /// Requests write and read authorization for specific types.
    /// Read permission is requested strictly to support deduplication.
    func requestAuthorization(for metrics: Set<HealthKitMetric>) async throws {
        guard isAvailable else { return }
        
        let types = hkTypes(for: metrics)
        guard !types.isEmpty else { return }
        
        try await healthStore.requestAuthorization(toShare: types, read: types)
    }
    
    /// Checks if authorization is explicitly denied or revoked for any of the active metrics.
    func isPermissionRevoked(for metrics: Set<HealthKitMetric>) -> Bool {
        guard isAvailable else { return false }
        
        for metric in metrics {
            let type = hkType(for: metric)
            if healthStore.authorizationStatus(for: type) == .sharingDenied {
                return true
            }
        }
        return false
    }
    
    /// Helper to map metric enum to HealthKit type
    private func hkType(for metric: HealthKitMetric) -> HKObjectType {
        switch metric {
        case .sleep: return sleepType
        case .hrv: return hrvType
        case .restingHeartRate: return rhrType
        case .steps: return stepsType
        }
    }
    
    private func hkTypes(for metrics: Set<HealthKitMetric>) -> Set<HKSampleType> {
        var types = Set<HKSampleType>()
        for metric in metrics {
            if let sampleType = hkType(for: metric) as? HKSampleType {
                types.insert(sampleType)
            }
        }
        return types
    }
    
    /// Checks if any HealthKit samples exist in a given time window to avoid duplication.
    func sampleExists(type: HKSampleType, start: Date, end: Date) async -> Bool {
        guard isAvailable else { return false }
        
        return await withCheckedContinuation { continuation in
            // Search in a window of +/- 1 minute around the target start time
            let predicate = HKQuery.predicateForSamples(withStart: start.addingTimeInterval(-60), end: end.addingTimeInterval(60), options: [])
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    print("⚠️ HealthKit query error during deduplication: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                } else if let samples = samples, !samples.isEmpty {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }
            healthStore.execute(query)
        }
    }
    
    /// Writes a steps data point to HealthKit with deduplication
    func writeSteps(value: Double, date: Date) async throws {
        guard isAvailable else { return }
        
        let start = date
        let end = date.addingTimeInterval(60) // steps represent a short window
        
        guard await !sampleExists(type: stepsType, start: start, end: end) else {
            print("⏭️ Steps sample already exists for \(date). Skipping.")
            return
        }
        
        let quantity = HKQuantity(unit: .count(), doubleValue: value)
        let sample = HKQuantitySample(type: stepsType, quantity: quantity, start: start, end: end)
        
        try await healthStore.save(sample)
        print("✅ Successfully wrote steps to Apple Health.")
    }
    
    /// Writes a resting heart rate data point to HealthKit with deduplication
    func writeRestingHeartRate(value: Double, date: Date) async throws {
        guard isAvailable else { return }
        
        let start = date
        let end = date
        
        guard await !sampleExists(type: rhrType, start: start, end: end) else {
            print("⏭️ Resting heart rate sample already exists for \(date). Skipping.")
            return
        }
        
        let unit = HKUnit.count().unitDivided(by: .minute())
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        let sample = HKQuantitySample(type: rhrType, quantity: quantity, start: start, end: end)
        
        try await healthStore.save(sample)
        print("✅ Successfully wrote resting heart rate to Apple Health.")
    }
    
    /// Writes a heart rate variability (SDNN/RMSSD) data point to HealthKit with deduplication
    func writeHRV(value: Double, date: Date) async throws {
        guard isAvailable else { return }
        
        let start = date
        let end = date
        
        guard await !sampleExists(type: hrvType, start: start, end: end) else {
            print("⏭️ HRV sample already exists for \(date). Skipping.")
            return
        }
        
        let unit = HKUnit.secondUnit(with: .milli)
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        let sample = HKQuantitySample(type: hrvType, quantity: quantity, start: start, end: end)
        
        try await healthStore.save(sample)
        print("✅ Successfully wrote HRV to Apple Health.")
    }
    
    /// Writes a sleep session (and stages if available) to HealthKit with deduplication
    func writeSleep(sleep: SleepData) async throws {
        guard isAvailable else { return }
        
        // We check if a sleep sample overlaps the bedTime/wakeTime
        guard await !sampleExists(type: sleepType, start: sleep.bedTime, end: sleep.wakeTime) else {
            print("⏭️ Sleep sample already exists for \(sleep.bedTime) - \(sleep.wakeTime). Skipping.")
            return
        }
        
        var samples: [HKSample] = []
        
        // Always write an InBed sample
        let inBedSample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.inBed.rawValue,
            start: sleep.bedTime,
            end: sleep.wakeTime
        )
        samples.append(inBedSample)
        
        // Determine whether we have sleep stage breakdown
        let hasStages = sleep.lightSleepTime > 0 || sleep.deepSleepTime > 0 || sleep.remSleepTime > 0
        
        if hasStages {
            // Layout stage breakdown sequentially within the sleep window
            var currentStart = sleep.bedTime
            
            let stages: [(Double, HKCategoryValueSleepAnalysis)] = [
                (sleep.awakeTime, .awake),
                (sleep.lightSleepTime, .asleepCore),
                (sleep.deepSleepTime, .asleepDeep),
                (sleep.remSleepTime, .asleepREM)
            ]
            
            for (duration, value) in stages {
                guard duration > 0 else { continue }
                // Ensure we don't exceed the wakeTime
                let end = min(sleep.wakeTime, currentStart.addingTimeInterval(duration))
                guard end > currentStart else { continue }
                
                let sample = HKCategorySample(
                    type: sleepType,
                    value: value.rawValue,
                    start: currentStart,
                    end: end
                )
                samples.append(sample)
                currentStart = end
            }
        } else {
            // Write general Asleep sample if no stage breakdowns
            let asleepStart = sleep.bedTime.addingTimeInterval(sleep.awakeTime)
            let asleepEnd = sleep.wakeTime
            if asleepEnd > asleepStart {
                let asleepSample = HKCategorySample(
                    type: sleepType,
                    value: HKCategoryValueSleepAnalysis.asleep.rawValue,
                    start: asleepStart,
                    end: asleepEnd
                )
                samples.append(asleepSample)
            }
        }
        
        try await healthStore.save(samples)
        print("✅ Successfully wrote sleep samples (count: \(samples.count)) to Apple Health.")
    }
}

enum HealthKitMetric: String, CaseIterable, Codable {
    case sleep = "Sleep"
    case hrv = "HRV"
    case restingHeartRate = "Resting HR"
    case steps = "Steps"
    
    var storageKey: String {
        switch self {
        case .sleep: return "appleHealthSyncSleep"
        case .hrv: return "appleHealthSyncHRV"
        case .restingHeartRate: return "appleHealthSyncRHR"
        case .steps: return "appleHealthSyncSteps"
        }
    }
}
