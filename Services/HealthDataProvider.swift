import Foundation

protocol HealthDataProvider {
    func fetchDataPoints(for dataType: HealthDataType,
                         from startDate: Date,
                         to endDate: Date) async throws -> [HealthDataPoint]

    func fetchReconciledDataPoints(for dataType: HealthDataType,
                                   from startDate: Date,
                                   to endDate: Date) async throws -> [HealthDataPoint]

    /// Returns the most recent sleep session (used for the Overview/Sleep detail view).
    func fetchSleepData(from startDate: Date, to endDate: Date) async throws -> SleepData?

    /// Returns one HealthDataPoint per day whose `value` is `totalTimeAsleep` in seconds.
    /// This is used by the Trends chart so sleep duration is treated like any other metric.
    func fetchSleepDataPoints(from startDate: Date, to endDate: Date) async throws -> [HealthDataPoint]
}
