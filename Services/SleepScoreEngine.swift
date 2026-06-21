import Foundation

class SleepScoreEngine {
    
    /// Computes the app-side sleep score breakdown.
    static func calculateScoreBreakdown(for sleep: SleepData) -> SleepScoreBreakdown {
        let totalTimeInBed = sleep.totalTimeInBed
        let totalTimeAsleep = sleep.totalTimeAsleep
        
        guard totalTimeInBed > 0, totalTimeAsleep > 0 else {
            return SleepScoreBreakdown(totalSleep: 0, efficiency: 0, deepSleep: 0, remSleep: 0, latency: nil, timing: 0)
        }

        // 1. Total Sleep (25%)
        let sleepHours = totalTimeAsleep / 3600.0
        let totalSleepScore: Double
        if sleepHours >= 7.0 {
            totalSleepScore = 100.0
        } else {
            totalSleepScore = max(0.0, ((sleepHours - 3.0) / 4.0) * 100.0)
        }

        // 2. Efficiency (20%)
        let efficiencyPct = totalTimeAsleep / totalTimeInBed
        let efficiencyScore = min(100.0, max(0.0, ((efficiencyPct - 0.70) / 0.15) * 100.0))

        // 3. Deep Sleep (15%)
        let deepPct = totalTimeAsleep > 0 ? (sleep.deepSleepTime / totalTimeAsleep) : 0.0
        let deepScore: Double
        let deepIdealRange = 0.13...0.23
        if deepIdealRange.contains(deepPct) {
            deepScore = 100.0
        } else {
            let dist = min(abs(deepPct - deepIdealRange.lowerBound), abs(deepPct - deepIdealRange.upperBound))
            deepScore = max(0.0, 100.0 - (dist * 10.0 * 100.0))
        }

        // 4. REM Sleep (15%)
        let remPct = totalTimeAsleep > 0 ? (sleep.remSleepTime / totalTimeAsleep) : 0.0
        let remScore: Double
        let remIdealRange = 0.20...0.25
        if remIdealRange.contains(remPct) {
            remScore = 100.0
        } else {
            let dist = min(abs(remPct - remIdealRange.lowerBound), abs(remPct - remIdealRange.upperBound))
            remScore = max(0.0, 100.0 - (dist * 10.0 * 100.0))
        }

        // 5. Latency (10%)
        let onsetMin = sleep.minutesToFallAsleep / 60.0
        let latencyScore: Double?
        if sleep.minutesToFallAsleep == 0 {
            latencyScore = nil
        } else if onsetMin >= 10.0 && onsetMin <= 20.0 {
            latencyScore = 100.0
        } else if onsetMin > 20.0 {
            latencyScore = max(0.0, 100.0 - ((onsetMin - 20.0) / 40.0) * 100.0)
        } else {
            latencyScore = max(0.0, min(100.0, 50.0 + (onsetMin / 10.0) * 50.0))
        }

        // 6. Timing (15%)
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
            latency: latencyScore.map { Int(round($0)) },
            timing: Int(round(timingScore))
        )
    }

    /// Computes the app-side sleep score using a range-based formula.
    /// - Parameter sleep: The SleepData struct with populated fields.
    /// - Returns: A score between 0 and 100.
    static func calculateScore(for sleep: SleepData) -> Int {
        return calculateScoreBreakdown(for: sleep).compositeScore
    }
}
