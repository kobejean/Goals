import Foundation
import SwiftData
import GoalsDomain

/// Data source implementation for TensorTonic AI/ML problem-solving statistics.
/// Uses cookie-based session authentication via Better Auth.
/// See docs/TENSORTONIC_API.md for API documentation.
public actor TensorTonicDataSource: TensorTonicDataSourceProtocol, CacheableDataSource {
    public let dataSourceType: DataSourceType = .tensorTonic

    public nonisolated var availableMetrics: [MetricInfo] {
        [
            MetricInfo(key: "totalSolved", name: "Problems Solved", unit: "", icon: "checkmark.circle"),
            MetricInfo(key: "easySolved", name: "Easy Solved", unit: "", icon: "1.circle"),
            MetricInfo(key: "mediumSolved", name: "Medium Solved", unit: "", icon: "2.circle"),
            MetricInfo(key: "hardSolved", name: "Hard Solved", unit: "", icon: "3.circle"),
            MetricInfo(key: "researchTotalSolved", name: "Research Solved", unit: "", icon: "brain"),
            MetricInfo(key: "combinedTotalSolved", name: "Combined Total", unit: "", icon: "sum"),
        ]
    }

    public nonisolated func metricValue(for key: String, from stats: Any) -> Double? {
        guard let stat = stats as? TensorTonicStats else { return nil }
        switch key {
        case "totalSolved": return Double(stat.totalSolved)
        case "easySolved": return Double(stat.easySolved)
        case "mediumSolved": return Double(stat.mediumSolved)
        case "hardSolved": return Double(stat.hardSolved)
        case "researchTotalSolved": return Double(stat.researchTotalSolved)
        case "combinedTotalSolved": return Double(stat.combinedTotalSolved)
        case "regularProgress": return stat.regularProgress * 100
        case "researchProgress": return stat.researchProgress * 100
        default: return nil
        }
    }

    // MARK: - CacheableDataSource

    public let modelContainer: ModelContainer?

    // MARK: - Configuration

    private var userId: String?
    private var sessionToken: String?
    private let urlSession: URLSession

    private static let apiBaseURL = "https://api.tensortonic.com"
    private static let webBaseURL = "https://www.tensortonic.com"

    /// Creates a TensorTonicDataSource without caching (for testing).
    public init(urlSession: URLSession = .shared) {
        self.modelContainer = nil
        self.urlSession = urlSession
    }

    /// Creates a TensorTonicDataSource with caching enabled (for production).
    public init(modelContainer: ModelContainer, urlSession: URLSession = .shared) {
        self.modelContainer = modelContainer
        self.urlSession = urlSession
    }

    public func isConfigured() async -> Bool {
        userId != nil && sessionToken != nil
    }

    public func configure(settings: DataSourceSettings) async throws {
        guard settings.dataSourceType == .tensorTonic else {
            throw DataSourceError.invalidConfiguration
        }

        guard let userId = settings.credentials["userId"], !userId.isEmpty else {
            throw DataSourceError.missingCredentials
        }

        guard let sessionToken = settings.credentials["sessionToken"], !sessionToken.isEmpty else {
            throw DataSourceError.missingCredentials
        }

        self.userId = userId
        self.sessionToken = sessionToken
    }

    public func clearConfiguration() async throws {
        userId = nil
        sessionToken = nil
    }

    public func fetchLatestMetricValue(for metricKey: String, taskId: UUID?) async throws -> Double? {
        guard let stats = try await fetchStats() else { return nil }
        return metricValue(for: metricKey, from: stats)
    }

    // MARK: - TensorTonicDataSourceProtocol

    public func fetchStats() async throws -> TensorTonicStats? {
        guard let userId = userId, let sessionToken = sessionToken else {
            throw DataSourceError.notConfigured
        }

        let url = URL(string: "\(Self.apiBaseURL)/api/user/\(userId)/stats")!
        let response: StatsResponse = try await performRequest(url: url, sessionToken: sessionToken)

        guard response.status == "success" else {
            throw DataSourceError.invalidResponse
        }

        let stats = TensorTonicStats(
            date: Date(),
            easySolved: response.data.easy,
            mediumSolved: response.data.medium,
            hardSolved: response.data.hard,
            totalSolved: response.data.total,
            totalEasyProblems: response.data.totalEasyProblems,
            totalMediumProblems: response.data.totalMediumProblems,
            totalHardProblems: response.data.totalHardProblems,
            researchEasySolved: response.data.researchEasy,
            researchMediumSolved: response.data.researchMedium,
            researchHardSolved: response.data.researchHard,
            researchTotalSolved: response.data.researchTotal,
            totalResearchEasyProblems: response.data.totalResearchEasyProblems,
            totalResearchMediumProblems: response.data.totalResearchMediumProblems,
            totalResearchHardProblems: response.data.totalResearchHardProblems
        )

        // Cache the stats
        try storeInCache([stats], modelType: TensorTonicStatsModel.self)

        return stats
    }

    public func fetchHeatmap(from startDate: Date, to endDate: Date) async throws -> [TensorTonicHeatmapEntry] {
        guard let userId = userId, let sessionToken = sessionToken else {
            throw DataSourceError.notConfigured
        }

        let url = URL(string: "\(Self.apiBaseURL)/api/user/\(userId)/heatmap")!
        let response: HeatmapResponse = try await performRequest(url: url, sessionToken: sessionToken)

        guard response.status == "success" else {
            throw DataSourceError.invalidResponse
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let entries = response.data.compactMap { item -> TensorTonicHeatmapEntry? in
            guard let date = dateFormatter.date(from: item.date) else { return nil }
            guard date >= startDate && date <= endDate else { return nil }
            return TensorTonicHeatmapEntry(date: date, count: item.value)
        }

        // Cache the entries
        try storeInCache(entries, modelType: TensorTonicHeatmapModel.self)

        return entries
    }

    public func testConnection() async throws -> Bool {
        guard let userId = userId, let sessionToken = sessionToken else {
            throw DataSourceError.notConfigured
        }

        // Test by fetching stats
        let url = URL(string: "\(Self.apiBaseURL)/api/user/\(userId)/stats")!

        do {
            let _: StatsResponse = try await performRequest(url: url, sessionToken: sessionToken)
            return true
        } catch {
            throw DataSourceError.connectionFailed(error.localizedDescription)
        }
    }

    // MARK: - Cache Methods

    public func fetchCachedStats() throws -> TensorTonicStats? {
        let cached = try fetchCached(TensorTonicStats.self, modelType: TensorTonicStatsModel.self)
        return cached.max { $0.date < $1.date }
    }

    public func fetchCachedHeatmap(from startDate: Date, to endDate: Date) throws -> [TensorTonicHeatmapEntry] {
        try fetchCached(TensorTonicHeatmapEntry.self, modelType: TensorTonicHeatmapModel.self, from: startDate, to: endDate)
    }

    public func hasCachedData() throws -> Bool {
        try hasCached(TensorTonicStats.self, modelType: TensorTonicStatsModel.self)
    }

    // MARK: - Private Helpers

    private func performRequest<T: Decodable>(url: URL, sessionToken: String) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Set required headers for TensorTonic API
        request.setValue("__Secure-better-auth.session_token=\(sessionToken)", forHTTPHeaderField: "Cookie")
        request.setValue(Self.webBaseURL, forHTTPHeaderField: "Origin")
        request.setValue("\(Self.webBaseURL)/", forHTTPHeaderField: "Referer")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DataSourceError.invalidResponse
        }

        // Handle authentication errors
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw DataSourceError.unauthorized
        }

        // Handle rate limiting
        if httpResponse.statusCode == 429 {
            throw DataSourceError.rateLimited
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DataSourceError.httpError(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - API Response Models

/// Response from /api/user/{userId}/stats
private struct StatsResponse: Decodable {
    let status: String
    let data: StatsData

    struct StatsData: Decodable {
        let easy: Int
        let medium: Int
        let hard: Int
        let total: Int
        let totalEasyProblems: Int
        let totalMediumProblems: Int
        let totalHardProblems: Int
        let researchEasy: Int
        let researchMedium: Int
        let researchHard: Int
        let researchTotal: Int
        let totalResearchEasyProblems: Int
        let totalResearchMediumProblems: Int
        let totalResearchHardProblems: Int
    }
}

/// Response from /api/user/{userId}/heatmap
private struct HeatmapResponse: Decodable {
    let status: String
    let data: [HeatmapItem]

    struct HeatmapItem: Decodable {
        let date: String
        let value: Int
    }
}

// MARK: - DataSourceConfigurable

extension TensorTonicDataSource: DataSourceConfigurable {
    public static var dataSourceType: DataSourceType { .tensorTonic }
    public static var credentialMappings: [ConfigKeyMapping] {
        [
            ConfigKeyMapping("tensorTonicUserId", as: "userId"),
            ConfigKeyMapping("tensorTonicSessionToken", as: "sessionToken")
        ]
    }
}
