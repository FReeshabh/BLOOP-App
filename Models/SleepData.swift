import Foundation

struct SleepScoreBreakdown: Codable, Equatable {
    let totalSleep: Int
    let efficiency: Int
    let deepSleep: Int
    let remSleep: Int
    let latency: Int?
    let timing: Int
    
    var compositeScore: Int {
        if let latencyScore = latency {
            let weighted = Double(totalSleep) * 0.25 +
                           Double(efficiency) * 0.20 +
                           Double(deepSleep) * 0.15 +
                           Double(remSleep) * 0.15 +
                           Double(latencyScore) * 0.10 +
                           Double(timing) * 0.15
            return Int(min(100.0, max(0.0, round(weighted))))
        } else {
            let weighted = Double(totalSleep) * 0.25 +
                           Double(efficiency) * 0.20 +
                           Double(deepSleep) * 0.15 +
                           Double(remSleep) * 0.15 +
                           Double(timing) * 0.15
            return Int(min(100.0, max(0.0, round(weighted / 0.90))))
        }
    }
}

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
    
    // Onset and restlessness
    let minutesToFallAsleep: TimeInterval // seconds
    let minutesAfterWakeUp: TimeInterval // seconds
    
    // Additional metrics
    var deepSleepRMSSD: Double? // From DailyHeartRateVariability if available
    
    // Targets & scoring
    let sleepNeed: TimeInterval        // personalized target in seconds (default 8h)
    var computedScore: Int?            // Calculated externally via SleepScoreEngine
    var scoreBreakdown: SleepScoreBreakdown?
    
    /// Note: Google Health / Health Connect does not provide a native sleep score.
    /// This score is always app-computed using the SleepScoreEngine, based on efficiency,
    /// duration, stage balance, and onset.
    var sleepPerformance: Int {
        if let breakdown = scoreBreakdown {
            return breakdown.compositeScore
        }
        return computedScore ?? 0
    }
    
    /// Hours vs Need as a percentage of sleep need achieved.
    var hoursVsNeed: Int {
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
    
    /// Sleep performance band.
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
