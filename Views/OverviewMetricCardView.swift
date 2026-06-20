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

    init(icon: String, iconColor: Color, title: String, value: String, unit: String = "",
         subtitle: String? = nil, showChevron: Bool = true) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.value = value
        self.unit = unit
        self.subtitle = subtitle
        self.showChevron = showChevron
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

                Text(stressLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(stressColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(stressColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            Spacer()

            // Mini gauge
            HStack {
                Spacer()
                miniGauge
                    .frame(width: 100, height: 55)
                Spacer()
            }

            Spacer()
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

    private var miniGauge: some View {
        ZStack {
            // Background arc
            ArcShape(startAngle: -180, endAngle: 0)
                .stroke(Color.gray.opacity(0.12), style: StrokeStyle(lineWidth: 8, lineCap: .round))

            // Gradient colored arc
            ArcShape(startAngle: -180, endAngle: -180 + (180 * stressLevel / 100.0))
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "00E08F"), Color(hex: "FFC700"), Color(hex: "FF334B")],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )

            // Needle dot
            let needleAngle = -180.0 + (180.0 * stressLevel / 100.0)
            let radians = needleAngle * .pi / 180.0
            let radius: CGFloat = 35
            let dotX = cos(radians) * radius
            let dotY = sin(radians) * radius

            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
                .shadow(color: .white.opacity(0.6), radius: 4)
                .offset(x: dotX, y: dotY + 10)
        }
    }
}
