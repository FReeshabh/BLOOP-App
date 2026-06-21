import SwiftUI

struct SleepDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let sleep: SleepData?
    let naps: [SleepData]
    @Binding var selectedDate: Date
    var onDateChange: ((Date) -> Void)?

    init(sleep: SleepData?, naps: [SleepData] = [], selectedDate: Binding<Date> = .constant(Date()), onDateChange: ((Date) -> Void)? = nil) {
        self.sleep = sleep
        self.naps = naps
        self._selectedDate = selectedDate
        self.onDateChange = onDateChange
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        sleepHeader

                        if let sleep = sleep {
                            // Last Night's Sleep section
                            lastNightSection(sleep: sleep)
                                .padding(.horizontal)

                            // Sleep stages (Primary Content)
                            sleepStagesSection(sleep: sleep)
                                .padding(.horizontal)

                            // Stage Timeline
                            stageTimeline(sleep: sleep)
                                .padding(.horizontal)

                            // Sleep Metrics
                            sleepMetricsCard(sleep: sleep)
                                .padding(.horizontal)

                            // Naps section
                            napsSection
                        } else {
                            // Empty State
                            VStack(spacing: 16) {
                                Image(systemName: "bed.double.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("No sleep data")
                                    .font(.title2.weight(.bold))
                                    .foregroundColor(.white)
                                Text("There is no sleep data synced from Health Connect for this night.")
                                    .font(.body)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 100)
                            .padding(.horizontal, 32)
                        }

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
                DatePicker(
                    "",
                    selection: Binding(
                        get: { selectedDate },
                        set: { newDate in
                            selectedDate = newDate
                            onDateChange?(newDate)
                        }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
                .colorInvert()
                .colorMultiply(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())

            Spacer()

            if let sleep = sleep {
                Text("\(sleep.bedTime.formatted(.dateTime.hour().minute()))–\(sleep.wakeTime.formatted(.dateTime.hour().minute()))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            } else {
                Text("--:--")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.clear) // Keep layout spacing
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Last Night Section

    private func lastNightSection(sleep: SleepData) -> some View {
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

    private func sleepStagesSection(sleep: SleepData) -> some View {
        let total = sleep.awakeTime + sleep.lightSleepTime + sleep.deepSleepTime + sleep.remSleepTime

        return VStack(spacing: 16) {
            if total > 0 {
                stageRow(
                    icon: "circle",
                    label: "Awake",
                    percentage: Int(sleep.awakeTime / total * 100),
                    duration: sleep.awakeTime,
                    color: Color.gray,
                    barColor: Color(hex: "FF8C42")
                )

                stageRow(
                    icon: "moon",
                    label: "Light",
                    percentage: Int(sleep.lightSleepTime / total * 100),
                    duration: sleep.lightSleepTime,
                    color: Color(hex: "00B4D8"),
                    barColor: Color(hex: "00B4D8")
                )

                stageRow(
                    icon: "moon.fill",
                    label: "Deep (SWS)",
                    percentage: Int(sleep.deepSleepTime / total * 100),
                    duration: sleep.deepSleepTime,
                    color: Color(hex: "5B86E5"),
                    barColor: Color(hex: "5B86E5")
                )

                stageRow(
                    icon: "moon.zzz.fill",
                    label: "REM",
                    percentage: Int(sleep.remSleepTime / total * 100),
                    duration: sleep.remSleepTime,
                    color: Color(hex: "E040FB"),
                    barColor: Color(hex: "E040FB")
                )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Sleep stage data not available from your device")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
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

    @ViewBuilder
    private func stageTimeline(sleep: SleepData) -> some View {
        let total = sleep.awakeTime + sleep.lightSleepTime + sleep.deepSleepTime + sleep.remSleepTime
        if total > 0 {
            VStack(spacing: 12) {
                HStack {
                    Text("STAGE TIMELINE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                        .tracking(1.5)
                    Spacer()

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
    }

    // MARK: - Sleep Metrics

    private func sleepMetricsCard(sleep: SleepData) -> some View {
        VStack(spacing: 0) {
            let goalDuration = sleep.sleepNeed > 0 ? sleep.sleepNeed : (8 * 3600)
            let durationTitle = SleepData.formatDuration(sleep.totalTimeAsleep)
            let goalTitle = SleepData.formatDuration(goalDuration)
            let progress = min(1.0, max(0.0, sleep.totalTimeAsleep / goalDuration))
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .frame(width: 20)

                    Text("Hours vs Goal")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    Spacer()
                    
                    Text("\(durationTitle) of \(goalTitle)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progress >= 1.0 ? Color(hex: "00E08F") : Color(hex: "5B86E5"))
                            .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Naps

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
