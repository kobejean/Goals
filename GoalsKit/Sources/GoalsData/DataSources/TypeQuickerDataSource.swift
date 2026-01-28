import Foundation
import GoalsDomain

/// Data source implementation for TypeQuicker typing statistics.
/// Supports optional caching via DataCache - uses DateBasedStrategy since typing stats are immutable.
public actor TypeQuickerDataSource: TypeQuickerDataSourceProtocol, CacheableDataSource {
    public let dataSourceType: DataSourceType = .typeQuicker

    public nonisolated var availableMetrics: [MetricInfo] {
        [
            MetricInfo(key: "wpm", name: "Average WPM", unit: "WPM", icon: "speedometer"),
            MetricInfo(key: "accuracy", name: "Average Accuracy", unit: "%", icon: "target"),
            MetricInfo(key: "practiceTime", name: "Practice Time", unit: "min", icon: "clock"),
        ]
    }

    public nonisolated func metricValue(for key: String, from stats: Any) -> Double? {
        guard let stat = stats as? TypeQuickerStats else { return nil }
        switch key {
        case "wpm": return stat.wordsPerMinute
        case "accuracy": return stat.accuracy
        case "practiceTime": return Double(stat.practiceTimeMinutes)
        default: return nil
        }
    }

    // MARK: - CacheableDataSource

    public let cache: DataCache?

    /// Strategy for incremental fetching.
    /// TypeQuicker stats are immutable once recorded, so we only need to fetch recent data.
    private let strategy = DateBasedStrategy(strategyKey: "typeQuicker.stats", volatileWindowDays: 1)

    // MARK: - Configuration

    private var username: String?
    private var baseURL: URL?
    private let httpClient: HTTPClient

    /// Creates a TypeQuickerDataSource without caching (for testing).
    public init(httpClient: HTTPClient = HTTPClient()) {
        self.cache = nil
        self.httpClient = httpClient
    }

    /// Creates a TypeQuickerDataSource with caching enabled (for production).
    public init(cache: DataCache, httpClient: HTTPClient = HTTPClient()) {
        self.cache = cache
        self.httpClient = httpClient
    }

    public func isConfigured() async -> Bool {
        username != nil
    }

    public func configure(settings: DataSourceSettings) async throws {
        guard settings.dataSourceType == .typeQuicker else {
            throw DataSourceError.invalidConfiguration
        }

        guard let username = settings.credentials["username"], !username.isEmpty else {
            throw DataSourceError.missingCredentials
        }

        self.username = username
        self.baseURL = URL(string: settings.options["baseURL"] ?? "https://api.typequicker.com")
    }

    public func clearConfiguration() async throws {
        username = nil
        baseURL = nil
    }

    public func fetchLatestMetricValue(for metricKey: String, taskId: UUID?) async throws -> Double? {
        guard let stats = try await fetchLatestStats() else { return nil }
        return metricValue(for: metricKey, from: stats)
    }

    public func fetchStats(from startDate: Date, to endDate: Date) async throws -> [TypeQuickerStats] {
        // Use cached fetch if caching is enabled
        try await cachedFetch(
            strategy: strategy,
            fetcher: fetchStatsFromRemote,
            from: startDate,
            to: endDate
        )
    }

    /// Internal method that fetches stats directly from TypeQuicker API.
    private func fetchStatsFromRemote(from startDate: Date, to endDate: Date) async throws -> [TypeQuickerStats] {
        let url = try buildStatsURL(from: startDate, to: endDate)
        let apiResponse: TypeQuickerAPIResponse = try await httpClient.get(url)
        return apiResponse.toStats()
    }

    // MARK: - Private Helpers

    private func buildStatsURL(from startDate: Date, to endDate: Date) throws -> URL {
        guard let username = username else {
            throw DataSourceError.notConfigured
        }

        let base = baseURL ?? URL(string: "https://api.typequicker.com")!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var components = URLComponents(url: base.appendingPathComponent("stats/\(username)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: dateFormatter.string(from: startDate)),
            URLQueryItem(name: "end_date", value: dateFormatter.string(from: endDate))
        ]

        guard let url = components.url else {
            throw DataSourceError.invalidURL
        }

        return url
    }

    public func fetchLatestStats() async throws -> TypeQuickerStats? {
        let endDate = Date()
        // Use 90 days lookback to find recent stats (user may not type every day)
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate) ?? endDate
        let stats = try await fetchStats(from: startDate, to: endDate)
        return stats.last
    }

    /// Fetch stats aggregated by mode across all dates in the range
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

    // MARK: - Cache-Only Methods (for instant display)

    public func fetchCachedStats(from startDate: Date, to endDate: Date) async throws -> [TypeQuickerStats] {
        try await fetchCached(TypeQuickerStats.self, from: startDate, to: endDate)
    }

    public func hasCachedData() async throws -> Bool {
        try await hasCached(TypeQuickerStats.self)
    }
}

// MARK: - API Response Models

/// API response structure from TypeQuicker
/// Format: { "activity": { "2026-01-11": [{ "wpm": 45, ... }], ... } }
/// Note: API may return {} or {"activity": null} for empty date ranges
private struct TypeQuickerAPIResponse: Codable {
    let activity: [String: [Session]]?

    // Handle empty responses gracefully
    var safeActivity: [String: [Session]] {
        activity ?? [:]
    }

    struct Session: Codable {
        let wpm: Double
        let cpm: Double
        let accuracy: Double
        let trueAccuracy: Double
        let timeTyping: Int // milliseconds
        let charactersTyped: Int
        let primaryMode: String
        let secondaryMode: String
        let keyboardLayout: String
    }

    func toStats() -> [TypeQuickerStats] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return safeActivity.compactMap { (dateString, sessions) -> TypeQuickerStats? in
            guard let date = dateFormatter.date(from: dateString), !sessions.isEmpty else {
                return nil
            }

            // Aggregate all sessions for the day
            let totalTimeMs = sessions.reduce(0) { $0 + $1.timeTyping }

            // Weighted average WPM based on time spent
            let weightedWpm = sessions.reduce(0.0) { acc, session in
                let weight = Double(session.timeTyping) / Double(max(totalTimeMs, 1))
                return acc + (session.wpm * weight)
            }

            // Weighted average accuracy
            let weightedAccuracy = sessions.reduce(0.0) { acc, session in
                let weight = Double(session.timeTyping) / Double(max(totalTimeMs, 1))
                return acc + (session.trueAccuracy * weight)
            }

            // Group by mode for this day
            let modeStats = aggregateByMode(sessions: sessions)

            return TypeQuickerStats(
                date: date,
                wordsPerMinute: weightedWpm,
                accuracy: weightedAccuracy,
                practiceTimeMinutes: totalTimeMs / 60000, // ms to minutes
                sessionsCount: sessions.count,
                byMode: modeStats.isEmpty ? nil : modeStats
            )
        }.sorted { $0.date < $1.date }
    }

    /// Aggregate all sessions by mode across all dates
    func toStatsByMode() -> [TypeQuickerModeStats] {
        let allSessions = safeActivity.values.flatMap { $0 }
        return aggregateByMode(sessions: allSessions)
    }

    /// Helper to aggregate sessions by primaryMode
    private func aggregateByMode(sessions: [Session]) -> [TypeQuickerModeStats] {
        let grouped = Dictionary(grouping: sessions) { $0.primaryMode }

        return grouped.compactMap { (mode, modeSessions) -> TypeQuickerModeStats? in
            guard !modeSessions.isEmpty else { return nil }

            let totalTimeMs = modeSessions.reduce(0) { $0 + $1.timeTyping }

            // Weighted average WPM
            let weightedWpm = modeSessions.reduce(0.0) { acc, session in
                let weight = Double(session.timeTyping) / Double(max(totalTimeMs, 1))
                return acc + (session.wpm * weight)
            }

            // Weighted average accuracy
            let weightedAccuracy = modeSessions.reduce(0.0) { acc, session in
                let weight = Double(session.timeTyping) / Double(max(totalTimeMs, 1))
                return acc + (session.trueAccuracy * weight)
            }

            return TypeQuickerModeStats(
                mode: mode,
                wordsPerMinute: weightedWpm,
                accuracy: weightedAccuracy,
                practiceTimeMinutes: totalTimeMs / 60000,
                sessionsCount: modeSessions.count
            )
        }.sorted { $0.practiceTimeMinutes > $1.practiceTimeMinutes } // Sort by most practiced
    }
}
