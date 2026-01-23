import Foundation
import GoalsDomain

/// Cached wrapper around TypeQuickerDataSource
/// Checks cache first, then fetches only missing data from remote
public actor CachedTypeQuickerDataSource: TypeQuickerDataSourceProtocol, CachingDataSourceWrapper {
    public let remote: TypeQuickerDataSource
    public let cache: DataCache

    /// Tracks the last date we successfully fetched from remote.
    /// Used to avoid re-fetching old data that won't change.
    private var lastSuccessfulFetchDate: Date? {
        didSet { saveLastSuccessfulFetchDate() }
    }
    private static let lastFetchKey = "typeQuickerLastSuccessfulFetchDate"

    public init(remote: TypeQuickerDataSource, cache: DataCache) {
        self.remote = remote
        self.cache = cache
        self.lastSuccessfulFetchDate = Self.loadLastSuccessfulFetchDate()
    }

    private static func loadLastSuccessfulFetchDate() -> Date? {
        UserDefaults.standard.object(forKey: lastFetchKey) as? Date
    }

    private func saveLastSuccessfulFetchDate() {
        UserDefaults.standard.set(lastSuccessfulFetchDate, forKey: Self.lastFetchKey)
    }

    // MARK: - Configuration passthrough provided by CachingDataSourceWrapper

    public func fetchLatestMetricValue(for metricKey: String, taskId: UUID?) async throws -> Double? {
        guard let stats = try await fetchLatestStats() else { return nil }
        return metricValue(for: metricKey, from: stats)
    }

    // MARK: - TypeQuickerDataSourceProtocol

    public func fetchStats(from startDate: Date, to endDate: Date) async throws -> [TypeQuickerStats] {
        let calendar = Calendar.current

        // Only fetch from 1 day before last successful fetch (old data is stable).
        // Missing days in the past are just days with no practice - no need to re-fetch.
        let remoteFetchStart: Date
        if let lastFetch = lastSuccessfulFetchDate {
            let volatileStart = calendar.date(byAdding: .day, value: -1, to: lastFetch) ?? lastFetch
            remoteFetchStart = max(calendar.startOfDay(for: volatileStart), calendar.startOfDay(for: startDate))
        } else {
            remoteFetchStart = calendar.startOfDay(for: startDate)
        }

        do {
            let remoteStats = try await remote.fetchStats(from: remoteFetchStart, to: endDate)
            if !remoteStats.isEmpty {
                try await cache.store(remoteStats)
            }
            lastSuccessfulFetchDate = calendar.startOfDay(for: endDate)
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
