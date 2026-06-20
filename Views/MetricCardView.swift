import SwiftUI

/// A single health metric card showing the actual value, unit, and trend vs. baseline.
struct MetricCardView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: Double
    let unit: String
    let delta: Double
    let formatSpec: String
    
    /// Convenience initializer with default format spec.
    init(icon: String, iconColor: Color, title: String, value: Double, unit: String, delta: Double, formatSpec: String = "%.0f") {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.value = value
        self.unit = unit
        self.delta = delta
        self.formatSpec = formatSpec
    }
    
    private var trendIcon: String {
        if delta > 0.5 { return "arrow.up.right" }
        else if delta < -0.5 { return "arrow.down.right" }
        else { return "arrow.right" }
    }
    
    private var trendColor: Color {
        // For HRV, up is good. For RHR/Resp, delta is already inverted (positive = good).
        if delta > 0.5 { return Color(hex: "00E08F") }
        else if delta < -0.5 { return Color(hex: "FF334B") }
        else { return .gray }
    }
    
    @State private var showDetails = false
    
    var body: some View {
        Button(action: { showDetails = true }) {
            HStack(spacing: 14) {
                // Metric icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                // Metric name
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: formatSpec, value))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(unit)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Trend indicator
                HStack(spacing: 4) {
                    Image(systemName: trendIcon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(trendColor)
                    
                    Text(String(format: "%+.1f", delta))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(trendColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(trendColor.opacity(0.12))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showDetails) {
            MetricDetailView(title: title, value: value, unit: unit, icon: icon, iconColor: iconColor)
        }
    }
}

struct MetricDetailView: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let value: Double
    let unit: String
    let icon: String
    let iconColor: Color
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "050510").edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 30) {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: icon)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                    .padding(.top, 40)
                    
                    VStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Current Measurement")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", value))
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(unit)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("DATA SOURCE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(1.5)
                        
                        HStack {
                            Image(systemName: "cross.case.fill")
                                .foregroundColor(.gray)
                            Text("Google Health API")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 20))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// Container that shows all three core metric cards.
struct MetricCardsSection: View {
    let score: RecoveryScore
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("VITALS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(1.5)
                
                Spacer()
                
                Text("vs. baseline")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .padding(.horizontal, 4)
            
            MetricCardView(
                icon: "waveform.path.ecg",
                iconColor: Color(hex: "6C5CE7"),
                title: "Heart Rate Variability",
                value: score.currentHRV,
                unit: "ms",
                delta: score.hrvDelta,
                formatSpec: "%.0f"
            )
            
            MetricCardView(
                icon: "heart.fill",
                iconColor: Color(hex: "FF6B6B"),
                title: "Resting Heart Rate",
                value: score.currentRHR,
                unit: "bpm",
                delta: score.rhrDelta,
                formatSpec: "%.0f"
            )
            
            MetricCardView(
                icon: "lungs.fill",
                iconColor: Color(hex: "00B4D8"),
                title: "Respiratory Rate",
                value: score.currentRespRate,
                unit: "br/min",
                delta: score.respRateDelta,
                formatSpec: "%.1f"
            )
        }
        .padding(.horizontal)
    }
}
