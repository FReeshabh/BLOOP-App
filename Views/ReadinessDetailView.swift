import SwiftUI

/// Hearth-style Readiness detail view — large ring + vitals list with averages and trends.
struct ReadinessDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let score: RecoveryScore
    let sleepDuration: TimeInterval?

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Date header
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }

                            Spacer()

                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                Text("Today")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())

                            Spacer()

                            Text("vs prior 30 days")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Large recovery ring
                        RecoveryRingView(score: score)
                            .padding(.top, 10)

                        // Insight description
                        Text(insightText)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 8)

                        // Vitals card
                        vitalsCard
                            .padding(.horizontal)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Insight Text

    private var insightText: String {
        switch score.band {
        case .green:
            return "Your HRV, resting HR, sleep and load balance are in a strong place today."
        case .yellow:
            return "Your vitals are in an adequate range. Consider moderate activity and prioritize good sleep."
        case .red:
            return "Your body is showing signs of stress. Prioritize rest, hydration, and recovery today."
        }
    }

    // MARK: - Vitals Card

    private var vitalsCard: some View {
        VStack(spacing: 0) {
            vitalRow(
                icon: "waveform.path.ecg",
                title: "Heart rate variability",
                value: String(format: "%.0f", score.currentHRV),
                unit: "ms",
                average: String(format: "avg %.0f ms", score.baselineHRV),
                delta: score.hrvDelta
            )

            Divider().background(Color.white.opacity(0.08))

            vitalRow(
                icon: "heart.fill",
                title: "Resting heart rate",
                value: String(format: "%.0f", score.currentRHR),
                unit: "bpm",
                average: String(format: "avg %.0f bpm", score.baselineRHR),
                delta: score.rhrDelta
            )

            Divider().background(Color.white.opacity(0.08))

            vitalRow(
                icon: "lungs.fill",
                title: "Respiratory rate",
                value: String(format: "%.1f", score.currentRespRate),
                unit: "br/min",
                average: String(format: "avg %.1f br/min", score.baselineRespRate),
                delta: score.respRateDelta
            )

            if let duration = sleepDuration {
                Divider().background(Color.white.opacity(0.08))

                let hours = Int(duration) / 3600
                let mins  = (Int(duration) % 3600) / 60
                // sleepNeed is 8 h — show as the target, not a historical average.
                let needHours = 8
                let needMins  = 0

                vitalRow(
                    icon: "moon.fill",
                    title: "Sleep duration",
                    value: "\(hours)h \(mins)m",
                    unit: "",
                    average: "need \(needHours)h \(needMins)m",
                    delta: (duration / 3600.0) - 8.0
                )
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func vitalRow(icon: String, title: String, value: String, unit: String,
                          average: String, delta: Double) -> some View {
        // delta is already directionally normalised at source:
        // HRV: higher is better, delta = current - baseline (positive = good)
        // RHR/Resp: already inverted, delta = baseline - current (positive = good)
        // Sleep: positive = above 8h need (good)
        let isPositive = delta > 0.5
        let isNegative = delta < -0.5
        let trendColor: Color = isPositive ? Color(hex: "00E08F") : (isNegative ? Color(hex: "FF334B") : .gray)
        let trendIcon = isPositive ? "arrowtriangle.up.fill" : (isNegative ? "arrowtriangle.down.fill" : "minus")

        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text(value)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }

                    Image(systemName: trendIcon)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(trendColor)
                }

                Text(average)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
