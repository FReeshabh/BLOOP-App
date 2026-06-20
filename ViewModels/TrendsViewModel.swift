import Foundation
import SwiftUI

/// Data point for trend charts.
struct TrendDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

/// A grouped period average for display.
struct PeriodAverage: Identifiable {
    let id = UUID()
    let label: String       // e.g. "Mar", "Apr"
    let average: Double
    let percentChange: Double?  // vs previous period
}

@MainActor
final class TrendsViewModel: ObservableObject {

    // MARK: - Types

    enum TrendMetric: String, CaseIterable, Identifiable {
        case restingHeartRate  = "Resting heart rate"
        case hrv               = "Heart rate variability"
        case sleepDuration     = "Sleep duration"
        case steps             = "Steps"
        case respiratoryRate   = "Respiratory rate"
        case weight            = "Weight"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .restingHeartRate: return "heart.fill"
            case .hrv:             return "waveform.path.ecg"
            case .sleepDuration:   return "moon.fill"
            case .steps:           return "figure.walk"
            case .respiratoryRate: return "lungs.fill"
            case .weight:          return "scalemass.fill"
            }
        }

        var unit: String {
            switch self {
            case .restingHeartRate: return "bpm"
            case .hrv:             return "ms"
            case .sleepDuration:   return "h/m"  // values are formatted as "Xh Ym"
            case .steps:           return "steps"
            case .respiratoryRate: return "br/min"
            case .weight:          return "lbs"
            }
        }

        var healthDataType: HealthDataType {
            switch self {
            case .restingHeartRate: return .dailyRestingHeartRate
            case .hrv:             return .dailyHeartRateVariability
            case .sleepDuration:   return .sleep
            case .steps:           return .steps
            case .respiratoryRate: return .respiratoryRate
            case .weight:          return .weight
            }
        }
        
        var isLowerBetter: Bool {
            switch self {
            case .restingHeartRate, .weight, .respiratoryRate: return true
            case .hrv, .sleepDuration, .steps: return false
            }
        }
    }

    enum TimePeriod: String, CaseIterable, Identifiable {
        case week     = "W"
        case month    = "M"
        case sixMonth = "6M"

        var id: String { rawValue }

        var days: Int {
            switch self {
            case .week:     return 7
            case .month:    return 30
            case .sixMonth: return 180
            }
        }
    }

    // MARK: - Published State

    @Published var selectedMetric: TrendMetric = .restingHeartRate
    @Published var selectedSecondaryMetric: TrendMetric? = nil
    @Published var selectedPeriod: TimePeriod = .sixMonth
    @Published var dataPoints: [TrendDataPoint] = []
    @Published var secondaryDataPoints: [TrendDataPoint] = []
    @Published var periodAverages: [PeriodAverage] = []
    @Published var secondaryPeriodAverages: [PeriodAverage] = []
    @Published var overallAverage: Double = 0
    @Published var totalDays: Int = 0
    @Published var isLoading: Bool = false
    @Published var dateRangeStart: Date = Date()
    @Published var dateRangeEnd: Date = Date()

    // MARK: - Dependencies

    private let healthService: HealthDataProvider
    private let authManager: AuthManager

    init(healthService: HealthDataProvider = GoogleHealthService(),
         authManager: AuthManager = .shared) {
        self.healthService = healthService
        self.authManager = authManager
    }

    // MARK: - Formatted Strings

    var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: dateRangeStart)) – \(formatter.string(from: dateRangeEnd))"
    }

    var formattedAverage: String {
        formatValue(overallAverage)
    }

    /// Formats a raw metric value for display. Sleep values (seconds) are shown as "Xh Ym";
    /// all others use numeric formatting appropriate to the metric.
    func formatValue(_ value: Double) -> String {
        if selectedMetric == .sleepDuration {
            let hours = Int(value) / 3600
            let mins  = (Int(value) % 3600) / 60
            return "\(hours)h \(mins)m"
        }
        return String(format: selectedMetric == .respiratoryRate ? "%.1f" : "%.0f", value)
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true

        do {
            if !authManager.isAuthenticated {
                try await authManager.signIn()
            }

            let now = Date()
            let calendar = Calendar.current
            let startDate = calendar.date(byAdding: .day, value: -selectedPeriod.days, to: now)!

            dateRangeStart = startDate
            dateRangeEnd = now

            // Sleep duration uses a dedicated fetch that returns one point per day (value = seconds asleep).
            // All other metrics use the generic fetchDataPoints path.
            let fetched: [HealthDataPoint]
            if selectedMetric == .sleepDuration {
                fetched = try await healthService.fetchSleepDataPoints(from: startDate, to: now)
            } else {
                fetched = try await healthService.fetchDataPoints(
                    for: selectedMetric.healthDataType,
                    from: startDate,
                    to: now
                )
            }

            let filtered = fetched.filter { $0.startTime >= startDate }
            self.dataPoints = filtered.map { TrendDataPoint(date: $0.startTime, value: $0.value) }
                .sorted { $0.date < $1.date }
            self.totalDays = selectedPeriod.days

            // Calculate overall average
            if !filtered.isEmpty {
                self.overallAverage = filtered.map(\.value).reduce(0, +) / Double(filtered.count)
            } else {
                self.overallAverage = 0
            }

            // Group into period averages
            self.periodAverages = computePeriodAverages(from: filtered, period: selectedPeriod, startDate: startDate)

            // Fetch Secondary Metric if selected
            if let secondary = selectedSecondaryMetric {
                let secFetched: [HealthDataPoint]
                if secondary == .sleepDuration {
                    secFetched = try await healthService.fetchSleepDataPoints(from: startDate, to: now)
                } else {
                    secFetched = try await healthService.fetchDataPoints(
                        for: secondary.healthDataType,
                        from: startDate,
                        to: now
                    )
                }
                let secFiltered = secFetched.filter { $0.startTime >= startDate }
                self.secondaryDataPoints = secFiltered.map { TrendDataPoint(date: $0.startTime, value: $0.value) }
                    .sorted { $0.date < $1.date }
                self.secondaryPeriodAverages = computePeriodAverages(from: secFiltered, period: selectedPeriod, startDate: startDate)
            } else {
                self.secondaryDataPoints = []
                self.secondaryPeriodAverages = []
            }

        } catch {
            print("Trends fetch error: \(error)")
            self.dataPoints = []
            self.secondaryDataPoints = []
            self.overallAverage = 0
            self.periodAverages = []
            self.secondaryPeriodAverages = []
        }

        isLoading = false
    }

    func navigatePeriod(forward: Bool) {
        let calendar = Calendar.current
        let offset = forward ? selectedPeriod.days : -selectedPeriod.days
        dateRangeStart = calendar.date(byAdding: .day, value: offset, to: dateRangeStart)!
        dateRangeEnd   = calendar.date(byAdding: .day, value: offset, to: dateRangeEnd)!
        Task { await loadData() }
    }

    // MARK: - Helpers

    private func computePeriodAverages(from points: [HealthDataPoint], period: TimePeriod, startDate: Date) -> [PeriodAverage] {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        let groupedByMonth: [Int: [HealthDataPoint]]
        switch period {
        case .week:
            formatter.dateFormat = "EEE"
            var averages: [PeriodAverage] = []
            for i in 0..<7 {
                let dayStart = calendar.date(byAdding: .day, value: i, to: calendar.startOfDay(for: startDate))!
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                let bucketPoints = points.filter { $0.startTime >= dayStart && $0.startTime < dayEnd }
                let avg = bucketPoints.isEmpty ? 0 : bucketPoints.map(\.value).reduce(0, +) / Double(bucketPoints.count)
                
                let change: Double? = {
                    guard i > 0 else { return nil }
                    let prevDayStart = calendar.date(byAdding: .day, value: i - 1, to: calendar.startOfDay(for: startDate))!
                    let prevPoints = points.filter { $0.startTime >= prevDayStart && $0.startTime < dayStart }
                    let prevAvg = prevPoints.isEmpty ? 0 : prevPoints.map(\.value).reduce(0, +) / Double(prevPoints.count)
                    return prevAvg > 0 ? ((avg - prevAvg) / prevAvg * 100) : 0
                }()
                let label = formatter.string(from: dayStart)
                averages.append(PeriodAverage(label: label, average: avg, percentChange: change))
            }
            return averages

        case .month:
            formatter.dateFormat = "MMM d"
            // Group by week
            let grouped = Dictionary(grouping: points) { calendar.component(.weekOfYear, from: $0.startTime) }
            return grouped.sorted { $0.key < $1.key }.enumerated().map { index, pair in
                let avg = pair.value.map(\.value).reduce(0, +) / Double(pair.value.count)
                let label = pair.value.first.map { formatter.string(from: $0.startTime) } ?? "W\(pair.key)"
                return PeriodAverage(label: label, average: avg, percentChange: nil)
            }

        case .sixMonth:
            formatter.dateFormat = "MMM"
            groupedByMonth = Dictionary(grouping: points) { calendar.component(.month, from: $0.startTime) }
            return groupedByMonth.sorted { $0.key < $1.key }.enumerated().map { index, pair in
                let avg = pair.value.map(\.value).reduce(0, +) / Double(pair.value.count)
                let prevAvg: Double? = index > 0 ? {
                    let prevPair = groupedByMonth.sorted { $0.key < $1.key }[index - 1]
                    return prevPair.value.map(\.value).reduce(0, +) / Double(prevPair.value.count)
                }() : nil
                let change = prevAvg.map { prev in prev > 0 ? ((avg - prev) / prev * 100) : 0 }
                let label = pair.value.first.map { formatter.string(from: $0.startTime) } ?? "\(pair.key)"
                return PeriodAverage(label: label, average: avg, percentChange: change)
            }
        }
    }
}
