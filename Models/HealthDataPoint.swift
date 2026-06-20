import Foundation

struct HealthDataPoint: Identifiable, Codable {
    var id: UUID = UUID()
    let type: HealthDataType
    let value: Double
    let startTime: Date
    let endTime: Date
    let source: String
}
