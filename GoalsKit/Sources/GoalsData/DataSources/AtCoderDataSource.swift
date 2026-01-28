import Foundation
import SwiftData
import GoalsDomain

/// Data source implementation for AtCoder competitive programming statistics.
/// Uses official AtCoder API for contest history and kenkoooo's AtCoder Problems API for solve counts.
/// Supports optional caching via ModelContainer - uses custom count-based validation for submissions.
public actor AtCoderDataSource: AtCoderDataSourceProtocol, CacheableDataSource {
    public let dataSourceType: DataSourceType = .atCoder

    public nonisolated var availableMetrics: [MetricInfo] {
        [
            MetricInfo(key: "rating", name: "Rating", unit: "", icon: "star"),
            MetricInfo(key: "highestRating", name: "Highest Rating", unit: "", icon: "star.fill"),
            MetricInfo(key: "contestsParticipated", name: "Contests", unit: "", icon: "calendar"),
            MetricInfo(key: "problemsSolved", name: "Problems Solved", unit: "", icon: "checkmark.circle"),
            MetricInfo(key: "longestStreak", name: "Longest Streak", unit: "days", icon: "flame"),
        ]
    }

    public nonisolated func metricValue(for key: String, from stats: Any) -> Double? {
        // Handle both AtCoderCurrentStats and AtCoderContestResult via the shared protocol
        guard let stat = stats as? any AtCoderStatsProtocol else { return nil }
        switch key {
        case "rating": return Double(stat.rating)
        case "highestRating": return Double(stat.highestRating)
        case "contestsParticipated": return Double(stat.contestsParticipated)
        case "problemsSolved": return Double(stat.problemsSolved)
        case "longestStreak": return Double(stat.longestStreak ?? 0)
        default: return nil
        }
    }

    // MARK: - CacheableDataSource

    public let modelContainer: ModelContainer?

    /// Time interval to always re-fetch (in seconds) - 2 days
    /// Recent submissions within this window are always fetched fresh
    /// Older data is validated by comparing local vs server counts
    private static let alwaysFetchInterval = 3600 * 24 * 2

    // MARK: - Configuration

    private var username: String?
    private let httpClient: HTTPClient

    // API base URLs
    private let atCoderBaseURL = URL(string: "https://atcoder.jp")!
    private let kenkooooBaseURL = URL(string: "https://kenkoooo.com/atcoder/atcoder-api/v3")!

    /// Creates an AtCoderDataSource without caching (for testing).
    public init(httpClient: HTTPClient = HTTPClient()) {
        self.modelContainer = nil
        self.httpClient = httpClient
    }

    /// Creates an AtCoderDataSource with caching enabled (for production).
    public init(modelContainer: ModelContainer, httpClient: HTTPClient = HTTPClient()) {
        self.modelContainer = modelContainer
        self.httpClient = httpClient
    }

    public func isConfigured() async -> Bool {
        username != nil
    }

    public func configure(settings: DataSourceSettings) async throws {
        guard settings.dataSourceType == .atCoder else {
            throw DataSourceError.invalidConfiguration
        }

        guard let username = settings.credentials["username"], !username.isEmpty else {
            throw DataSourceError.missingCredentials
        }

        self.username = username
    }

    public func clearConfiguration() async throws {
        username = nil
    }

    public func fetchLatestMetricValue(for metricKey: String, taskId: UUID?) async throws -> Double? {
        guard let stats = try await fetchStats() else { return nil }
        return metricValue(for: metricKey, from: stats)
    }

    public func fetchStats() async throws -> AtCoderCurrentStats? {
        let (stats, _) = try await fetchStatsAndContestHistory()
        return stats
    }

    public func fetchContestHistory() async throws -> [AtCoderContestResult] {
        let (_, history) = try await fetchStatsAndContestHistory()
        return history
    }

    /// Fetches both stats and contest history in a single operation, avoiding redundant API calls.
    /// This is more efficient than calling fetchStats() and fetchContestHistory() separately
    /// because ranking APIs (ac_rank, streak_rank) are only called once.
    public func fetchStatsAndContestHistory() async throws -> (stats: AtCoderCurrentStats?, history: [AtCoderContestResult]) {
        guard let username = username else {
            throw DataSourceError.notConfigured
        }

        // Fetch all data concurrently - ranking APIs called only once
        async let contestHistoryTask = fetchContestHistoryFromAPI(username: username)
        async let acRankTask = fetchACRank(username: username)
        async let streakRankTask = fetchStreakRank(username: username)

        let contestHistory = try await contestHistoryTask
        let acRank = try? await acRankTask
        let streakRank = try? await streakRankTask

        let problemsSolved = acRank?.count ?? 0
        let longestStreak = streakRank?.count

        // Build contest history
        var highestSoFar = 0
        let history = contestHistory.enumerated().map { (index, result) in
            highestSoFar = max(highestSoFar, result.NewRating)
            return AtCoderContestResult(
                date: result.endTime,
                rating: result.NewRating,
                highestRating: highestSoFar,
                contestsParticipated: index + 1,
                problemsSolved: index == contestHistory.count - 1 ? problemsSolved : 0,
                longestStreak: index == contestHistory.count - 1 ? longestStreak : nil,
                contestScreenName: result.ContestScreenName
            )
        }

        // Store contest history in cache if available
        try storeInCache(history, modelType: AtCoderContestResultModel.self)

        // Build current stats
        let stats: AtCoderCurrentStats?
        if let latest = contestHistory.last {
            stats = AtCoderCurrentStats(
                date: Date(),
                rating: latest.NewRating,
                highestRating: contestHistory.map { $0.NewRating }.max() ?? 0,
                contestsParticipated: contestHistory.count,
                problemsSolved: problemsSolved,
                longestStreak: longestStreak
            )
        } else if acRank != nil {
            // User has no contest history but has solved problems
            stats = AtCoderCurrentStats(
                date: Date(),
                rating: 0,
                highestRating: 0,
                contestsParticipated: 0,
                problemsSolved: problemsSolved,
                longestStreak: longestStreak
            )
        } else {
            stats = nil
        }

        // Single source of truth for history: always return from cache if available
        let cachedHistory = try fetchCached(AtCoderContestResult.self, modelType: AtCoderContestResultModel.self)
        return (stats, cachedHistory.isEmpty ? history : cachedHistory)
    }

    // MARK: - Submission APIs

    /// Fetches user submissions (protocol-conforming method)
    /// Uses count-based cache validation to ensure complete history integrity.
    /// - Parameter fromDate: Start date (nil means all time)
    /// - Returns: Array of submissions
    public func fetchSubmissions(from fromDate: Date?) async throws -> [AtCoderSubmission] {
        guard modelContainer != nil else {
            // No caching - just fetch from remote
            let fromSecond = fromDate.map { Int($0.timeIntervalSince1970) } ?? 0
            return try await fetchSubmissionsFromRemote(fromSecond: fromSecond)
        }

        // Load cached submissions (all of them for validation)
        let cachedSubmissions = try fetchCached(AtCoderSubmission.self, modelType: AtCoderSubmissionModel.self)

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
            let serverCount = try await fetchSubmissionCount(
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
        let newSubmissions = try await fetchSubmissionsFromRemote(fromSecond: fetchFromSecond)

        // Store in cache
        try storeInCache(newSubmissions, modelType: AtCoderSubmissionModel.self)

        // Single source of truth: always return from cache
        // If fromDate is nil, return all submissions; otherwise filter by date
        return try fetchCached(AtCoderSubmission.self, modelType: AtCoderSubmissionModel.self, from: fromDate)
            .sorted { $0.date < $1.date }
    }

    /// Fetches user submissions from kenkoooo API (without caching)
    /// - Parameters:
    ///   - fromSecond: Unix timestamp to start from (defaults to 0 for all history)
    /// - Returns: Array of submissions
    private func fetchSubmissionsFromRemote(fromSecond: Int = 0) async throws -> [AtCoderSubmission] {
        guard let username = username else {
            throw DataSourceError.notConfigured
        }

        return try await fetchSubmissionsFromAPI(username: username, fromSecond: fromSecond)
    }

    /// Fetches the count of submissions in a time range (for cache validation)
    /// - Parameters:
    ///   - fromSecond: Unix timestamp to start from
    ///   - toSecond: Unix timestamp to end at
    /// - Returns: Number of submissions in the range
    public func fetchSubmissionCount(fromSecond: Int, toSecond: Int) async throws -> Int {
        guard let username = username else {
            throw DataSourceError.notConfigured
        }

        let url = try buildSubmissionCountURL(username: username, fromSecond: fromSecond, toSecond: toSecond)
        let response: SubmissionCountResponse = try await httpClient.get(url, decoder: HTTPClient.snakeCaseDecoder)
        return response.count
    }

    /// Fetches problem difficulties from kenkoooo API
    /// Returns a dictionary mapping problem_id to difficulty rating
    public func fetchProblemDifficulties() async throws -> [String: Int] {
        let url = URL(string: "https://kenkoooo.com/atcoder/resources/problem-models.json")!
        let models: [String: ProblemModel] = try await httpClient.get(url)

        // Extract difficulty ratings, converting to Int
        return models.compactMapValues { model in
            model.difficulty.map { Int($0) }
        }
    }

    /// Fetches daily effort data (submissions grouped by day and difficulty)
    /// - Parameter fromDate: Start date (nil means all time)
    /// - Returns: Array of daily effort summaries sorted by date
    public func fetchDailyEffort(from fromDate: Date? = nil) async throws -> [AtCoderDailyEffort] {
        // Use our cached fetchSubmissions which has count-based validation
        // This ensures we have all historical submissions before computing daily effort
        let submissions = try await fetchSubmissions(from: fromDate)

        // Fetch problem difficulties for effort calculation
        let difficulties = try await fetchProblemDifficulties()

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
        try storeInCache(effort, modelType: AtCoderDailyEffortModel.self)

        return effort
    }

    // MARK: - Private API Methods

    /// Fetches submissions from kenkoooo API (handles pagination for >500 submissions)
    /// - Parameters:
    ///   - username: AtCoder username
    ///   - fromSecond: Unix timestamp to start from
    ///   - toSecond: Optional Unix timestamp to end at (stops fetching when exceeded)
    ///   - sleepDuration: Duration to sleep between API calls (default 1 second)
    private func fetchSubmissionsFromAPI(
        username: String,
        fromSecond: Int,
        toSecond: Int? = nil,
        sleepDuration: Duration = .seconds(1)
    ) async throws -> [AtCoderSubmission] {
        var allSubmissions: [AtCoderSubmission] = []
        var currentFromSecond = fromSecond

        // API returns up to 500 submissions per request, so we paginate
        while true {
            let url = try buildSubmissionsURL(username: username, fromSecond: currentFromSecond)
            let submissions: [AtCoderSubmissionResponse] = try await httpClient.get(url, decoder: HTTPClient.snakeCaseDecoder)

            if submissions.isEmpty {
                break
            }

            // Filter submissions if we have an end bound
            let filteredSubmissions: [AtCoderSubmissionResponse]
            if let toSecond = toSecond {
                filteredSubmissions = submissions.filter { $0.epochSecond <= toSecond }
            } else {
                filteredSubmissions = submissions
            }

            allSubmissions.append(contentsOf: filteredSubmissions.map { $0.toDomain() })

            // If we filtered some out, we've reached our end bound
            if let toSecond = toSecond, submissions.contains(where: { $0.epochSecond > toSecond }) {
                break
            }

            // If we got fewer than 500, we've reached the end
            if submissions.count < 500 {
                break
            }

            // Get the last submission's epoch second for next page
            if let lastEpoch = submissions.last?.epochSecond {
                currentFromSecond = lastEpoch + 1
            } else {
                break
            }

            // Rate limiting between requests
            try await Task.sleep(for: sleepDuration)
        }

        return allSubmissions
    }

    /// Fetches contest history from official AtCoder API
    private func fetchContestHistoryFromAPI(username: String) async throws -> [AtCoderContestHistoryResponse] {
        let url = atCoderBaseURL.appendingPathComponent("users/\(username)/history/json")
        return try await httpClient.get(url)
    }

    /// Fetches AC (Accepted) count from kenkoooo's AtCoder Problems API
    private func fetchACRank(username: String) async throws -> KenkooooRankResponse {
        let url = try buildKenkooooURL(path: "user/ac_rank", username: username)
        return try await httpClient.get(url)
    }

    /// Fetches longest streak from kenkoooo's AtCoder Problems API
    private func fetchStreakRank(username: String) async throws -> KenkooooRankResponse {
        let url = try buildKenkooooURL(path: "user/streak_rank", username: username)
        return try await httpClient.get(url)
    }

    // MARK: - URL Building Helpers

    private func buildSubmissionsURL(username: String, fromSecond: Int) throws -> URL {
        let url = kenkooooBaseURL.appendingPathComponent("user/submissions")
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw DataSourceError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "user", value: username),
            URLQueryItem(name: "from_second", value: String(fromSecond))
        ]

        guard let requestURL = components.url else {
            throw DataSourceError.invalidURL
        }

        return requestURL
    }

    private func buildSubmissionCountURL(username: String, fromSecond: Int, toSecond: Int) throws -> URL {
        let url = kenkooooBaseURL.appendingPathComponent("user/submission_count")
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw DataSourceError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "user", value: username),
            URLQueryItem(name: "from_second", value: String(fromSecond)),
            URLQueryItem(name: "to_second", value: String(toSecond))
        ]

        guard let requestURL = components.url else {
            throw DataSourceError.invalidURL
        }

        return requestURL
    }

    private func buildKenkooooURL(path: String, username: String) throws -> URL {
        let url = kenkooooBaseURL.appendingPathComponent(path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw DataSourceError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "user", value: username)]

        guard let requestURL = components.url else {
            throw DataSourceError.invalidURL
        }

        return requestURL
    }

    // MARK: - Cache-Only Methods (for instant display)

    public func fetchCachedContestHistory() throws -> [AtCoderContestResult] {
        try fetchCached(AtCoderContestResult.self, modelType: AtCoderContestResultModel.self)
    }

    public func fetchCachedDailyEffort(from startDate: Date?) throws -> [AtCoderDailyEffort] {
        try fetchCached(AtCoderDailyEffort.self, modelType: AtCoderDailyEffortModel.self, from: startDate)
    }

    public func fetchCachedSubmissions(from startDate: Date) throws -> [AtCoderSubmission] {
        try fetchCached(AtCoderSubmission.self, modelType: AtCoderSubmissionModel.self, from: startDate)
    }

    public func hasCachedContestHistory() throws -> Bool {
        try hasCached(AtCoderContestResult.self, modelType: AtCoderContestResultModel.self)
    }

    public func hasCachedDailyEffort() throws -> Bool {
        try hasCached(AtCoderDailyEffort.self, modelType: AtCoderDailyEffortModel.self)
    }
}

// MARK: - API Response Models

/// AtCoder contest history response from official history API
private struct AtCoderContestHistoryResponse: Codable {
    let IsRated: Bool
    let Place: Int
    let OldRating: Int
    let NewRating: Int
    let Performance: Int
    let ContestName: String
    let ContestNameEn: String
    let ContestScreenName: String
    let EndTime: String

    var endTime: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: EndTime) ?? Date()
    }
}

/// Response from kenkoooo's ranking APIs (ac_rank, streak_rank, etc.)
private struct KenkooooRankResponse: Codable {
    let count: Int
    let rank: Int
}

/// Response from kenkoooo's submission count API
private struct SubmissionCountResponse: Codable {
    let count: Int
}

/// Submission response from kenkoooo API
private struct AtCoderSubmissionResponse: Codable {
    let id: Int
    let epochSecond: Int
    let problemId: String
    let contestId: String
    let userId: String
    let language: String
    let point: Double
    let length: Int
    let result: String
    let executionTime: Int?

    func toDomain() -> AtCoderSubmission {
        AtCoderSubmission(
            id: id,
            epochSecond: epochSecond,
            problemId: problemId,
            contestId: contestId,
            userId: userId,
            language: language,
            point: point,
            length: length,
            result: result,
            executionTime: executionTime
        )
    }
}

/// Problem model from kenkoooo API (for difficulty ratings)
private struct ProblemModel: Codable {
    let difficulty: Double?
    let discrimination: Double?
    let isExperimental: Bool?

    enum CodingKeys: String, CodingKey {
        case difficulty
        case discrimination
        case isExperimental = "is_experimental"
    }
}
