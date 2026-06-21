import Foundation

class SleepScoreEngine {
    
    /// Computes the app-side sleep score using a range-based formula.
    /// - Parameter sleep: The SleepData struct with populated fields.
    /// - Returns: A score between 0 and 100.
    static func calculateScore(for sleep: SleepData) -> Int {
        let totalTimeInBed = sleep.totalTimeInBed
        let totalTimeAsleep = sleep.totalTimeAsleep
        let sleepNeed = sleep.sleepNeed > 0 ? sleep.sleepNeed : 8 * 3600 // 8 hours default
        
        guard totalTimeInBed > 0, totalTimeAsleep > 0 else {
            return 0
        }
        
        var totalWeight = 0.0
        var earnedPoints = 0.0
        
        // 1. Efficiency (Target Weight: 35)
        let efficiencyPct = totalTimeAsleep / totalTimeInBed
        // 85-95% is the target. Map 70% -> 0 score, 85%+ -> 1.0 score
        let effScoreNorm = max(0.0, min(1.0, (efficiencyPct - 0.70) / 0.15))
        earnedPoints += effScoreNorm * 35.0
        totalWeight += 35.0
        
        // 2. Duration vs Goal (Target Weight: 30)
        let durationPct = totalTimeAsleep / sleepNeed
        // Map 50% of need -> 0 score, 100% of need -> 1.0 score
        let durationScoreNorm = max(0.0, min(1.0, (durationPct - 0.5) / 0.5))
        earnedPoints += durationScoreNorm * 30.0
        totalWeight += 30.0
        
        // 3. Stage Balance (Target Weight: 25)
        let hasStages = (sleep.deepSleepTime > 0 || sleep.remSleepTime > 0 || sleep.lightSleepTime > 0)
        if hasStages {
            let deepPct = sleep.deepSleepTime / totalTimeAsleep
            let remPct = sleep.remSleepTime / totalTimeAsleep
            
            // Distance penalty. Deep ~13-23%, REM ~20-25%
            func scoreStage(actual: Double, idealRange: ClosedRange<Double>) -> Double {
                if idealRange.contains(actual) { return 1.0 }
                let dist = min(abs(actual - idealRange.lowerBound), abs(actual - idealRange.upperBound))
                // Penalty: 0.1 for every 1% off -> max penalty at 10% off
                return max(0.0, 1.0 - (dist * 10.0))
            }
            
            let deepScoreNorm = scoreStage(actual: deepPct, idealRange: 0.13...0.23)
            let remScoreNorm = scoreStage(actual: remPct, idealRange: 0.20...0.25)
            
            let stageScoreNorm = (deepScoreNorm + remScoreNorm) / 2.0
            earnedPoints += stageScoreNorm * 25.0
            totalWeight += 25.0
        }
        
        // 4. Onset / Restlessness (Target Weight: 10)
        // If device provides it, penalize minutesToFallAsleep > 20, minutesAfterWakeUp > 10
        let onsetMin = sleep.minutesToFallAsleep / 60.0
        let afterWakeMin = sleep.minutesAfterWakeUp / 60.0
        
        // We only fold this in if we actually have onset data (many devices report >0 when measured)
        // Some devices omit it entirely. If both are exactly 0, we can assume it's unmeasured or perfect.
        // We'll include it always unless it's known missing, but since we default to 0, 0 is a perfect score.
        let onsetPenalty = max(0.0, (onsetMin - 20.0) / 40.0) // 0 at 20m, 1.0 at 60m
        let afterWakePenalty = max(0.0, (afterWakeMin - 10.0) / 20.0) // 0 at 10m, 1.0 at 30m
        
        let onsetScoreNorm = max(0.0, 1.0 - onsetPenalty - afterWakePenalty)
        earnedPoints += onsetScoreNorm * 10.0
        totalWeight += 10.0
        
        // 5. HRV Integration (Target Weight: 5)
        if let rmssd = sleep.deepSleepRMSSD, rmssd > 0 {
            // Very simple proxy for deep sleep RMSSD. Normal is 20-100 depending on person.
            // Since we don't have baseline here, we'll score 0.5 (neutral) for typical, higher for better.
            let rmssdNorm = max(0.0, min(1.0, (rmssd - 15.0) / 40.0)) // 15ms = 0 score, 55ms = 1.0 score
            earnedPoints += rmssdNorm * 5.0
            totalWeight += 5.0
        }
        
        // Re-normalize to 100
        let finalScore = (earnedPoints / totalWeight) * 100.0
        return Int(min(100.0, max(0.0, round(finalScore))))
    }
}
