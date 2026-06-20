import Foundation

/// Represents a single sleep session with stage breakdown.
struct SleepData: Identifiable, Codable {
    var id: UUID = UUID()
    let date: Date
    
    // Timing
    let bedTime: Date
    let wakeTime: Date
    let totalTimeInBed: TimeInterval   // seconds
    let totalTimeAsleep: TimeInterval  // seconds
    
    // Sleep stages (durations in seconds)
    let awakeTime: TimeInterval
    let lightSleepTime: TimeInterval
    let remSleepTime: TimeInterval
    let deepSleepTime: TimeInterval
    
    // Targets & scoring
    let sleepNeed: TimeInterval        // personalized target in seconds (default 8h)
    var apiScore: Int?                 // Provided by API
    
    /// Sleep performance as a percentage of sleep need achieved.
    var sleepPerformance: Int {
        if let apiScore = apiScore, apiScore > 0 {
            return apiScore
        }
        guard sleepNeed > 0 else { return 0 }
        return min(100, Int(round((totalTimeAsleep / sleepNeed) * 100)))
    }
    
    /// Sleep efficiency: time asleep / time in bed.
    var sleepEfficiency: Int {
        guard totalTimeInBed > 0 else { return 0 }
        return min(100, Int(round((totalTimeAsleep / totalTimeInBed) * 100)))
    }
    
    /// Formatted hours/minutes for a time interval.
    static func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    /// Sleep performance band (mirrors recovery band logic).
    var performanceBand: SleepPerformanceBand {
        if sleepPerformance >= 85 { return .optimal }
        else if sleepPerformance >= 70 { return .adequate }
        else { return .poor }
    }
}

enum SleepPerformanceBand: String, Codable {
    case optimal   // 85-100%
    case adequate  // 70-84%
    case poor      // 0-69%
    
    var colorHex: String {
        switch self {
        case .optimal: return "00E08F"
        case .adequate: return "FFC700"
        case .poor: return "FF334B"
        }
    }
    
    var label: String {
        switch self {
        case .optimal: return "OPTIMAL"
        case .adequate: return "ADEQUATE"
        case .poor: return "POOR"
        }
    }
}
