import Foundation
import GoalsDomain

/// Cached wrapper around TypeQuickerDataSource
/// Uses DateBasedStrategy for incremental fetching (past typing stats don't change)
public actor CachedTypeQuickerDataSource: TypeQuickerDataSourceProtocol, CachingDataSourceWrapper {
    public let remote: TypeQuickerDataSource
    public let cache: DataCache

    /// Strategy for incremental fetching.
    /// TypeQuicker stats are immutable once recorded, so we only need to fetch recent data.
    public let incrementalStrategy = DateBasedStrategy(
        strategyKey: "typeQuicker.stats",
        volatileWindowDays: 1
    )

    /// Old UserDefaults key for migration
    private static let legacyLastFetchKey = "typeQuickerLastSuccessfulFetchDate"

    public init(remote: TypeQuickerDataSource, cache: DataCache) {
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

    // MARK: - TypeQuickerDataSourceProtocol

    public func fetchStats(from startDate: Date, to endDate: Date) async throws -> [TypeQuickerStats] {
        // Migrate legacy metadata if needed (one-time operation)
        await migrateFromLegacyMetadataIfNeeded()

        // Calculate what we need to fetch based on strategy
        let fetchRange = try await calculateIncrementalFetchRange(for: (startDate, endDate))

        do {
            let remoteStats = try await remote.fetchStats(from: fetchRange.start, to: fetchRange.end)
            if !remoteStats.isEmpty {
                try await cache.store(remoteStats)
            }
            try await recordSuccessfulFetch(range: (fetchRange.start, fetchRange.end))
        } catch {
            // Don't fail if we have cached data - use what we have
            let cachedStats = try await fetchCached(TypeQuickerStats.self, from: startDate, to: endDate)
            if cachedStats.isEmpty {
                throw error
            }
        }

        return try await fetchCached(TypeQuickerStats.self, from: startDate, to: endDate)
    }

    public func fetchLatestStats() async throws -> TypeQuickerStats? {
        let endDate = Date()
        // Use 90 days lookback to find recent stats (user may not type every day)
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate) ?? endDate
        let stats = try await fetchStats(from: startDate, to: endDate)
        return stats.last
    }

    // MARK: - Cache-Only Methods (for instant display)

    public func fetchCachedStats(from startDate: Date, to endDate: Date) async throws -> [TypeQuickerStats] {
        try await fetchCached(TypeQuickerStats.self, from: startDate, to: endDate)
    }

    public func hasCachedData() async throws -> Bool {
        try await hasCached(TypeQuickerStats.self)
    }

    // MARK: - Mode Stats

    public func fetchStatsByMode(from startDate: Date, to endDate: Date) async throws -> [TypeQuickerModeStats] {
        // Stats by mode requires full session data, so we fetch from remote
        // and cache the individual stats
        let stats = try await fetchStats(from: startDate, to: endDate)

        // Aggregate mode stats from all days
        var modeAggregation: [String: (wpm: Double, accuracy: Double, time: Int, sessions: Int, weight: Int)] = [:]

        for dayStat in stats {
            guard let modeStats = dayStat.byMode else { continue }
            for modeStat in modeStats {
                let existing = modeAggregation[modeStat.mode] ?? (0, 0, 0, 0, 0)
                let newTime = existing.time + modeStat.practiceTimeMinutes
                let newSessions = existing.sessions + modeStat.sessionsCount

                // Weighted average calculation
                let totalWeight = existing.weight + modeStat.practiceTimeMinutes
                let weightedWpm = (existing.wpm * Double(existing.weight) + modeStat.wordsPerMinute * Double(modeStat.practiceTimeMinutes)) / Double(max(totalWeight, 1))
                let weightedAccuracy = (existing.accuracy * Double(existing.weight) + modeStat.accuracy * Double(modeStat.practiceTimeMinutes)) / Double(max(totalWeight, 1))

                modeAggregation[modeStat.mode] = (weightedWpm, weightedAccuracy, newTime, newSessions, totalWeight)
            }
        }

        return modeAggregation.map { mode, values in
            TypeQuickerModeStats(
                mode: mode,
                wordsPerMinute: values.wpm,
                accuracy: values.accuracy,
                practiceTimeMinutes: values.time,
                sessionsCount: values.sessions
            )
        }.sorted { $0.practiceTimeMinutes > $1.practiceTimeMinutes }
    }
}
