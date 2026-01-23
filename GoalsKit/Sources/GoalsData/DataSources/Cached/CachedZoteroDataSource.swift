import Foundation
import GoalsDomain

/// Cached wrapper around ZoteroDataSource
/// Returns cached data when Zotero API isn't available, fetches fresh data when possible
public actor CachedZoteroDataSource: ZoteroDataSourceProtocol, CachingDataSourceWrapper {
    public let remote: ZoteroDataSource
    public let cache: DataCache

    public init(remote: ZoteroDataSource, cache: DataCache) {
        self.remote = remote
        self.cache = cache
    }

    // MARK: - Configuration passthrough provided by CachingDataSourceWrapper

    public func fetchLatestMetricValue(for metricKey: String, taskId: UUID?) async throws -> Double? {
        try await remote.fetchLatestMetricValue(for: metricKey, taskId: taskId)
    }

    // MARK: - ZoteroDataSourceProtocol

    public func fetchDailyStats(from startDate: Date, to endDate: Date) async throws -> [ZoteroDailyStats] {
        // Get cached data to determine what's missing
        let cachedStats = try await fetchCached(ZoteroDailyStats.self, from: startDate, to: endDate)
        let cachedDates = Set(cachedStats.map { Calendar.current.startOfDay(for: $0.date) })

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
                // This is graceful degradation for when Zotero API isn't available
                if !cachedStats.isEmpty {
                    break
                }
                // Only throw if we have no cached data at all
                throw error
            }
        }

        // Single source of truth: always return from cache
        return try await fetchCached(ZoteroDailyStats.self, from: startDate, to: endDate)
    }

    public func fetchReadingStatus() async throws -> ZoteroReadingStatus? {
        // Reading status is a point-in-time snapshot, so always try to fetch fresh
        // But cache it for widget access
        do {
            if let status = try await remote.fetchReadingStatus() {
                try await cache.store([status])
                return status
            }
            // Fall back to cached if remote returns nil (not configured)
            return try await fetchCachedReadingStatus()
        } catch {
            // Fall back to cached reading status on error
            return try await fetchCachedReadingStatus()
        }
    }

    public func testConnection() async throws -> Bool {
        try await remote.testConnection()
    }

    // MARK: - Cache-Only Methods (for instant display)

    public func fetchCachedDailyStats(from startDate: Date, to endDate: Date) async throws -> [ZoteroDailyStats] {
        try await fetchCached(ZoteroDailyStats.self, from: startDate, to: endDate)
    }

    public func fetchCachedReadingStatus() async throws -> ZoteroReadingStatus? {
        // Get the most recent reading status from cache
        let cachedStatuses = try await fetchCached(ZoteroReadingStatus.self)
        return cachedStatuses.max { $0.date < $1.date }
    }

    public func hasCachedData() async throws -> Bool {
        try await hasCached(ZoteroDailyStats.self)
    }
}
