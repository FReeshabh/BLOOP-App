import Foundation

struct SleepScoreBreakdown: Codable, Equatable {
    let totalSleep: Int
    let efficiency: Int
    let deepSleep: Int
    let remSleep: Int
    let latency: Int
    let timing: Int
    
    var compositeScore: Int {
        let weighted = Double(totalSleep) * 0.25 +
                       Double(efficiency) * 0.20 +
                       Double(deepSleep) * 0.15 +
                       Double(remSleep) * 0.15 +
                       Double(latency) * 0.10 +
                       Double(timing) * 0.15
        return Int(min(100.0, max(0.0, round(weighted))))
    }
}

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
    static func calculateScoreBreakdown(for sleep: SleepData) -> SleepScoreBreakdown {
        let totalTimeInBed = sleep.totalTimeInBed
        let totalTimeAsleep = sleep.totalTimeAsleep
        
        guard totalTimeInBed > 0, totalTimeAsleep > 0 else {
            return SleepScoreBreakdown(totalSleep: 0, efficiency: 0, deepSleep: 0, remSleep: 0, latency: 0, timing: 0)
        }

        let sleepHours = totalTimeAsleep / 3600.0
        let totalSleepScore: Double
        if sleepHours >= 7.0 {
            totalSleepScore = 100.0
        } else {
            totalSleepScore = max(0.0, ((sleepHours - 3.0) / 4.0) * 100.0)
        }

        let efficiencyPct = totalTimeAsleep / totalTimeInBed
        let efficiencyScore = min(100.0, max(0.0, ((efficiencyPct - 0.70) / 0.15) * 100.0))

        let deepPct = totalTimeAsleep > 0 ? (sleep.deepSleepTime / totalTimeAsleep) : 0.0
        let deepScore: Double
        let deepIdealRange = 0.13...0.23
        if deepIdealRange.contains(deepPct) {
            deepScore = 100.0
        } else {
            let dist = min(abs(deepPct - deepIdealRange.lowerBound), abs(deepPct - deepIdealRange.upperBound))
            deepScore = max(0.0, 100.0 - (dist * 10.0 * 100.0))
        }

        let remPct = totalTimeAsleep > 0 ? (sleep.remSleepTime / totalTimeAsleep) : 0.0
        let remScore: Double
        let remIdealRange = 0.20...0.25
        if remIdealRange.contains(remPct) {
            remScore = 100.0
        } else {
            let dist = min(abs(remPct - remIdealRange.lowerBound), abs(remPct - remIdealRange.upperBound))
            remScore = max(0.0, 100.0 - (dist * 10.0 * 100.0))
        }

        let onsetMin = sleep.minutesToFallAsleep / 60.0
        let latencyScore: Double
        if onsetMin >= 10.0 && onsetMin <= 20.0 {
            latencyScore = 100.0
        } else if onsetMin > 20.0 {
            latencyScore = max(0.0, 100.0 - ((onsetMin - 20.0) / 40.0) * 100.0)
        } else {
            latencyScore = max(0.0, min(100.0, 50.0 + (onsetMin / 10.0) * 50.0))
        }

        let midpoint = sleep.bedTime.addingTimeInterval(sleep.totalTimeInBed / 2.0)
        let calendar = Calendar.current
        let hour = Double(calendar.component(.hour, from: midpoint))
        let minute = Double(calendar.component(.minute, from: midpoint))
        let timeInHours = hour + minute / 60.0
        
        var distance = 0.0
        if timeInHours > 3.0 && timeInHours < 18.0 {
            distance = timeInHours - 3.0
        } else if timeInHours >= 18.0 {
            distance = 24.0 - timeInHours
        }
        
        let timingScore = max(0.0, 100.0 - (distance * 20.0))

        return SleepScoreBreakdown(
            totalSleep: Int(round(totalSleepScore)),
            efficiency: Int(round(efficiencyScore)),
            deepSleep: Int(round(deepScore)),
            remSleep: Int(round(remScore)),
            latency: Int(round(latencyScore)),
            timing: Int(round(timingScore))
        )
    }

    static func calculateScore(for sleep: SleepData) -> Int {
        return calculateScoreBreakdown(for: sleep).compositeScore
    }
}

// Fixed Date for testing: Setting it to precisely midnight
var components = DateComponents()
components.year = 2026
components.month = 6
components.day = 20
components.hour = 0 // midnight
components.minute = 0
let date = Calendar.current.date(from: components)!

let userNight = SleepData(
    bedTime: date.addingTimeInterval(-8.5 * 3600), // ~15:30 prev day? Wait, midnight - 8.5h is 3:30 PM. Let's fix this.
    wakeTime: date,
    totalTimeInBed: 8.5 * 3600,
    totalTimeAsleep: 6.8 * 3600,
    awakeTime: 1.7 * 3600,
    lightSleepTime: 4.0 * 3600,
    remSleepTime: 1.5 * 3600,
    deepSleepTime: 1.3 * 3600,
    minutesToFallAsleep: 25 * 60,
    minutesAfterWakeUp: 15 * 60,
    deepSleepRMSSD: 35.0
)

// Let's create more realistic dates.
let bedTimeNormal = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: date)! // 11 PM
let wakeTimeNormal = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: date.addingTimeInterval(86400))! // 7 AM

let perfectNight = SleepData(
    bedTime: bedTimeNormal,
    wakeTime: wakeTimeNormal,
    totalTimeInBed: 8.0 * 3600,
    totalTimeAsleep: 7.6 * 3600,
    awakeTime: 0.4 * 3600,
    lightSleepTime: 4.1 * 3600,
    remSleepTime: 1.9 * 3600, // 25%
    deepSleepTime: 1.6 * 3600, // 21%
    minutesToFallAsleep: 15 * 60,
    minutesAfterWakeUp: 5 * 60,
    deepSleepRMSSD: 50.0
)

let poorStagesNight = SleepData(
    bedTime: bedTimeNormal,
    wakeTime: wakeTimeNormal,
    totalTimeInBed: 8.0 * 3600,
    totalTimeAsleep: 7.6 * 3600,
    awakeTime: 0.4 * 3600,
    lightSleepTime: 6.0 * 3600,
    remSleepTime: 1.0 * 3600, // 13% - poor
    deepSleepTime: 0.6 * 3600, // 8% - poor
    minutesToFallAsleep: 15 * 60,
    minutesAfterWakeUp: 5 * 60,
    deepSleepRMSSD: 50.0
)

let lateNightBedTime = Calendar.current.date(bySettingHour: 4, minute: 0, second: 0, of: date.addingTimeInterval(86400))! // 4 AM
let lateNightWakeTime = lateNightBedTime.addingTimeInterval(8.0 * 3600)

let lateNight = SleepData(
    bedTime: lateNightBedTime,
    wakeTime: lateNightWakeTime,
    totalTimeInBed: 8.0 * 3600,
    totalTimeAsleep: 7.6 * 3600,
    awakeTime: 0.4 * 3600,
    lightSleepTime: 4.1 * 3600,
    remSleepTime: 1.9 * 3600, 
    deepSleepTime: 1.6 * 3600, 
    minutesToFallAsleep: 15 * 60,
    minutesAfterWakeUp: 5 * 60,
    deepSleepRMSSD: 50.0
)

print("Perfect night (good stages, good timing): \(SleepScoreEngine.calculateScore(for: perfectNight))")
let perfectBreakdown = SleepScoreEngine.calculateScoreBreakdown(for: perfectNight)
print("Breakdown: \(perfectBreakdown)")

print("\nPoor stages night (same duration/timing as perfect, but poor deep/rem): \(SleepScoreEngine.calculateScore(for: poorStagesNight))")
let poorBreakdown = SleepScoreEngine.calculateScoreBreakdown(for: poorStagesNight)
print("Breakdown: \(poorBreakdown)")

print("\nLate night (same duration/stages as perfect, but 4 AM bedtime): \(SleepScoreEngine.calculateScore(for: lateNight))")
let lateBreakdown = SleepScoreEngine.calculateScoreBreakdown(for: lateNight)
print("Breakdown: \(lateBreakdown)")
