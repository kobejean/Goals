import Foundation
import GoalsDomain

/// Cached wrapper around TypeQuickerDataSource
/// Checks cache first, then fetches only missing data from remote
public actor CachedTypeQuickerDataSource: TypeQuickerDataSourceProtocol, CachingDataSourceWrapper {
    public let remote: TypeQuickerDataSource
    public let cache: DataCache

    public init(remote: TypeQuickerDataSource, cache: DataCache) {
        self.remote = remote
        self.cache = cache
    }

    // MARK: - Configuration passthrough provided by CachingDataSourceWrapper

    public func fetchLatestMetricValue(for metricKey: String) async throws -> Double? {
        guard let stats = try await fetchLatestStats() else { return nil }
        return metricValue(for: metricKey, from: stats)
    }

    // MARK: - TypeQuickerDataSourceProtocol

    public func fetchStats(from startDate: Date, to endDate: Date) async throws -> [TypeQuickerStats] {
        // Get cached data to determine what's missing
        let cachedStats = try await fetchCached(TypeQuickerStats.self, from: startDate, to: endDate)
        let cachedDates = Set(cachedStats.map { Calendar.current.startOfDay(for: $0.date) })

        // Calculate and fetch missing ranges
        let missingRanges = calculateMissingDateRanges(from: startDate, to: endDate, cachedDates: cachedDates)

        for range in missingRanges {
            do {
                let remoteStats = try await remote.fetchStats(from: range.start, to: range.end)
                if !remoteStats.isEmpty {
                    try await cache.store(remoteStats)
                }
            } catch {
                // Don't fail if we already have cached data - use what we have
                if !cachedStats.isEmpty {
                    break
                }
                // Only throw if we have no cached data at all
                throw error
            }
        }

        // Single source of truth: always return from cache
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
