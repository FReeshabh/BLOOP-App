import Foundation
import SwiftData

@Model
final class RecoveryScoreEntity {
    var id: UUID
    var date: Date
    var score: Int
    
    // Raw values
    var currentHRV: Double
    var currentRHR: Double
    var currentRespRate: Double
    
    // Baselines
    var baselineHRV: Double
    var baselineRHR: Double
    var baselineRespRate: Double
    
    // Z-scores
    var hrvZScore: Double
    var rhrZScore: Double
    var respiratoryRateZScore: Double
    var bandRawValue: String
    
    init(id: UUID = UUID(),
         date: Date,
         score: Int,
         currentHRV: Double,
         currentRHR: Double,
         currentRespRate: Double,
         baselineHRV: Double,
         baselineRHR: Double,
         baselineRespRate: Double,
         hrvZScore: Double,
         rhrZScore: Double,
         respiratoryRateZScore: Double,
         bandRawValue: String) {
        self.id = id
        self.date = date
        self.score = score
        self.currentHRV = currentHRV
        self.currentRHR = currentRHR
        self.currentRespRate = currentRespRate
        self.baselineHRV = baselineHRV
        self.baselineRHR = baselineRHR
        self.baselineRespRate = baselineRespRate
        self.hrvZScore = hrvZScore
        self.rhrZScore = rhrZScore
        self.respiratoryRateZScore = respiratoryRateZScore
        self.bandRawValue = bandRawValue
    }
    
    var band: RecoveryBand? {
        RecoveryBand(rawValue: bandRawValue)
    }
}
