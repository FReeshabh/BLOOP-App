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

                    // Metric Picker
                    metricPickerButton

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

                    // Sign out link
                    signOutSection

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
                let maxVal = viewModel.periodAverages.map(\.average).max() ?? 1
                let barWidth = max(20, (geometry.size.width - CGFloat(viewModel.periodAverages.count - 1) * 8) / CGFloat(max(viewModel.periodAverages.count, 1)))

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(viewModel.periodAverages) { period in
                        VStack(spacing: 6) {
                            // Value label — sleep shown as "Xh Ym", others as a number
                            Text(viewModel.formatValue(period.average))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            // Percent change
                            if let change = period.percentChange {
                                Text(String(format: "%+.0f%%", change))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(change >= 0 ? Color(hex: "FFC700") : Color(hex: "FF334B"))
                            }

                            // Bar
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "FFC700").opacity(0.5), Color(hex: "FFC700")],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(
                                    width: min(barWidth, 50),
                                    height: max(4, geometry.size.height * 0.5 * CGFloat(period.average / maxVal))
                                )

                            // Label
                            Text(period.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
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

    // MARK: - Sign Out

    private var signOutSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                AuthManager.shared.signOut()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14))
                    Text("Sign out")
                        .font(.system(size: 14, weight: .medium))
                        .underline()
                }
                .foregroundColor(.gray)
            }

            // Data range info
            let formatter = DateFormatter()
            let _ = formatter.dateFormat = "yyyy-MM-dd"
            Text("\(formatter.string(from: viewModel.dateRangeStart)) → \(formatter.string(from: viewModel.dateRangeEnd)) · Readiness, Sleep quality & Load are estimates.")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.gray.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 16)
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
}
