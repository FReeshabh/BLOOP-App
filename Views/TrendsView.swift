import SwiftUI

/// Hearth-style Trends view — historical data browser with metric picker, period toggle, and chart.
struct TrendsView: View {
    @StateObject private var viewModel = TrendsViewModel()
    @State private var showMetricPicker = false
    @State private var showSecondaryMetricPicker = false

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    trendsHeader

                    // Metric Picker
                    metricPickerButton
                    
                    // Secondary Metric Picker
                    secondaryMetricPickerButton

                    // Average + Period Toggle
                    averageAndPeriodSection

                    // Date Range Navigator
                    dateRangeNavigator

                    // Chart
                    if viewModel.isLoading {
                        chartLoadingView
                    } else if viewModel.periodAverages.isEmpty {
                        chartEmptyView
                    } else {
                        chartView
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .task {
            if viewModel.dataPoints.isEmpty {
                await viewModel.loadData()
            }
        }
        .sheet(isPresented: $showMetricPicker) {
            metricPickerSheet
        }
        .sheet(isPresented: $showSecondaryMetricPicker) {
            secondaryMetricPickerSheet
        }
    }

    // MARK: - Header

    private var trendsHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: "FFC700"))
                    .frame(width: 10, height: 10)
                Text("TRENDS")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1)
            }

            Spacer()

            Text("\(viewModel.totalDays) days")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }

    // MARK: - Metric Picker

    private var metricPickerButton: some View {
        Button(action: { showMetricPicker = true }) {
            HStack {
                Image(systemName: viewModel.selectedMetric.icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "00E08F"))

                Text(viewModel.selectedMetric.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Secondary Metric Picker

    private var secondaryMetricPickerButton: some View {
        HStack {
            if let secondaryMetric = viewModel.selectedSecondaryMetric {
                Button(action: { showSecondaryMetricPicker = true }) {
                    HStack {
                        Image(systemName: secondaryMetric.icon)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "5B86E5"))

                        Text(secondaryMetric.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                }
                
                Button(action: {
                    viewModel.selectedSecondaryMetric = nil
                    Task { await viewModel.loadData() }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.leading, 8)
                }
            } else {
                Button(action: { showSecondaryMetricPicker = true }) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)

                        Text("Compare with another metric")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round, dash: [4, 4]))
                    )
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Average + Period

    private var averageAndPeriodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AVERAGE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
                .tracking(1)

            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.formattedAverage)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(viewModel.selectedMetric.unit)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)

                Spacer()

                // Period toggle
                HStack(spacing: 0) {
                    ForEach(TrendsViewModel.TimePeriod.allCases) { period in
                        Button(action: {
                            viewModel.selectedPeriod = period
                            Task { await viewModel.loadData() }
                        }) {
                            Text(period.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(viewModel.selectedPeriod == period ? .black : .gray)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    viewModel.selectedPeriod == period ?
                                    Color.white : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Date Range Navigator

    private var dateRangeNavigator: some View {
        HStack {
            Button(action: { viewModel.navigatePeriod(forward: false) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(viewModel.dateRangeString)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            Button(action: { viewModel.navigatePeriod(forward: true) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Chart

    private var chartView: some View {
        VStack(spacing: 16) {
            // Chart header: axis unit label
            HStack {
                Text("PER PERIOD")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray.opacity(0.5))
                    .tracking(1)
                Spacer()
                Text(viewModel.selectedMetric.unit.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "FFC700").opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: "FFC700").opacity(0.1))
                    .clipShape(Capsule())
            }

            // Bar chart of period averages
            GeometryReader { geometry in
                let isZoomed = viewModel.selectedMetric != .sleepDuration && viewModel.selectedMetric != .steps
                let allVals = viewModel.periodAverages.map(\.average)
                let maxVal = allVals.max() ?? 1
                let minVal = isZoomed ? (allVals.min() ?? 0) * 0.95 : 0
                let range = max(maxVal - minVal, 1)
                
                // For secondary metric line
                let secAllVals = viewModel.secondaryPeriodAverages.map(\.average)
                let secMaxVal = secAllVals.max() ?? 1
                let secMinVal = isZoomed ? (secAllVals.min() ?? 0) * 0.95 : 0
                let secRange = max(secMaxVal - secMinVal, 1)

                let barWidth = max(20, (geometry.size.width - CGFloat(viewModel.periodAverages.count - 1) * 8) / CGFloat(max(viewModel.periodAverages.count, 1)))

                ZStack {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(viewModel.periodAverages) { period in
                            VStack(spacing: 6) {
                                // Value label
                                Text(viewModel.formatValue(period.average))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)

                                // Percent change
                                if let change = period.percentChange {
                                    let isGood = viewModel.selectedMetric.isLowerBetter ? change < 0 : change > 0
                                    Text(String(format: "%+.0f%%", change))
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(isGood ? Color(hex: "00E08F") : Color(hex: "FF334B"))
                                } else {
                                    Text(" ")
                                        .font(.system(size: 9, weight: .semibold))
                                }

                                // Bar
                                let barHeight = max(4, geometry.size.height * 0.5 * CGFloat((period.average - minVal) / range))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "FFC700").opacity(0.5), Color(hex: "FFC700")],
                                            startPoint: .bottom,
                                            endPoint: .top
                                        )
                                    )
                                    .frame(width: min(barWidth, 50), height: barHeight)

                                // Label
                                Text(period.label)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // Secondary line overlay
                    if viewModel.selectedSecondaryMetric != nil, viewModel.secondaryPeriodAverages.count == viewModel.periodAverages.count {
                        Path { path in
                            let count = viewModel.periodAverages.count
                            let stepX = geometry.size.width / CGFloat(count)
                            for i in 0..<count {
                                let x = stepX * CGFloat(i) + stepX / 2.0
                                let avg = viewModel.secondaryPeriodAverages[i].average
                                // The Y goes from top (0) to bottom (height) for drawing, but our bar area is roughly the bottom 50%
                                // We'll map the line to the same height scale:
                                let h = geometry.size.height * 0.5 * CGFloat((avg - secMinVal) / secRange)
                                // Top of bar area is at geometry.size.height - h - text offsets
                                // Let's just draw it within the chart area:
                                let y = geometry.size.height - 20 - h // 20 roughly for the bottom label
                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color(hex: "5B86E5"), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        
                        // Dots for the secondary line
                        let count = viewModel.periodAverages.count
                        let stepX = geometry.size.width / CGFloat(count)
                        ForEach(0..<count, id: \.self) { i in
                            let x = stepX * CGFloat(i) + stepX / 2.0
                            let avg = viewModel.secondaryPeriodAverages[i].average
                            let h = geometry.size.height * 0.5 * CGFloat((avg - secMinVal) / secRange)
                            let y = geometry.size.height - 20 - h
                            Circle()
                                .fill(Color(hex: "5B86E5"))
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)
                        }
                    }
                }
            }
            .frame(height: 180)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }

    private var chartLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .gray))
            Text("Loading trend data...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(height: 180)
    }

    private var chartEmptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.3))
            Text("No historical data available for this period")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray.opacity(0.5))
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
        )
        .padding(.horizontal)
    }

    // MARK: - Metric Picker Sheets

    private var metricPickerSheet: some View {
        NavigationView {
            ZStack {
                Color(white: 0.08).edgesIgnoringSafeArea(.all)

                List {
                    ForEach(TrendsViewModel.TrendMetric.allCases) { metric in
                        Button(action: {
                            viewModel.selectedMetric = metric
                            showMetricPicker = false
                            Task { await viewModel.loadData() }
                        }) {
                            HStack {
                                Image(systemName: metric.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: "00E08F"))
                                    .frame(width: 28)

                                Text(metric.rawValue)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)

                                Spacer()

                                if viewModel.selectedMetric == metric {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(hex: "00E08F"))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Select Metric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showMetricPicker = false }
                        .foregroundColor(Color(hex: "00E08F"))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var secondaryMetricPickerSheet: some View {
        NavigationView {
            ZStack {
                Color(white: 0.08).edgesIgnoringSafeArea(.all)

                List {
                    ForEach(TrendsViewModel.TrendMetric.allCases) { metric in
                        Button(action: {
                            viewModel.selectedSecondaryMetric = metric
                            showSecondaryMetricPicker = false
                            Task { await viewModel.loadData() }
                        }) {
                            HStack {
                                Image(systemName: metric.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: "5B86E5"))
                                    .frame(width: 28)

                                Text(metric.rawValue)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)

                                Spacer()

                                if viewModel.selectedSecondaryMetric == metric {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(hex: "5B86E5"))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Select Secondary Metric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showSecondaryMetricPicker = false }
                        .foregroundColor(Color(hex: "5B86E5"))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
