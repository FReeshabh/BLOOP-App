import Foundation
import SwiftData

@Model
final class HealthDataPointEntity {
    var id: UUID
    var typeRawValue: String
    var value: Double
    var startTime: Date
    var endTime: Date
    var source: String
    
    init(id: UUID = UUID(), typeRawValue: String, value: Double, startTime: Date, endTime: Date, source: String) {
        self.id = id
        self.typeRawValue = typeRawValue
        self.value = value
        self.startTime = startTime
        self.endTime = endTime
        self.source = source
    }
    
    var type: HealthDataType? {
        HealthDataType(rawValue: typeRawValue)
    }
}
