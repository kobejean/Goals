import Foundation
import GoalsDomain

/// Cached wrapper around AtCoderDataSource
/// Checks cache first, then fetches only missing data from remote
public actor CachedAtCoderDataSource: AtCoderDataSourceProtocol {
    public let dataSourceType: DataSourceType = .atCoder

    public nonisolated var availableMetrics: [MetricInfo] {
        remote.availableMetrics
    }

    public nonisolated func metricValue(for key: String, from stats: Any) -> Double? {
        remote.metricValue(for: key, from: stats)
    }

    private let remote: AtCoderDataSource
    private let cache: DataCache

    public init(remote: AtCoderDataSource, cache: DataCache) {
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
        guard let stats = try await fetchStats() else { return nil }
        return metricValue(for: metricKey, from: stats)
    }

    // MARK: - AtCoderDataSourceProtocol

    public func fetchStats() async throws -> AtCoderStats? {
        // Always fetch fresh stats from remote (current snapshot)
        // Don't cache - this is a point-in-time snapshot, not historical data
        try await remote.fetchStats()
    }

    public func fetchContestHistory() async throws -> [AtCoderStats] {
        // Fetch from remote and store in cache
        let freshHistory = try await remote.fetchContestHistory()
        try await cache.store(freshHistory)

        // Single source of truth: always return from cache
        // Cache handles deduplication via cacheKey during store
        return try await cache.fetch(AtCoderStats.self).filter { $0.isContestResult }
    }

    public func fetchSubmissions(from fromDate: Date?) async throws -> [AtCoderSubmission] {
        let startDate = fromDate ?? Calendar.current.date(byAdding: .year, value: -1, to: Date())!

        // Check if historical backfill is needed
        let earliestCached = try await cache.earliestRecordDate(for: AtCoderSubmission.self)
        let backfillCutoff = DateComponents(calendar: .current, year: 2022, month: 1, day: 1).date!

        if earliestCached == nil || earliestCached! > backfillCutoff {
            // Perform historical backfill (silent, no progress UI)
            try await performHistoricalBackfill(to: earliestCached ?? Date())
        }

        // Determine if we need to fetch more data
        // If we have cached data, only fetch from the latest cached submission onwards
        let fetchFromDate: Date
        if let latestCachedDate = try await cache.latestRecordDate(for: AtCoderSubmission.self),
           latestCachedDate >= startDate {
            // Fetch from day after latest cached submission
            fetchFromDate = Calendar.current.date(byAdding: .second, value: 1, to: latestCachedDate) ?? latestCachedDate
        } else {
            // No relevant cache, fetch from the requested start date
            fetchFromDate = startDate
        }

        // Only fetch if the fetch date is before now
        if fetchFromDate < Date() {
            let newSubmissions = try await remote.fetchSubmissions(from: fetchFromDate)

            // Store in cache
            if !newSubmissions.isEmpty {
                try await cache.store(newSubmissions)
            }
        }

        // Single source of truth: always return from cache
        // Cache handles deduplication via cacheKey during store
        return try await cache.fetch(AtCoderSubmission.self, from: startDate)
            .sorted { $0.date < $1.date }
    }

    public func fetchDailyEffort(from fromDate: Date?) async throws -> [AtCoderDailyEffort] {
        let startDate = fromDate ?? Calendar.current.date(byAdding: .year, value: -1, to: Date())!

        // Check if we have recent cached data
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let latestCachedDate = try await cache.latestRecordDate(for: AtCoderDailyEffort.self)
        let hasCachedData = try await cache.hasCachedData(for: AtCoderDailyEffort.self)

        // Determine what data to fetch based on cache state
        if let latestDate = latestCachedDate, hasCachedData {
            let daysSinceLatest = calendar.dateComponents([.day], from: latestDate, to: today).day ?? 0
            if daysSinceLatest <= 1 {
                // Cache is current - only fetch recent days to check for updates
                let recentStart = calendar.date(byAdding: .day, value: -7, to: today) ?? today
                let recentSubmissions = try await remote.fetchSubmissions(from: recentStart)

                // Update cache with recent submissions
                if !recentSubmissions.isEmpty {
                    try await cache.store(recentSubmissions)
                    // Recalculate daily effort for affected days and store
                    let updatedEffort = try await computeDailyEffort(from: startDate)
                    try await cache.store(updatedEffort)
                }
            } else {
                // Cache is stale - fetch fresh data
                let effort = try await remote.fetchDailyEffort(from: startDate)
                try await cache.store(effort)
            }
        } else {
            // No cache - fetch fresh data
            let effort = try await remote.fetchDailyEffort(from: startDate)
            try await cache.store(effort)
        }

        // Single source of truth: always return from cache
        // Cache handles deduplication via cacheKey during store
        return try await cache.fetch(AtCoderDailyEffort.self, from: startDate)
    }

    // MARK: - Cache-Only Methods (for instant display)

    /// Returns cached contest history without fetching from remote
    public func fetchCachedContestHistory() async throws -> [AtCoderStats] {
        // Filter to only include actual contest results (with contestScreenName)
        try await cache.fetch(AtCoderStats.self).filter { $0.isContestResult }
    }

    /// Returns cached daily effort without fetching from remote
    public func fetchCachedDailyEffort(from startDate: Date) async throws -> [AtCoderDailyEffort] {
        try await cache.fetch(AtCoderDailyEffort.self, from: startDate)
    }

    /// Returns cached submissions without fetching from remote
    public func fetchCachedSubmissions(from startDate: Date) async throws -> [AtCoderSubmission] {
        try await cache.fetch(AtCoderSubmission.self, from: startDate)
    }

    /// Returns true if there's any cached contest history
    public func hasCachedContestHistory() async throws -> Bool {
        try await cache.hasCachedData(for: AtCoderStats.self)
    }

    /// Returns true if there's any cached daily effort
    public func hasCachedDailyEffort() async throws -> Bool {
        try await cache.hasCachedData(for: AtCoderDailyEffort.self)
    }

    // MARK: - Private Helpers

    /// Computes daily effort from cached submissions
    private func computeDailyEffort(from startDate: Date) async throws -> [AtCoderDailyEffort] {
        let submissions = try await cache.fetch(AtCoderSubmission.self, from: startDate)

        // We need problem difficulties - this would require another cache or API call
        // For now, delegate to remote which has this logic
        return try await remote.fetchDailyEffort(from: startDate)
    }

    /// Performs one-time historical backfill from 2022 to earliest cached date
    /// Runs silently in the background with 1.5s rate limiting
    /// - Parameter endDate: The date to backfill up to (usually earliest cached submission or now)
    private func performHistoricalBackfill(to endDate: Date) async throws {
        let backfillStart = DateComponents(calendar: .current, year: 2022, month: 1, day: 1).date!

        let submissions = try await remote.fetchSubmissionsWithRateLimit(
            fromSecond: Int(backfillStart.timeIntervalSince1970),
            toSecond: Int(endDate.timeIntervalSince1970),
            sleepDuration: .milliseconds(1500)
        )

        // Store all fetched submissions
        if !submissions.isEmpty {
            try await cache.store(submissions)
        }
    }
}
