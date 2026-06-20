import Foundation
import SwiftData

@Model
final class UserBaselineEntity {
    var id: UUID
    var typeRawValue: String
    var mean: Double
    var standardDeviation: Double
    var lastUpdated: Date
    
    init(id: UUID = UUID(), typeRawValue: String, mean: Double, standardDeviation: Double, lastUpdated: Date = Date()) {
        self.id = id
        self.typeRawValue = typeRawValue
        self.mean = mean
        self.standardDeviation = standardDeviation
        self.lastUpdated = lastUpdated
    }
    
    var type: HealthDataType? {
        HealthDataType(rawValue: typeRawValue)
    }
}
