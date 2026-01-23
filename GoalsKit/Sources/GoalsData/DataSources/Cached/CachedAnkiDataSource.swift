import Foundation
import GoalsDomain

/// Cached wrapper around AnkiDataSource
/// Returns cached data when Anki isn't running, fetches fresh data when available
public actor CachedAnkiDataSource: AnkiDataSourceProtocol, CachingDataSourceWrapper {
    public let remote: AnkiDataSource
    public let cache: DataCache

    public init(remote: AnkiDataSource, cache: DataCache) {
        self.remote = remote
        self.cache = cache
    }

    // MARK: - Configuration passthrough provided by CachingDataSourceWrapper

    public func fetchLatestMetricValue(for metricKey: String, taskId: UUID?) async throws -> Double? {
        guard let stats = try await fetchLatestStats() else { return nil }
        return metricValue(for: metricKey, from: stats)
    }

    // MARK: - AnkiDataSourceProtocol

    public func fetchDailyStats(from startDate: Date, to endDate: Date) async throws -> [AnkiDailyStats] {
        // Get cached data to determine what's missing
        let cachedStats = try await fetchCached(AnkiDailyStats.self, from: startDate, to: endDate)

        // Always refetch today since new reviews can happen throughout the day
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let cachedDates = Set(cachedStats.map { calendar.startOfDay(for: $0.date) })
            .filter { $0 != today }

        // Calculate and fetch missing ranges
        let missingRanges = calculateMissingDateRanges(from: startDate, to: endDate, cachedDates: cachedDates)

        for range in missingRanges {
            do {
                let remoteStats = try await remote.fetchDailyStats(from: range.start, to: range.end)
                if !remoteStats.isEmpty {
                    try await cache.store(remoteStats)
                }
            } catch {
                // Don't fail if we already have cached data - use what we have
                // This is the graceful degradation for when Anki isn't running
                if !cachedStats.isEmpty {
                    break
                }
                // Only throw if we have no cached data at all
                throw error
            }
        }

        // Single source of truth: always return from cache
        return try await fetchCached(AnkiDailyStats.self, from: startDate, to: endDate)
    }

    public func fetchLatestStats() async throws -> AnkiDailyStats? {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate) ?? endDate
        let stats = try await fetchDailyStats(from: startDate, to: endDate)
        return stats.last
    }

    public func fetchDeckNames() async throws -> [String] {
        // Deck names aren't cached - they're configuration
        try await remote.fetchDeckNames()
    }

    public func testConnection() async throws -> Bool {
        try await remote.testConnection()
    }

    // MARK: - Cache-Only Methods (for instant display)

    public func fetchCachedDailyStats(from startDate: Date, to endDate: Date) async throws -> [AnkiDailyStats] {
        try await fetchCached(AnkiDailyStats.self, from: startDate, to: endDate)
    }

    public func hasCachedData() async throws -> Bool {
        try await hasCached(AnkiDailyStats.self)
    }
}
