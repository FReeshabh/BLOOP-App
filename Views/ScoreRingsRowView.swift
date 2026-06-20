import SwiftUI

/// Hearth-style row of 3 animated score rings: Sleep, Readiness, Load.
struct ScoreRingsRowView: View {
    let sleepScore: Int
    let readinessScore: Int
    let loadScore: Int

    /// When false, the corresponding ring shows "–" instead of "0" so the
    /// user knows data simply hasn't loaded yet.
    var hasSleepData: Bool = true
    var hasReadinessData: Bool = true
    var hasLoadData: Bool = true

    var isReadinessCalculating: Bool = false

    var onSleepTap: (() -> Void)?
    var onReadinessTap: (() -> Void)?
    var onLoadTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            ScoreRingView(
                score: sleepScore,
                label: "Sleep",
                icon: "moon.fill",
                ringColor: Color(hex: "4A90D9"),
                showPercent: true,
                hasData: hasSleepData
            )
            .onTapGesture { onSleepTap?() }

            ScoreRingView(
                score: readinessScore,
                label: "Readiness",
                icon: "gauge.with.dots.needle.33percent",
                ringColor: Color(hex: "00E08F"),
                showPercent: false,
                hasData: hasReadinessData,
                isCalculating: isReadinessCalculating
            )
            .onTapGesture { onReadinessTap?() }

            ScoreRingView(
                score: loadScore,
                label: "Load",
                icon: "bolt.fill",
                ringColor: Color(hex: "5B86E5"),
                showPercent: false,
                hasData: hasLoadData,
                isCalculating: false
            )
            .onTapGesture { onLoadTap?() }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Individual Score Ring

struct ScoreRingView: View {
    let score: Int
    let label: String
    let icon: String
    let ringColor: Color
    let showPercent: Bool
    /// When false, shows "–" in the centre and keeps the ring empty (progress = 0).
    var hasData: Bool = true
    /// When true, shows "Calculating..." state.
    var isCalculating: Bool = false

    @State private var animatedProgress: CGFloat = 0

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background track always visible
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 10)

                if isCalculating {
                    // Muted gray dashed ring for calculating state
                    Circle()
                        .stroke(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 10, dash: [8, 8]))
                } else if hasData {
                    // Animated progress arc
                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    ringColor.opacity(0.4),
                                    ringColor.opacity(0.7),
                                    ringColor
                                ]),
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }

                // Center text
                VStack(spacing: 0) {
                    if isCalculating {
                        Text("...")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.gray.opacity(0.4))
                    } else if hasData {
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text("\(score)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            if showPercent {
                                Text("%")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                                    .baselineOffset(10)
                            }
                        }
                    } else {
                        Text("–")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                }
            }
            .frame(width: 100, height: 100)

            // Label
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Text(isCalculating ? "Calculating" : label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard hasData else { return }
            withAnimation(.easeInOut(duration: 1.2).delay(0.2)) {
                animatedProgress = CGFloat(min(score, 100)) / 100.0
            }
        }
        .onChange(of: score) { _, newValue in
            guard hasData else {
                animatedProgress = 0; return
            }
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedProgress = CGFloat(min(newValue, 100)) / 100.0
            }
        }
        .onChange(of: hasData) { _, newHasData in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = newHasData ? CGFloat(min(score, 100)) / 100.0 : 0
            }
        }
    }
}
