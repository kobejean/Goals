import Foundation
import GoalsDomain

/// Data source for location-based time tracking metrics
/// Since location data is stored locally, this doesn't need remote/caching layers
@MainActor
public final class LocationsDataSource: DataSourceRepositoryProtocol, Sendable {
    public let dataSourceType: DataSourceType = .locations

    private let locationRepository: LocationRepositoryProtocol

    public nonisolated var availableMetrics: [MetricInfo] {
        [
            MetricInfo(key: "dailyDuration", name: "Daily Tracked Time", unit: "min", icon: "timer"),
            MetricInfo(key: "sessionCount", name: "Sessions Today", unit: "", icon: "number"),
            MetricInfo(key: "totalDuration", name: "Total Tracked Time", unit: "hrs", icon: "location.fill"),
        ]
    }

    public init(locationRepository: LocationRepositoryProtocol) {
        self.locationRepository = locationRepository
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

    public func fetchLatestMetricValue(for metricKey: String, taskId: UUID?) async throws -> Double? {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now

        switch metricKey {
        case "dailyDuration":
            // Total duration today in minutes
            let sessions = try await locationRepository.fetchSessions(from: startOfDay, to: endOfDay)
            let totalMinutes = sessions.totalDuration / 60.0
            return totalMinutes

        case "sessionCount":
            // Number of completed sessions today
            let sessions = try await locationRepository.fetchSessions(from: startOfDay, to: endOfDay)
            return Double(sessions.filter { !$0.isActive }.count)

        case "totalDuration":
            // All-time total in hours
            let allSessions = try await locationRepository.fetchSessions(from: .distantPast, to: now)
            let totalHours = allSessions.totalDuration / 3600.0
            return totalHours

        default:
            return nil
        }
    }

    public nonisolated func metricValue(for key: String, from stats: Any) -> Double? {
        // For locations, we don't have a stats object - data comes directly from repository
        nil
    }
}
