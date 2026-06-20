import SwiftUI

/// Compact metric card for the Overview dashboard grid.
/// Displays icon, title, large value + unit, and an optional subtitle/chevron.
struct OverviewMetricCardView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let unit: String
    let subtitle: String?
    let showChevron: Bool
    let isLive: Bool

    init(icon: String, iconColor: Color, title: String, value: String, unit: String = "",
         subtitle: String? = nil, showChevron: Bool = true, isLive: Bool = false) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.value = value
        self.unit = unit
        self.subtitle = subtitle
        self.showChevron = showChevron
        self.isLive = isLive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top: icon + title + chevron
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(iconColor)

                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    if isLive {
                        PulsingDotView(color: Color(hex: "00E08F"))
                    }
                }

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }

            Spacer()

            // Value
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                }
            }

            // Subtitle
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Stress Gauge Mini Card

/// Small stress/strain semicircle gauge for the overview grid.
struct StressGaugeCardView: View {
    let stressLevel: Double  // 0–100

    private var stressColor: Color {
        if stressLevel < 33 { return Color(hex: "00E08F") }
        else if stressLevel < 66 { return Color(hex: "FFC700") }
        else { return Color(hex: "FF334B") }
    }

    private var stressLabel: String {
        if stressLevel < 20 { return "LOW" }
        else if stressLevel < 40 { return "MILD" }
        else if stressLevel < 60 { return "MED" }
        else if stressLevel < 80 { return "HIGH" }
        else { return "PEAK" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "FF6B6B"))

                    Text("Stress")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
            }

            Spacer()

            // Number & Badge
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.0f", stressLevel))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(stressLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(stressColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(stressColor.opacity(0.15))
                    .clipShape(Capsule())
                    .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 6 }
            }

            // Subtitle
            Text(stressLevel > 60 ? "Elevated today" : "Within normal range")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray.opacity(0.6))
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}


struct PulsingDotView: View {
    @State private var animate = false
    let color: Color
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .scaleEffect(animate ? 1.4 : 0.8)
            .opacity(animate ? 0.4 : 1.0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
    }
}
