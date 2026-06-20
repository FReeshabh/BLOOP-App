import SwiftUI

/// Hearth-style Trends view — historical data browser with metric picker, period toggle, and chart.
struct TrendsView: View {
    @StateObject private var viewModel = TrendsViewModel()
    @State private var showMetricPicker = false

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    trendsHeader

                    // Metric Picker Chips
                    metricChipsRow

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

    // MARK: - Metric Chips

    private var metricChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TrendsViewModel.TrendMetric.allCases.prefix(5)) { metric in
                    let isSelected = viewModel.selectedMetric == metric
                    let accentColor = Color(hex: metric.colorHex)
                    
                    Button(action: {
                        viewModel.selectedMetric = metric
                        Task { await viewModel.loadData() }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: metric.icon)
                                .font(.system(size: 12))
                            Text(metric.rawValue)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundColor(isSelected ? accentColor : .gray)
                        .background(
                            isSelected ? accentColor.opacity(0.15) : Color.white.opacity(0.06)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isSelected ? accentColor.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                
                // More chip
                if TrendsViewModel.TrendMetric.allCases.count > 5 {
                    Button(action: { showMetricPicker = true }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(.horizontal)
        }
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
                    .foregroundColor(Color(hex: viewModel.selectedMetric.colorHex).opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: viewModel.selectedMetric.colorHex).opacity(0.1))
                    .clipShape(Capsule())
            }

            // Line chart
            GeometryReader { geometry in
                let accentColor = Color(hex: viewModel.selectedMetric.colorHex)
                let validVals = viewModel.periodAverages.compactMap { $0.average }
                let scaleMode = viewModel.selectedMetric.scaleMode
                
                let maxVal = validVals.max() ?? 1
                let minVal: Double = {
                    if validVals.isEmpty { return 0 }
                    if scaleMode == .zeroBased { return 0 }
                    // tight scaling: add slight padding
                    let currentMin = validVals.min() ?? 0
                    let range = maxVal - currentMin
                    return max(0, currentMin - (range * 0.1)) // 10% padding below
                }()
                let range = max(maxVal - minVal, 1)

                let count = viewModel.periodAverages.count
                let stepX = count > 1 ? geometry.size.width / CGFloat(count) : geometry.size.width
                
                // Gridlines (3 lines: top, middle, bottom)
                let gridlines = [maxVal, minVal + (range / 2), minVal]
                
                ZStack {
                    // Background gridlines and labels
                    ForEach(0..<gridlines.count, id: \.self) { i in
                        let val = gridlines[i]
                        let h = geometry.size.height * 0.7 * CGFloat((val - minVal) / range)
                        let y = geometry.size.height - 35 - h
                        
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width - 30, y: y))
                        }
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        
                        Text(viewModel.formatValue(val))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.gray.opacity(0.6))
                            .position(x: geometry.size.width - 10, y: y)
                    }

                    // Connecting Line
                    Path { path in
                        var firstPoint = true
                        for i in 0..<count {
                            let item = viewModel.periodAverages[i]
                            if let avg = item.average {
                                let x = stepX * CGFloat(i) + stepX / 2.0
                                let h = geometry.size.height * 0.7 * CGFloat((avg - minVal) / range)
                                let y = geometry.size.height - 35 - h
                                
                                if firstPoint {
                                    path.move(to: CGPoint(x: x, y: y))
                                    firstPoint = false
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            } else {
                                firstPoint = true // Break the line for missing data
                            }
                        }
                    }
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // Points and X-Axis Labels
                    ForEach(0..<count, id: \.self) { i in
                        let item = viewModel.periodAverages[i]
                        let x = stepX * CGFloat(i) + stepX / 2.0
                        let isMostRecent = i == count - 1
                        
                        if let avg = item.average {
                            let h = geometry.size.height * 0.7 * CGFloat((avg - minVal) / range)
                            let y = geometry.size.height - 35 - h
                            
                            // Point Marker
                            if isMostRecent {
                                // Emphasized point
                                Circle()
                                    .fill(accentColor.opacity(0.3))
                                    .frame(width: 14, height: 14)
                                    .position(x: x, y: y)
                                Circle()
                                    .fill(accentColor)
                                    .frame(width: 8, height: 8)
                                    .position(x: x, y: y)
                            } else {
                                // Regular hollow point
                                Circle()
                                    .stroke(accentColor, lineWidth: 2)
                                    .background(Circle().fill(Color.black))
                                    .frame(width: 8, height: 8)
                                    .position(x: x, y: y)
                            }
                            
                            // Point Value Label (optional, currently disabled to avoid clutter)
                            /*
                            Text(viewModel.formatValue(avg))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .position(x: x, y: y - 16)
                            */
                        }
                        
                        // X-Axis Label
                        VStack(spacing: 2) {
                            Text(item.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray)
                            if let subLabel = item.subLabel {
                                Text(subLabel)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                        }
                        .position(x: x, y: geometry.size.height - 10)
                    }
                }
            }
            .frame(height: 200)
            
            // Missing Data Caption
            if viewModel.periodAverages.contains(where: { $0.average == nil }) {
                let missingCount = viewModel.periodAverages.filter { $0.average == nil }.count
                Text("\(missingCount) period(s) — no data synced.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray.opacity(0.7))
                    .padding(.top, 4)
            }
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
        .frame(height: 200)
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
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
        )
        .padding(.horizontal)
    }

    // MARK: - Metric Picker Sheet

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
                                    .foregroundColor(Color(hex: metric.colorHex))
                                    .frame(width: 28)

                                Text(metric.rawValue)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)

                                Spacer()

                                if viewModel.selectedMetric == metric {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(hex: metric.colorHex))
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
                        .foregroundColor(Color(hex: viewModel.selectedMetric.colorHex))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
