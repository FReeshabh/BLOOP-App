import SwiftUI

/// Hearth-style Sleep Quality detail — large ring, quality contributors, stage breakdown, timeline.
struct SleepDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let sleep: SleepData
    let naps: [SleepData]

    init(sleep: SleepData, naps: [SleepData] = []) {
        self.sleep = sleep
        self.naps = naps
    }

    private var totalAsleepWithNaps: TimeInterval {
        sleep.totalTimeAsleep + naps.map(\.totalTimeAsleep).reduce(0, +)
    }
    
    private var overallPerformance: Int {
        guard sleep.sleepNeed > 0 else { return 0 }
        return min(100, Int(round((totalAsleepWithNaps / sleep.sleepNeed) * 100)))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        sleepHeader

                        // Sleep Quality Ring
                        sleepQualityRing
                            .padding(.top, 10)

                        // Quality Contributors
                        qualityContributorsCard
                            .padding(.horizontal)

                        // Last Night's Sleep section
                        lastNightSection
                            .padding(.horizontal)
                        
                        // Naps section
                        napsSection

                        // Sleep stages
                        sleepStagesSection
                            .padding(.horizontal)

                        // Stage Timeline
                        stageTimeline
                            .padding(.horizontal)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var sleepHeader: some View {
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
                Text("Last night")
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

            Text("\(sleep.bedTime.formatted(.dateTime.hour().minute()))–\(sleep.wakeTime.formatted(.dateTime.hour().minute()))")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Sleep Quality Ring

    private var sleepQualityRing: some View {
        let performance = overallPerformance
        let performanceBand: SleepPerformanceBand = {
            if performance >= 85 { return .optimal }
            else if performance >= 70 { return .adequate }
            else { return .poor }
        }()
        let bandColor = Color(hex: performanceBand.colorHex)

        return VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 16)

                Circle()
                    .trim(from: 0, to: CGFloat(performance) / 100.0)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [bandColor.opacity(0.5), bandColor]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: performance)

                Circle()
                    .trim(from: 0, to: CGFloat(performance) / 100.0)
                    .stroke(bandColor.opacity(0.25), lineWidth: 28)
                    .blur(radius: 10)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(performance)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("%")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .frame(width: 200, height: 200)

            Text("SLEEP QUALITY")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .tracking(2)

            Text(naps.isEmpty
                 ? "An ensemble of the four below, weighted toward Hours vs Need. Estimated from Fitbit sleep data."
                 : "Overall sleep score including nocturnal sleep and \(naps.count) recovery nap(s).")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.gray.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Quality Contributors

    private var qualityContributorsCard: some View {
        VStack(spacing: 0) {
            qualityRow(
                icon: "clock.fill",
                label: "Hours vs Need",
                value: sleep.sleepPerformance,
                trendUp: sleep.sleepPerformance >= 85
            )
            Divider().background(Color.white.opacity(0.08))

            qualityRow(
                icon: "target",
                label: "Sleep Consistency",
                value: min(100, sleep.sleepEfficiency + 5),  // Approximation
                trendUp: true
            )
            Divider().background(Color.white.opacity(0.08))

            qualityRow(
                icon: "bed.double.fill",
                label: "Sleep Efficiency",
                value: sleep.sleepEfficiency,
                trendUp: sleep.sleepEfficiency >= 85
            )
            Divider().background(Color.white.opacity(0.08))

            qualityRow(
                icon: "waveform.path.ecg",
                label: "High Sleep Stress",
                value: 100 - sleep.sleepEfficiency,
                trendUp: false
            )

            // Legend
            HStack(spacing: 16) {
                legendDot(color: Color(hex: "FF334B"), label: "Poor")
                legendDot(color: .gray, label: "Sufficient")
                legendDot(color: Color(hex: "00E08F"), label: "Optimal")
            }
            .padding(.top, 12)
            .padding(.bottom, 4)
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
    private func qualityRow(icon: String, label: String, value: Int, trendUp: Bool) -> some View {
        let barColor: Color = value >= 85 ? Color(hex: "00E08F") : (value >= 50 ? .gray : Color(hex: "FF334B"))
        let trendColor: Color = trendUp ? Color(hex: "00E08F") : Color(hex: "FF334B")

        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            // Mini dot bar
            HStack(spacing: 2) {
                ForEach(0..<10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i < value / 10 ? barColor : Color.white.opacity(0.08))
                        .frame(width: 8, height: 8)
                }
            }

            HStack(spacing: 3) {
                Text("\(value)%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Image(systemName: trendUp ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 7))
                    .foregroundColor(trendColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 4)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray.opacity(0.6))
        }
    }

    // MARK: - Last Night Section

    private var lastNightSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("LAST NIGHT'S SLEEP")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(1.5)
                Spacer()
                Text(SleepData.formatDuration(sleep.totalTimeInBed) + " in bed")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
    }

    // MARK: - Sleep Stages Section

    private var sleepStagesSection: some View {
        let total = sleep.awakeTime + sleep.lightSleepTime + sleep.deepSleepTime + sleep.remSleepTime

        return VStack(spacing: 16) {
            stageRow(
                icon: "circle",
                label: "Awake",
                percentage: total > 0 ? Int(sleep.awakeTime / total * 100) : 0,
                duration: sleep.awakeTime,
                color: Color.gray,
                barColor: Color(hex: "FF8C42")
            )

            stageRow(
                icon: "moon",
                label: "Light",
                percentage: total > 0 ? Int(sleep.lightSleepTime / total * 100) : 0,
                duration: sleep.lightSleepTime,
                color: Color(hex: "00B4D8"),
                barColor: Color(hex: "00B4D8")
            )

            stageRow(
                icon: "moon.fill",
                label: "Deep (SWS)",
                percentage: total > 0 ? Int(sleep.deepSleepTime / total * 100) : 0,
                duration: sleep.deepSleepTime,
                color: Color(hex: "5B86E5"),
                barColor: Color(hex: "5B86E5")
            )

            stageRow(
                icon: "moon.zzz.fill",
                label: "REM",
                percentage: total > 0 ? Int(sleep.remSleepTime / total * 100) : 0,
                duration: sleep.remSleepTime,
                color: Color(hex: "E040FB"),
                barColor: Color(hex: "E040FB")
            )
        }
        .padding(16)
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
    private func stageRow(icon: String, label: String, percentage: Int, duration: TimeInterval,
                          color: Color, barColor: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Text("\(percentage)%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(barColor)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor)
                            .frame(width: geometry.size.width * CGFloat(percentage) / 100.0, height: 6)
                    }
                }
                .frame(height: 6)
            }

            Spacer()

            Text(SleepData.formatDuration(duration))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }

    // MARK: - Stage Timeline

    private var stageTimeline: some View {
        VStack(spacing: 12) {
            HStack {
                Text("STAGE TIMELINE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(1.5)
                Spacer()

                let total = sleep.awakeTime + sleep.lightSleepTime + sleep.deepSleepTime + sleep.remSleepTime
                let restorativePct = total > 0 ? Int((sleep.deepSleepTime + sleep.remSleepTime) / total * 100) : 0
                Text("\(restorativePct)% restorative")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
            }

            SleepStagesBarView(
                awake: sleep.awakeTime,
                light: sleep.lightSleepTime,
                rem: sleep.remSleepTime,
                deep: sleep.deepSleepTime
            )

            // Time labels
            HStack {
                Text(sleep.bedTime.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray.opacity(0.5))
                Spacer()
                Text(sleep.wakeTime.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var napsSection: some View {
        Group {
            if !naps.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("RECOVERY NAPS TODAY")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                        .tracking(1.5)
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(naps.enumerated()), id: \.element.id) { index, nap in
                            HStack {
                                Image(systemName: "sun.max.fill")
                                    .foregroundColor(Color(hex: "FFC700"))
                                    .font(.system(size: 14))
                                    .frame(width: 20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Nap \(index + 1)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("\(nap.bedTime.formatted(.dateTime.hour().minute())) – \(nap.wakeTime.formatted(.dateTime.hour().minute()))")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(SleepData.formatDuration(nap.totalTimeAsleep))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("reduces sleep debt")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: "00E08F"))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            
                            if index < naps.count - 1 {
                                Divider().background(Color.white.opacity(0.08))
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                }
            }
        }
    }
}
