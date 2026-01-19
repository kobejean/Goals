import Foundation
import GoalsDomain

/// Cached wrapper around AtCoderDataSource
/// Uses count-based cache validation (inspired by AtCoderProblems)
public actor CachedAtCoderDataSource: AtCoderDataSourceProtocol, CachingDataSourceWrapper {
    public let remote: AtCoderDataSource
    public let cache: DataCache

    /// Time interval to always re-fetch (in seconds) - 2 days
    /// Recent submissions within this window are always fetched fresh
    /// Older data is validated by comparing local vs server counts
    private static let alwaysFetchInterval = 3600 * 24 * 2

    public init(remote: AtCoderDataSource, cache: DataCache) {
        self.remote = remote
        self.cache = cache
    }

    // MARK: - Configuration passthrough provided by CachingDataSourceWrapper

    public func fetchLatestMetricValue(for metricKey: String) async throws -> Double? {
        guard let stats = try await fetchStats() else { return nil }
        return metricValue(for: metricKey, from: stats)
    }

    // MARK: - AtCoderDataSourceProtocol

    public func fetchStats() async throws -> AtCoderCurrentStats? {
        // Always fetch fresh stats from remote (current snapshot)
        // Don't cache - this is a point-in-time snapshot, not historical data
        try await remote.fetchStats()
    }

    public func fetchContestHistory() async throws -> [AtCoderContestResult] {
        // Fetch from remote and store in cache
        let freshHistory = try await remote.fetchContestHistory()
        try await cache.store(freshHistory)

        // Single source of truth: always return from cache
        return try await fetchCached(AtCoderContestResult.self)
    }

    public func fetchSubmissions(from fromDate: Date?) async throws -> [AtCoderSubmission] {
        // Load cached submissions (all of them for validation)
        let cachedSubmissions = try await fetchCached(AtCoderSubmission.self)

        // Sort by epoch second to find latest
        let sortedCache = cachedSubmissions.sorted { $0.epochSecond < $1.epochSecond }

        let fetchFromSecond: Int

        if let latestSubmission = sortedCache.last {
            // Calculate validation boundary (latest - 2 days)
            // We always re-fetch submissions within this window to catch any updates
            let validationBoundary = latestSubmission.epochSecond - Self.alwaysFetchInterval

            // Count local submissions before the boundary
            let localCount = sortedCache.filter { $0.epochSecond < validationBoundary }.count

            // Get server count before the boundary to validate cache integrity
            let serverCount = try await remote.fetchSubmissionCount(
                fromSecond: 0,
                toSecond: validationBoundary
            )

            // Validate cache by comparing counts
            let isCacheValid = localCount == serverCount

            if isCacheValid {
                // Cache is valid - only fetch from the validation boundary
                fetchFromSecond = validationBoundary
            } else {
                // Cache is invalid (count mismatch) - fetch everything from beginning
                fetchFromSecond = 0
            }
        } else {
            // No cached data - fetch from the beginning
            fetchFromSecond = 0
        }

        // Fetch new submissions
        let newSubmissions = try await remote.fetchSubmissions(fromSecond: fetchFromSecond)

        // Store in cache
        if !newSubmissions.isEmpty {
            try await cache.store(newSubmissions)
        }

        // Single source of truth: always return from cache
        // If fromDate is nil, return all submissions; otherwise filter by date
        return try await fetchCached(AtCoderSubmission.self, from: fromDate)
            .sorted { $0.date < $1.date }
    }

    public func fetchDailyEffort(from fromDate: Date?) async throws -> [AtCoderDailyEffort] {
        // Use our cached fetchSubmissions which has count-based validation
        // This ensures we have all historical submissions before computing daily effort
        let submissions = try await fetchSubmissions(from: fromDate)

        // Fetch problem difficulties for effort calculation
        let difficulties = try await remote.fetchProblemDifficulties()

        // Group submissions by day and compute effort
        let calendar = Calendar.current
        var dailyData: [Date: [AtCoderRankColor: Int]] = [:]

        for submission in submissions {
            let dayStart = calendar.startOfDay(for: submission.date)
            let difficulty = difficulties[submission.problemId]
            let color = AtCoderRankColor.from(difficulty: difficulty)

            if dailyData[dayStart] == nil {
                dailyData[dayStart] = [:]
            }
            dailyData[dayStart]![color, default: 0] += 1
        }

        // Convert to array and sort by date
        let effort = dailyData.map { date, submissions in
            AtCoderDailyEffort(date: date, submissionsByDifficulty: submissions)
        }.sorted { $0.date < $1.date }

        // Store computed effort in cache
        try await cache.store(effort)

        return effort
    }

    // MARK: - Cache-Only Methods (for instant display)

    public func fetchCachedContestHistory() async throws -> [AtCoderContestResult] {
        try await fetchCached(AtCoderContestResult.self)
    }

    public func fetchCachedDailyEffort(from startDate: Date?) async throws -> [AtCoderDailyEffort] {
        try await fetchCached(AtCoderDailyEffort.self, from: startDate)
    }

    public func fetchCachedSubmissions(from startDate: Date) async throws -> [AtCoderSubmission] {
        try await fetchCached(AtCoderSubmission.self, from: startDate)
    }

    public func hasCachedContestHistory() async throws -> Bool {
        try await hasCached(AtCoderContestResult.self)
    }

    public func hasCachedDailyEffort() async throws -> Bool {
        try await hasCached(AtCoderDailyEffort.self)
    }
}
