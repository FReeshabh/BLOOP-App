import Foundation

class RecoveryScoreEngine {
    
    /// Calculates the Recovery Score based on the Z-score method.
    /// Returns a `RecoveryScore` that includes both the computed score and all raw values.
    func calculateScore(currentHRV: Double, currentRHR: Double, currentRespRate: Double,
                        hrvBaseline: (mean: Double, sd: Double),
                        rhrBaseline: (mean: Double, sd: Double),
                        respRateBaseline: (mean: Double, sd: Double),
                        date: Date = Date()) -> RecoveryScore {
        
        let hrvZ = calculateZScore(value: currentHRV, mean: hrvBaseline.mean, sd: hrvBaseline.sd)
        // RHR and Respiratory Rate: lower is better, so invert Z-score
        let rhrZ = -calculateZScore(value: currentRHR, mean: rhrBaseline.mean, sd: rhrBaseline.sd)
        let respZ = -calculateZScore(value: currentRespRate, mean: respRateBaseline.mean, sd: respRateBaseline.sd)
        
        let weightedSum = (0.7 * hrvZ) + (0.2 * rhrZ) + (0.1 * respZ)
        
        // Normalize: map a typical weighted sum range (e.g. -3.0 to 3.0) to 0-100
        // A weightedSum of 0 represents normal baseline (score around 50)
        let rawScore = 50.0 + (weightedSum * 16.6)
        
        let finalScore = max(0, min(100, Int(round(rawScore))))
        
        return RecoveryScore(
            date: date,
            score: finalScore,
            currentHRV: currentHRV,
            currentRHR: currentRHR,
            currentRespRate: currentRespRate,
            baselineHRV: hrvBaseline.mean,
            baselineRHR: rhrBaseline.mean,
            baselineRespRate: respRateBaseline.mean,
            hrvZScore: hrvZ,
            rhrZScore: rhrZ,
            respiratoryRateZScore: respZ
        )
    }
    
    private func calculateZScore(value: Double, mean: Double, sd: Double) -> Double {
        guard sd > 0 else { return 0 }
        return (value - mean) / sd
    }
}
