import Foundation
import GoalsDomain

/// Cached wrapper around HealthKitSleepDataSource
/// Uses DateBasedStrategy for incremental fetching (past sleep data doesn't change)
///
/// Note: Previously used gap-filling which had iteration issues for large date ranges.
/// Sleep data is immutable once recorded, so date-based incremental is simpler and more efficient.
public actor CachedHealthKitSleepDataSource: HealthKitSleepDataSourceProtocol, CachingDataSourceWrapper {
    public let remote: HealthKitSleepDataSource
    public let cache: DataCache

    /// Strategy for incremental fetching.
    /// Sleep records are immutable once recorded, so we only need to fetch recent data.
    public let incrementalStrategy = DateBasedStrategy(
        strategyKey: "healthkit.sleep",
        volatileWindowDays: 1
    )

    public init(remote: HealthKitSleepDataSource, cache: DataCache) {
        self.remote = remote
        self.cache = cache
    }

    // MARK: - Configuration passthrough provided by CachingDataSourceWrapper

    public func fetchLatestMetricValue(for metricKey: String, taskId: UUID?) async throws -> Double? {
        guard let summary = try await fetchLatestSleep() else { return nil }
        return metricValue(for: metricKey, from: summary)
    }

    // MARK: - Authorization (passthrough)

    public func requestAuthorization() async throws -> Bool {
        try await remote.requestAuthorization()
    }

    public func isAuthorized() async -> Bool {
        await remote.isAuthorized()
    }

    // MARK: - HealthKitSleepDataSourceProtocol

    public func fetchSleepData(from startDate: Date, to endDate: Date) async throws -> [SleepDailySummary] {
        // Calculate fetch range using strategy
        let fetchRange = try await calculateIncrementalFetchRange(for: (startDate, endDate))

        do {
            let remoteSummaries = try await remote.fetchSleepData(from: fetchRange.start, to: fetchRange.end)
            if !remoteSummaries.isEmpty {
                try await cache.store(remoteSummaries)
            }
            try await recordSuccessfulFetch(range: (fetchRange.start, fetchRange.end))
        } catch {
            // Don't fail if we have cached data
            let cachedSummaries = try await fetchCached(SleepDailySummary.self, from: startDate, to: endDate)
            if cachedSummaries.isEmpty {
                throw error
            }
        }

        // Single source of truth: always return from cache
        return try await fetchCached(SleepDailySummary.self, from: startDate, to: endDate)
    }

    public func fetchLatestSleep() async throws -> SleepDailySummary? {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        let summaries = try await fetchSleepData(from: startDate, to: endDate)
        return summaries.last
    }

    // MARK: - Cache-Only Methods (for instant display)

    public func fetchCachedSleepData(from startDate: Date, to endDate: Date) async throws -> [SleepDailySummary] {
        try await fetchCached(SleepDailySummary.self, from: startDate, to: endDate)
    }

    public func hasCachedData() async throws -> Bool {
        try await hasCached(SleepDailySummary.self)
    }
}
