import Foundation
import GoalsDomain

/// Cached wrapper around HealthKitSleepDataSource
/// Checks cache first, then fetches only missing data from HealthKit
public actor CachedHealthKitSleepDataSource: HealthKitSleepDataSourceProtocol, CachingDataSourceWrapper {
    public let remote: HealthKitSleepDataSource
    public let cache: DataCache

    public init(remote: HealthKitSleepDataSource, cache: DataCache) {
        self.remote = remote
        self.cache = cache
    }

    // MARK: - Configuration passthrough provided by CachingDataSourceWrapper

    public func fetchLatestMetricValue(for metricKey: String) async throws -> Double? {
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
        // Get cached data to determine what's missing
        let cachedSummaries = try await fetchCached(SleepDailySummary.self, from: startDate, to: endDate)
        let cachedDates = Set(cachedSummaries.map { Calendar.current.startOfDay(for: $0.date) })

        // Calculate and fetch missing ranges
        let missingRanges = calculateMissingDateRanges(from: startDate, to: endDate, cachedDates: cachedDates)
        for range in missingRanges {
            let remoteSummaries = try await remote.fetchSleepData(from: range.start, to: range.end)
            if !remoteSummaries.isEmpty {
                try await cache.store(remoteSummaries)
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
