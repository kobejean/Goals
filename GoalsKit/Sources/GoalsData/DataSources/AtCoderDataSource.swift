import Foundation
import GoalsDomain

/// Data source implementation for AtCoder competitive programming statistics
/// Uses official AtCoder API for contest history and kenkoooo's AtCoder Problems API for solve counts
public actor AtCoderDataSource: AtCoderDataSourceProtocol {
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
        guard let stat = stats as? AtCoderStats else { return nil }
        switch key {
        case "rating": return Double(stat.rating)
        case "highestRating": return Double(stat.highestRating)
        case "contestsParticipated": return Double(stat.contestsParticipated)
        case "problemsSolved": return Double(stat.problemsSolved)
        case "longestStreak": return Double(stat.longestStreak ?? 0)
        default: return nil
        }
    }

    private var username: String?
    private let httpClient: HTTPClient

    // API base URLs
    private let atCoderBaseURL = URL(string: "https://atcoder.jp")!
    private let kenkooooBaseURL = URL(string: "https://kenkoooo.com/atcoder/atcoder-api/v3")!

    public init(httpClient: HTTPClient = HTTPClient()) {
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

    public func fetchLatestMetricValue(for metricKey: String) async throws -> Double? {
        guard let stats = try await fetchStats() else { return nil }
        return metricValue(for: metricKey, from: stats)
    }

    public func fetchStats() async throws -> AtCoderStats? {
        guard let username = username else {
            throw DataSourceError.notConfigured
        }

        // Fetch data from multiple APIs concurrently
        async let contestHistoryTask = fetchContestHistoryFromAPI(username: username)
        async let acRankTask = fetchACRank(username: username)
        async let streakRankTask = fetchStreakRank(username: username)

        let contestHistory = try await contestHistoryTask
        let acRank = try? await acRankTask
        let streakRank = try? await streakRankTask

        guard let latest = contestHistory.last else {
            // User has no contest history, but might still have solved problems
            if let acRank {
                return AtCoderStats(
                    date: Date(),
                    rating: 0,
                    highestRating: 0,
                    contestsParticipated: 0,
                    problemsSolved: acRank.count,
                    longestStreak: streakRank?.count
                )
            }
            return nil
        }

        return AtCoderStats(
            date: Date(),
            rating: latest.NewRating,
            highestRating: contestHistory.map { $0.NewRating }.max() ?? 0,
            contestsParticipated: contestHistory.count,
            problemsSolved: acRank?.count ?? 0,
            longestStreak: streakRank?.count
        )
    }

    public func fetchContestHistory() async throws -> [AtCoderStats] {
        guard let username = username else {
            throw DataSourceError.notConfigured
        }

        let contestHistory = try await fetchContestHistoryFromAPI(username: username)

        // Also fetch AC count for the most recent stats
        let acRank = try? await fetchACRank(username: username)
        let streakRank = try? await fetchStreakRank(username: username)
        let problemsSolved = acRank?.count ?? 0
        let longestStreak = streakRank?.count

        var highestSoFar = 0
        return contestHistory.enumerated().map { (index, result) in
            highestSoFar = max(highestSoFar, result.NewRating)
            return AtCoderStats(
                date: result.endTime,
                rating: result.NewRating,
                highestRating: highestSoFar,
                contestsParticipated: index + 1,
                problemsSolved: index == contestHistory.count - 1 ? problemsSolved : 0,
                longestStreak: index == contestHistory.count - 1 ? longestStreak : nil,
                contestScreenName: result.ContestScreenName
            )
        }
    }

    // MARK: - Submission APIs

    /// Fetches user submissions from kenkoooo API
    /// - Parameters:
    ///   - fromDate: Start date for submissions (defaults to 1 year ago)
    /// - Returns: Array of submissions
    public func fetchSubmissions(from fromDate: Date? = nil) async throws -> [AtCoderSubmission] {
        guard let username = username else {
            throw DataSourceError.notConfigured
        }

        let startDate = fromDate ?? Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let fromSecond = Int(startDate.timeIntervalSince1970)

        return try await fetchSubmissionsFromAPI(username: username, fromSecond: fromSecond)
    }

    /// Fetches submissions with configurable rate limiting for backfill operations
    /// - Parameters:
    ///   - fromSecond: Unix timestamp to start from
    ///   - toSecond: Unix timestamp to end at (optional, defaults to now)
    ///   - sleepDuration: Duration to sleep between API calls (default 1.5s)
    /// - Returns: Array of submissions within the specified time range
    public func fetchSubmissionsWithRateLimit(
        fromSecond: Int,
        toSecond: Int? = nil,
        sleepDuration: Duration = .milliseconds(1500)
    ) async throws -> [AtCoderSubmission] {
        guard let username = username else {
            throw DataSourceError.notConfigured
        }

        return try await fetchSubmissionsFromAPI(
            username: username,
            fromSecond: fromSecond,
            toSecond: toSecond,
            sleepDuration: sleepDuration
        )
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
    /// - Parameter fromDate: Start date (defaults to 1 year ago)
    /// - Returns: Array of daily effort summaries sorted by date
    public func fetchDailyEffort(from fromDate: Date? = nil) async throws -> [AtCoderDailyEffort] {
        // Fetch submissions and difficulties concurrently
        async let submissionsTask = fetchSubmissions(from: fromDate)
        async let difficultiesTask = fetchProblemDifficulties()

        let submissions = try await submissionsTask
        let difficulties = try await difficultiesTask

        // Group submissions by day
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
        return dailyData.map { date, submissions in
            AtCoderDailyEffort(date: date, submissionsByDifficulty: submissions)
        }.sorted { $0.date < $1.date }
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
    private func fetchContestHistoryFromAPI(username: String) async throws -> [AtCoderContestResult] {
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
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "user", value: username),
            URLQueryItem(name: "from_second", value: String(fromSecond))
        ]

        guard let requestURL = components.url else {
            throw DataSourceError.invalidURL
        }

        return requestURL
    }

    private func buildKenkooooURL(path: String, username: String) throws -> URL {
        let url = kenkooooBaseURL.appendingPathComponent(path)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "user", value: username)]

        guard let requestURL = components.url else {
            throw DataSourceError.invalidURL
        }

        return requestURL
    }
}

// MARK: - API Response Models

/// AtCoder contest result from official history API
private struct AtCoderContestResult: Codable {
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
