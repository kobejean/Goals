import Foundation
import GoalsDomain

/// Cached wrapper around AnkiDataSource
/// Uses DateBasedStrategy for incremental fetching (past review stats don't change)
public actor CachedAnkiDataSource: AnkiDataSourceProtocol, CachingDataSourceWrapper {
    public let remote: AnkiDataSource
    public let cache: DataCache

    /// Strategy for incremental fetching.
    /// Anki review stats are immutable once recorded, so we only need to fetch recent data.
    public let incrementalStrategy = DateBasedStrategy(
        strategyKey: "anki.dailyStats",
        volatileWindowDays: 1
    )

    /// Old UserDefaults key for migration
    private static let legacyLastFetchKey = "ankiLastSuccessfulFetchDate"

    public init(remote: AnkiDataSource, cache: DataCache) {
        self.remote = remote
        self.cache = cache
    }

    /// Migrate old UserDefaults-based lastFetchDate to new strategy metadata
    private func migrateFromLegacyMetadataIfNeeded() async {
        // Check if new metadata already exists
        if let _ = try? await cache.fetchStrategyMetadata(for: incrementalStrategy) {
            return // Already migrated
        }

        // Check for legacy metadata
        if let legacyDate = UserDefaults.standard.object(forKey: Self.legacyLastFetchKey) as? Date {
            let metadata = DateBasedStrategy.Metadata(lastFetchDate: legacyDate)
            try? await cache.storeStrategyMetadata(metadata, for: incrementalStrategy)
            // Remove legacy key after migration
            UserDefaults.standard.removeObject(forKey: Self.legacyLastFetchKey)
        }
    }

    // MARK: - Configuration passthrough provided by CachingDataSourceWrapper

    public func fetchLatestMetricValue(for metricKey: String, taskId: UUID?) async throws -> Double? {
        guard let stats = try await fetchLatestStats() else { return nil }
        return metricValue(for: metricKey, from: stats)
    }

    // MARK: - AnkiDataSourceProtocol

    public func fetchDailyStats(from startDate: Date, to endDate: Date) async throws -> [AnkiDailyStats] {
        // Migrate legacy metadata if needed (one-time operation)
        await migrateFromLegacyMetadataIfNeeded()

        // Calculate what we need to fetch based on strategy
        let fetchRange = try await calculateIncrementalFetchRange(for: (startDate, endDate))

        do {
            let remoteStats = try await remote.fetchDailyStats(from: fetchRange.start, to: fetchRange.end)
            if !remoteStats.isEmpty {
                try await cache.store(remoteStats)
            }
            try await recordSuccessfulFetch(range: (fetchRange.start, fetchRange.end))
        } catch {
            // Don't fail if we have cached data - use what we have
            let cachedStats = try await fetchCached(AnkiDailyStats.self, from: startDate, to: endDate)
            if cachedStats.isEmpty {
                throw error
            }
        }

        // Return all cached data for the requested range
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
