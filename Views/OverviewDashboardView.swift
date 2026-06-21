import SwiftUI
import SwiftData

/// The main Overview dashboard — Hearth-inspired unified view with 3 score rings + metric cards.
struct OverviewDashboardView: View {
    @StateObject private var viewModel = OverviewViewModel()
    @Environment(\.modelContext) private var modelContext

    @State private var showReadinessDetail = false
    @State private var showSleepDetail = false
    @State private var showLoadDetail = false
    @State private var showHeartRateDetail = false
    @State private var showActivitiesDetail = false
    @State private var showStressDetail = false

    var body: some View {
        ZStack {
            // Background
            Color.black.edgesIgnoringSafeArea(.all)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.errorMessage != nil {
                        errorView
                    } else {
                        overviewContent
                    }
                }
                .padding(.bottom, 40)
            }
            .refreshable {
                await viewModel.loadData(modelContext: modelContext)
            }
        }
        .task {
            if viewModel.recoveryScore == nil && viewModel.sleepData == nil {
                await viewModel.loadData(modelContext: modelContext)
            }
        }
        .sheet(isPresented: $showReadinessDetail) {
            if let score = viewModel.recoveryScore {
                ReadinessDetailView(
                    score: score,
                    sleepDuration: viewModel.sleepData?.totalTimeAsleep
                )
            }
        }
        .sheet(isPresented: $showSleepDetail) {
            SleepDetailView(
                sleep: viewModel.sleepData,
                naps: viewModel.todayNaps,
                selectedDate: Binding(
                    get: { viewModel.selectedDate },
                    set: { newDate in
                        viewModel.selectedDate = newDate
                        Task {
                            await viewModel.loadData(modelContext: modelContext)
                        }
                    }
                ),
                onDateChange: { _ in }
            )
        }
        .sheet(isPresented: $showLoadDetail) {
            if let strain = viewModel.strainData {
                LoadDetailView(strain: strain)
            }
        }
        .sheet(isPresented: $showHeartRateDetail) {
            HeartRateDetailView(
                heartRateData: viewModel.todayHeartRateData,
                restingHeartRate: viewModel.restingHeartRate
            )
        }
        .sheet(isPresented: $showActivitiesDetail) {
            if let activities = viewModel.strainData?.activities {
                ActivitiesDetailView(activities: activities)
            }
        }
        .sheet(isPresented: $showStressDetail) {
            if let strain = viewModel.strainData, let recovery = viewModel.recoveryScore {
                StressDetailView(
                    stressLevel: viewModel.estimatedStress,
                    strain: strain,
                    recovery: recovery
                )
            }
        }
        .sheet(isPresented: $viewModel.showHistoricalSyncPrompt) {
            historicalSyncPrompt
        }
        .overlay {
            if viewModel.isSyncingHistoricalData {
                syncProgressOverlay
            }
        }
    }

    // MARK: - Overview Content

    @ViewBuilder
    private var overviewContent: some View {
        // Header
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: "00E08F"))
                    .frame(width: 10, height: 10)
                Text("BLOOP")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1)
            }

            Spacer()

            HStack(spacing: 6) {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { viewModel.selectedDate },
                        set: { newDate in
                            viewModel.selectedDate = newDate
                            Task {
                                await viewModel.loadData(modelContext: modelContext)
                            }
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
        }
        .padding(.horizontal)
        .padding(.top, 12)

        // Daily Insight Card
        InsightCardView(
            headline: viewModel.insightHeadline,
            explanation: viewModel.insightExplanation
        )
        .padding(.horizontal)

        // Three Score Rings — show "–" when data hasn't arrived yet
        ScoreRingsRowView(
            sleepScore: viewModel.sleepScore,
            readinessScore: viewModel.readinessScore,
            loadScore: viewModel.loadScore,
            hasSleepData: viewModel.sleepData != nil,
            hasReadinessData: viewModel.recoveryScore != nil,
            hasLoadData: viewModel.strainData != nil,
            isReadinessCalculating: viewModel.isReadinessCalculating,
            onSleepTap: { if viewModel.sleepData != nil { showSleepDetail = true } },
            onReadinessTap: { if viewModel.recoveryScore != nil { showReadinessDetail = true } },
            onLoadTap: { if viewModel.strainData != nil { showLoadDetail = true } }
        )
        .padding(.top, 4)

        // Metric Cards Grid
        metricCardsGrid
            .padding(.horizontal)

        // Last updated
        if let score = viewModel.recoveryScore {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                Text("Updated \(score.date.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.gray.opacity(0.4))
            .padding(.top, 8)
        }
    }

    // MARK: - Metric Cards Grid

    private var metricCardsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            // Heart Rate - primary is resting, secondary is current
            if !viewModel.todayHeartRateData.isEmpty {
                Button(action: {
                    showHeartRateDetail = true
                }) {
                    OverviewMetricCardView(
                        icon: "heart.fill",
                        iconColor: Color(hex: "FF6B6B"),
                        title: "Heart rate",
                        value: viewModel.restingHeartRate.map { String(format: "%.0f", $0) } ?? "--",
                        unit: viewModel.restingHeartRate != nil ? "bpm" : "",
                        subtitle: viewModel.currentHeartRate.map { "Current \($0) bpm" } ?? "No data",
                        isLive: true
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Steps
            if viewModel.todaySteps > 0 {
                OverviewMetricCardView(
                    icon: "figure.walk",
                    iconColor: Color(hex: "5B86E5"),
                    title: "Steps",
                    value: formatSteps(viewModel.todaySteps),
                    subtitle: stepsSubtitle
                )
            }

            // Zone Minutes
            if viewModel.activeZoneMinutes > 0 {
                Button(action: {
                    showActivitiesDetail = true
                }) {
                    OverviewMetricCardView(
                        icon: "heart.circle.fill",
                        iconColor: Color(hex: "FFC700"),
                        title: "Zone minutes",
                        value: String(format: "%.0f", viewModel.activeZoneMinutes),
                        unit: "min",
                        subtitle: "Above average",
                        showChevron: false
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Optimal Load
            Button(action: {
                showLoadDetail = true
            }) {
                OverviewMetricCardView(
                    icon: "bolt.horizontal.fill",
                    iconColor: Color(hex: "5B86E5"),
                    title: "Optimal load",
                    value: String(format: "%.0f", viewModel.currentLoadPosition),
                    unit: "",
                    subtitle: "Range \(Int(viewModel.optimalLoadRange.lowerBound))-\(Int(viewModel.optimalLoadRange.upperBound))",
                    showChevron: true
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Stress gauge
            if viewModel.strainData != nil && viewModel.recoveryScore != nil {
                Button(action: {
                    showStressDetail = true
                }) {
                    StressGaugeCardView(stressLevel: viewModel.estimatedStress)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var stepsSubtitle: String {
        let steps = viewModel.todaySteps
        if steps > 0 {
            return "\(formatSteps(steps)) today"
        }
        return "Goal 10,000"
    }

    private func formatSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 24) {
            // Animated placeholder rings
            HStack(spacing: 20) {
                ForEach(0..<3) { _ in
                    Circle()
                        .stroke(Color.gray.opacity(0.12), lineWidth: 10)
                        .frame(width: 100, height: 100)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .gray.opacity(0.3)))
                        )
                }
            }
            .padding(.top, 60)

            Text("Analyzing your vitals...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.gray)
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Color(hex: "FF334B"))
            }

            VStack(spacing: 8) {
                Text("Connection Required")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(viewModel.errorMessage ?? "Unknown error")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: {
                Task {
                    await viewModel.loadData(modelContext: modelContext)
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.headline)
                    Text("Retry Connection")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.white, Color(hex: "E0E0E0")]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                )
                .shadow(color: Color.white.opacity(0.15), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.top, 60)
    }

    // MARK: - Historical Sync

    private var historicalSyncPrompt: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "00E08F"))

            Text("Sync Historical Data")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("To provide accurate recovery insights, BLOOP needs to analyze your 60-day baseline data.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                Task { await viewModel.syncHistoricalData() }
            }) {
                Text("Start Sync")
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "00E08F"))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)

            Button(action: {
                viewModel.showHistoricalSyncPrompt = false
                UserDefaults.standard.set(true, forKey: "hasPromptedForHistoricalSync")
            }) {
                Text("Skip for Now")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.1).edgesIgnoringSafeArea(.all))
    }

    private var syncProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                ProgressView(value: viewModel.historicalSyncProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "00E08F")))
                    .padding(.horizontal, 40)

                Text("Syncing Baseline Data...")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("\(Int(viewModel.historicalSyncProgress * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(32)
            .background(Color(white: 0.15))
            .cornerRadius(16)
            .shadow(radius: 20)
        }
    }
}

// MARK: - Button Style (keep accessible)

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
