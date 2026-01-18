import Foundation
import GoalsDomain

/// Cached wrapper around TypeQuickerDataSource
/// Checks cache first, then fetches only missing data from remote
public actor CachedTypeQuickerDataSource: TypeQuickerDataSourceProtocol {
    public let dataSourceType: DataSourceType = .typeQuicker

    public nonisolated var availableMetrics: [MetricInfo] {
        remote.availableMetrics
    }

    public nonisolated func metricValue(for key: String, from stats: Any) -> Double? {
        remote.metricValue(for: key, from: stats)
    }

    private let remote: TypeQuickerDataSource
    private let cache: DataCache

    public init(remote: TypeQuickerDataSource, cache: DataCache) {
        self.remote = remote
        self.cache = cache
    }

    // MARK: - DataSourceRepositoryProtocol

    public func isConfigured() async -> Bool {
        await remote.isConfigured()
    }

    public func configure(settings: DataSourceSettings) async throws {
        try await remote.configure(settings: settings)
    }

    public func clearConfiguration() async throws {
        try await remote.clearConfiguration()
    }

    public func fetchLatestMetricValue(for metricKey: String) async throws -> Double? {
        guard let stats = try await fetchLatestStats() else { return nil }
        return metricValue(for: metricKey, from: stats)
    }

    // MARK: - TypeQuickerDataSourceProtocol

    public func fetchStats(from startDate: Date, to endDate: Date) async throws -> [TypeQuickerStats] {
        let calendar = Calendar.current

        // Get cached data to determine what's missing
        let cachedStats = try await cache.fetch(
            TypeQuickerStats.self,
            from: startDate,
            to: endDate
        )
        let cachedDates = Set(cachedStats.map { calendar.startOfDay(for: $0.date) })

        // Determine which dates need to be fetched
        var missingRanges: [(start: Date, end: Date)] = []
        var currentStart: Date? = nil

        var checkDate = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        while checkDate <= endDay {
            if !cachedDates.contains(checkDate) {
                if currentStart == nil {
                    currentStart = checkDate
                }
            } else {
                if let start = currentStart {
                    let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                    missingRanges.append((start, previousDay))
                    currentStart = nil
                }
            }
            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
        }

        if let start = currentStart {
            missingRanges.append((start, endDay))
        }

        // Fetch missing data from remote and store in cache
        for range in missingRanges {
            let remoteStats = try await remote.fetchStats(from: range.start, to: range.end)
            if !remoteStats.isEmpty {
                try await cache.store(remoteStats)
            }
        }

        // Single source of truth: always return from cache
        // Cache handles deduplication via cacheKey during store
        return try await cache.fetch(TypeQuickerStats.self, from: startDate, to: endDate)
    }

    public func fetchLatestStats() async throws -> TypeQuickerStats? {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        let stats = try await fetchStats(from: startDate, to: endDate)
        return stats.last
    }

    // MARK: - Cache-Only Methods (for instant display)

    /// Returns cached stats without fetching from remote
    /// Use this for instant display while updating in background
    public func fetchCachedStats(from startDate: Date, to endDate: Date) async throws -> [TypeQuickerStats] {
        try await cache.fetch(TypeQuickerStats.self, from: startDate, to: endDate)
    }

    /// Returns true if there's any cached data available
    public func hasCachedData() async throws -> Bool {
        try await cache.hasCachedData(for: TypeQuickerStats.self)
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
