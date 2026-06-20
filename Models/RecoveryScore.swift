import Foundation

enum RecoveryBand: String, Codable {
    case green // 67-100%
    case yellow // 34-66%
    case red // 0-33%
    
    var colorHex: String {
        switch self {
        case .green:
            return "00E08F"
        case .yellow:
            return "FFC700"
        case .red:
            return "FF334B"
        }
    }
    
    var label: String {
        switch self {
        case .green: return "GREEN"
        case .yellow: return "YELLOW"
        case .red: return "RED"
        }
    }
}

struct RecoveryScore: Identifiable, Codable {
    var id: UUID = UUID()
    let date: Date
    let score: Int // 0-100
    
    // Raw values (user-facing)
    let currentHRV: Double       // milliseconds
    let currentRHR: Double       // beats per minute
    let currentRespRate: Double  // breaths per minute
    
    // Personal baselines (for trend comparison)
    let baselineHRV: Double
    let baselineRHR: Double
    let baselineRespRate: Double
    
    // Z-scores (internal, used by engine)
    let hrvZScore: Double
    let rhrZScore: Double
    let respiratoryRateZScore: Double
    
    var band: RecoveryBand {
        if score >= 67 {
            return .green
        } else if score >= 34 {
            return .yellow
        } else {
            return .red
        }
    }
    
    /// Returns the delta of each metric vs. baseline (positive = better for recovery).
    /// For HRV: higher is better, so delta = current - baseline.
    /// For RHR/Resp: lower is better, so delta = baseline - current (inverted).
    var hrvDelta: Double { currentHRV - baselineHRV }
    var rhrDelta: Double { baselineRHR - currentRHR }
    var respRateDelta: Double { baselineRespRate - currentRespRate }
    
    /// Normalizes each metric's z-score to a 0–100 contribution scale.
    /// A z-score of 0 = 50 (baseline), clamped to 0–100.
    var hrvContribution: Int {
        Int(max(0, min(100, 50.0 + hrvZScore * 16.6)).rounded())
    }
    var rhrContribution: Int {
        Int(max(0, min(100, 50.0 + rhrZScore * 16.6)).rounded())
    }
    var respRateContribution: Int {
        Int(max(0, min(100, 50.0 + respiratoryRateZScore * 16.6)).rounded())
    }
}
