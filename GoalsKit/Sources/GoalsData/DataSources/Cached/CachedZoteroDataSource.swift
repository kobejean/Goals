import Foundation
import GoalsDomain

/// Cached wrapper around ZoteroDataSource
/// Uses VersionBasedStrategy for incremental sync (annotations can be edited)
///
/// Zotero data is mutable - annotations can be edited after creation.
/// The Zotero API supports version-based incremental sync, so we use that.
public actor CachedZoteroDataSource: ZoteroDataSourceProtocol, CachingDataSourceWrapper {
    public let remote: ZoteroDataSource
    public let cache: DataCache

    /// Strategy for incremental fetching.
    /// Zotero annotations are mutable and the API supports version-based sync.
    public let incrementalStrategy = VersionBasedStrategy(
        strategyKey: "zotero.dailyStats"
    )

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
        // Get current cached data
        let cachedStats = try await fetchCached(ZoteroDailyStats.self, from: startDate, to: endDate)

        // Get version for incremental fetch
        let metadata = try? await cache.fetchStrategyMetadata(for: incrementalStrategy)
        let sinceVersion = incrementalStrategy.versionForIncrementalFetch(metadata: metadata)

        do {
            // Use version-based incremental sync
            // - If we have sinceVersion, only fetch items modified since then
            // - If not, do a full fetch (first time or after cache clear)
            let (remoteStats, newLibraryVersion) = try await remote.fetchDailyStatsWithVersion(
                from: startDate,
                to: endDate,
                sinceVersion: sinceVersion
            )

            if !remoteStats.isEmpty {
                // Merge new stats with existing cached data
                // For incremental sync, we need to combine counts for the same day
                let mergedStats = mergeStats(existing: cachedStats, new: remoteStats)
                try await cache.store(mergedStats)
            }

            // Update library version on success
            if newLibraryVersion > 0 {
                let updatedMetadata = incrementalStrategy.updateMetadata(
                    previous: metadata,
                    fetchedRange: (startDate, endDate),
                    fetchedAt: Date(),
                    newVersion: newLibraryVersion
                )
                try await cache.storeStrategyMetadata(updatedMetadata, for: incrementalStrategy)
            }
        } catch {
            // Don't fail if we already have cached data - use what we have
            // This is graceful degradation for when Zotero API isn't available
            if cachedStats.isEmpty {
                throw error
            }
        }

        // Single source of truth: always return from cache
        return try await fetchCached(ZoteroDailyStats.self, from: startDate, to: endDate)
    }

    /// Merges new stats with existing cached stats.
    /// For incremental sync, new stats may include modified items that were already counted.
    /// To avoid double-counting: only add stats for dates that didn't exist before,
    /// and for today's date (which is volatile and may have genuinely new items).
    private func mergeStats(existing: [ZoteroDailyStats], new: [ZoteroDailyStats]) -> [ZoteroDailyStats] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var statsByDay: [Date: ZoteroDailyStats] = [:]

        // First, add all existing stats
        for stat in existing {
            let day = calendar.startOfDay(for: stat.date)
            statsByDay[day] = stat
        }

        // Then merge in new stats
        for stat in new {
            let day = calendar.startOfDay(for: stat.date)
            if let existingStat = statsByDay[day] {
                // For today's date, add to existing counts (genuinely new items likely)
                // For past dates, the incremental data might include modified items
                // we already counted, so only add if it's today
                if day == today {
                    statsByDay[day] = ZoteroDailyStats(
                        date: existingStat.date,
                        annotationCount: existingStat.annotationCount + stat.annotationCount,
                        noteCount: existingStat.noteCount + stat.noteCount
                    )
                }
                // For past dates, skip - they're likely modified items we already counted
            } else {
                // New date we haven't seen before - add it
                statsByDay[day] = stat
            }
        }

        return statsByDay.values.sorted { $0.date < $1.date }
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
