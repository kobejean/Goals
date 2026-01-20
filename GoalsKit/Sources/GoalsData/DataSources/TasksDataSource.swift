import Foundation
import GoalsDomain

/// Data source for task time tracking metrics
/// Since tasks are stored locally, this doesn't need remote/caching layers
@MainActor
public final class TasksDataSource: DataSourceRepositoryProtocol, Sendable {
    public let dataSourceType: DataSourceType = .tasks

    private let taskRepository: TaskRepositoryProtocol

    public nonisolated var availableMetrics: [MetricInfo] {
        [
            MetricInfo(key: "dailyDuration", name: "Daily Duration", unit: "min", icon: "timer"),
            MetricInfo(key: "sessionCount", name: "Sessions Today", unit: "", icon: "number"),
            MetricInfo(key: "totalDuration", name: "Total Duration", unit: "hrs", icon: "clock"),
        ]
    }

    public init(taskRepository: TaskRepositoryProtocol) {
        self.taskRepository = taskRepository
    }

    // MARK: - Configuration (always configured since data is local)

    public func isConfigured() async -> Bool {
        true
    }

    public func configure(settings: DataSourceSettings) async throws {
        // No configuration needed - data is local
    }

    public func clearConfiguration() async throws {
        // No configuration to clear
    }

    // MARK: - Metric Fetching

    public func fetchLatestMetricValue(for metricKey: String) async throws -> Double? {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now

        let sessions = try await taskRepository.fetchSessions(from: startOfDay, to: endOfDay)

        switch metricKey {
        case "dailyDuration":
            // Total duration today in minutes
            let totalMinutes = sessions.totalDuration / 60.0
            return totalMinutes

        case "sessionCount":
            // Number of completed sessions today
            return Double(sessions.filter { !$0.isActive }.count)

        case "totalDuration":
            // All-time total in hours (not just today)
            let allSessions = try await fetchAllSessions()
            let totalHours = allSessions.totalDuration / 3600.0
            return totalHours

        default:
            return nil
        }
    }

    public nonisolated func metricValue(for key: String, from stats: Any) -> Double? {
        // For tasks, we don't have a stats object - data comes directly from repository
        nil
    }

    // MARK: - Private Helpers

    private func fetchAllSessions() async throws -> [TaskSession] {
        // Fetch sessions from the beginning of time
        let startDate = Date.distantPast
        let endDate = Date()
        return try await taskRepository.fetchSessions(from: startDate, to: endDate)
    }
}
