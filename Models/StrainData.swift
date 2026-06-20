import Foundation

/// Represents strain data for a day, including HR zone breakdown and activities.
struct StrainData: Identifiable, Codable {
    var id: UUID = UUID()
    let date: Date
    
    /// Day strain on WHOOP's 0–21 logarithmic scale.
    let dayStrain: Double
    
    // Heart rate zone minutes
    let zone1Minutes: Double  // Light: 50-60% max HR
    let zone2Minutes: Double  // Moderate: 60-70%
    let zone3Minutes: Double  // Hard: 70-80%
    let zone4Minutes: Double  // Threshold: 80-90%
    let zone5Minutes: Double  // Max: 90-100%
    
    // Activity summary
    let caloriesBurned: Double
    let steps: Int
    let distance: Double      // miles (converted from meters by OverviewViewModel)
    let activeZoneMinutes: Double
    
    // Individual activities
    let activities: [ActivitySession]
    
    /// Total time in all zones.
    var totalZoneMinutes: Double {
        zone1Minutes + zone2Minutes + zone3Minutes + zone4Minutes + zone5Minutes
    }
    
    /// Strain band for color-coding.
    var strainBand: StrainBand {
        if dayStrain >= 18 { return .allOut }
        else if dayStrain >= 14 { return .high }
        else if dayStrain >= 10 { return .moderate }
        else { return .light }
    }
}

struct ActivitySession: Identifiable, Codable {
    var id: UUID = UUID()
    let name: String
    let startTime: Date
    let duration: TimeInterval   // seconds
    let activityStrain: Double   // 0–21
    let caloriesBurned: Double
    let averageHR: Double        // bpm
    let maxHR: Double            // bpm
}

enum StrainBand: String, Codable {
    case light     // 0-9
    case moderate  // 10-13
    case high      // 14-17
    case allOut    // 18-21
    
    var colorHex: String {
        switch self {
        case .light: return "5B86E5"
        case .moderate: return "00E08F"
        case .high: return "FFC700"
        case .allOut: return "FF334B"
        }
    }
    
    var label: String {
        switch self {
        case .light: return "LIGHT"
        case .moderate: return "MODERATE"
        case .high: return "HIGH"
        case .allOut: return "ALL OUT"
        }
    }
}
