import Foundation

// Copying necessary structs and enums to make it standalone for testing
struct SleepData {
    let bedTime: Date
    let wakeTime: Date
    let totalTimeInBed: TimeInterval
    let totalTimeAsleep: TimeInterval
    let awakeTime: TimeInterval
    let lightSleepTime: TimeInterval
    let remSleepTime: TimeInterval
    let deepSleepTime: TimeInterval
    let minutesToFallAsleep: TimeInterval
    let minutesAfterWakeUp: TimeInterval
    var deepSleepRMSSD: Double?
    let sleepNeed: TimeInterval = 8 * 3600
}

class SleepScoreEngine {
    static func calculateScore(for sleep: SleepData) -> Int {
        let totalTimeInBed = sleep.totalTimeInBed
        let totalTimeAsleep = sleep.totalTimeAsleep
        let sleepNeed = sleep.sleepNeed > 0 ? sleep.sleepNeed : 8 * 3600
        
        guard totalTimeInBed > 0, totalTimeAsleep > 0 else {
            return 0
        }
        
        var totalWeight = 0.0
        var earnedPoints = 0.0
        
        let efficiencyPct = totalTimeAsleep / totalTimeInBed
        let effScoreNorm = max(0.0, min(1.0, (efficiencyPct - 0.70) / 0.15))
        earnedPoints += effScoreNorm * 35.0
        totalWeight += 35.0
        
        let durationPct = totalTimeAsleep / sleepNeed
        let durationScoreNorm = max(0.0, min(1.0, (durationPct - 0.5) / 0.5))
        earnedPoints += durationScoreNorm * 30.0
        totalWeight += 30.0
        
        let hasStages = (sleep.deepSleepTime > 0 || sleep.remSleepTime > 0 || sleep.lightSleepTime > 0)
        if hasStages {
            let deepPct = sleep.deepSleepTime / totalTimeAsleep
            let remPct = sleep.remSleepTime / totalTimeAsleep
            
            func scoreStage(actual: Double, idealRange: ClosedRange<Double>) -> Double {
                if idealRange.contains(actual) { return 1.0 }
                let dist = min(abs(actual - idealRange.lowerBound), abs(actual - idealRange.upperBound))
                return max(0.0, 1.0 - (dist * 10.0))
            }
            
            let deepScoreNorm = scoreStage(actual: deepPct, idealRange: 0.13...0.23)
            let remScoreNorm = scoreStage(actual: remPct, idealRange: 0.20...0.25)
            
            let stageScoreNorm = (deepScoreNorm + remScoreNorm) / 2.0
            earnedPoints += stageScoreNorm * 25.0
            totalWeight += 25.0
        }
        
        let onsetMin = sleep.minutesToFallAsleep / 60.0
        let afterWakeMin = sleep.minutesAfterWakeUp / 60.0
        
        let onsetPenalty = max(0.0, (onsetMin - 20.0) / 40.0)
        let afterWakePenalty = max(0.0, (afterWakeMin - 10.0) / 20.0)
        
        let onsetScoreNorm = max(0.0, 1.0 - onsetPenalty - afterWakePenalty)
        earnedPoints += onsetScoreNorm * 10.0
        totalWeight += 10.0
        
        if let rmssd = sleep.deepSleepRMSSD, rmssd > 0 {
            let rmssdNorm = max(0.0, min(1.0, (rmssd - 15.0) / 40.0))
            earnedPoints += rmssdNorm * 5.0
            totalWeight += 5.0
        }
        
        let finalScore = (earnedPoints / totalWeight) * 100.0
        return Int(min(100.0, max(0.0, round(finalScore))))
    }
}

let date = Date()
let userNight = SleepData(
    bedTime: date.addingTimeInterval(-8.5 * 3600),
    wakeTime: date,
    totalTimeInBed: 8.5 * 3600, // 510 mins
    totalTimeAsleep: 6.8 * 3600, // 408 mins
    awakeTime: 1.7 * 3600, // 102 mins
    lightSleepTime: 4.0 * 3600, // ~60%
    remSleepTime: 1.5 * 3600,   // ~22%
    deepSleepTime: 1.3 * 3600,  // ~19%
    minutesToFallAsleep: 25 * 60,
    minutesAfterWakeUp: 15 * 60,
    deepSleepRMSSD: 35.0
)

let perfectNight = SleepData(
    bedTime: date.addingTimeInterval(-8.0 * 3600),
    wakeTime: date,
    totalTimeInBed: 8.0 * 3600,
    totalTimeAsleep: 7.6 * 3600, // 95% efficiency
    awakeTime: 0.4 * 3600,
    lightSleepTime: 4.1 * 3600,
    remSleepTime: 1.9 * 3600, // 25%
    deepSleepTime: 1.6 * 3600, // 21%
    minutesToFallAsleep: 10 * 60,
    minutesAfterWakeUp: 5 * 60,
    deepSleepRMSSD: 50.0
)

let fragmentedNight = SleepData(
    bedTime: date.addingTimeInterval(-7.0 * 3600),
    wakeTime: date,
    totalTimeInBed: 7.0 * 3600,
    totalTimeAsleep: 4.5 * 3600, // ~64% efficiency
    awakeTime: 2.5 * 3600,
    lightSleepTime: 3.0 * 3600,
    remSleepTime: 0.5 * 3600, // ~11%
    deepSleepTime: 1.0 * 3600, // ~22%
    minutesToFallAsleep: 45 * 60,
    minutesAfterWakeUp: 20 * 60,
    deepSleepRMSSD: 20.0
)

print("User's typical OK night (expected ~73): \(SleepScoreEngine.calculateScore(for: userNight))")
print("Perfect night (expected ~95+): \(SleepScoreEngine.calculateScore(for: perfectNight))")
print("Short fragmented night (expected ~50-60): \(SleepScoreEngine.calculateScore(for: fragmentedNight))")
