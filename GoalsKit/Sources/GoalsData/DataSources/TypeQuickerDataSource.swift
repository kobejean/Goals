import Foundation
import GoalsDomain

/// Data source implementation for TypeQuicker typing statistics
public actor TypeQuickerDataSource: TypeQuickerDataSourceProtocol {
    public let dataSourceType: DataSourceType = .typeQuicker

    private var username: String?
    private var baseURL: URL?
    private let urlSession: URLSession

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
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

    public func fetchData(from startDate: Date, to endDate: Date) async throws -> [DataPoint] {
        let stats = try await fetchStats(from: startDate, to: endDate)
        return stats.map { stat in
            DataPoint(
                goalId: UUID(), // Will be assigned when linked to a goal
                value: stat.wordsPerMinute,
                timestamp: stat.date,
                source: .typeQuicker,
                metadata: [
                    "accuracy": String(format: "%.1f", stat.accuracy),
                    "practiceMinutes": "\(stat.practiceTimeMinutes)",
                    "sessions": "\(stat.sessionsCount)"
                ]
            )
        }
    }

    public func fetchLatest() async throws -> DataPoint? {
        guard let stat = try await fetchLatestStats() else { return nil }
        return DataPoint(
            goalId: UUID(),
            value: stat.wordsPerMinute,
            timestamp: stat.date,
            source: .typeQuicker,
            metadata: [
                "accuracy": String(format: "%.1f", stat.accuracy),
                "practiceMinutes": "\(stat.practiceTimeMinutes)",
                "sessions": "\(stat.sessionsCount)"
            ]
        )
    }

    public func fetchStats(from startDate: Date, to endDate: Date) async throws -> [TypeQuickerStats] {
        guard let username = username else {
            throw DataSourceError.notConfigured
        }

        let base = baseURL ?? URL(string: "https://api.typequicker.com")!
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        var components = URLComponents(url: base.appendingPathComponent("stats/\(username)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: dateFormatter.string(from: startDate).prefix(10).description),
            URLQueryItem(name: "end_date", value: dateFormatter.string(from: endDate).prefix(10).description)
        ]

        guard let url = components.url else {
            throw DataSourceError.invalidURL
        }

        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DataSourceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw DataSourceError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let apiResponse = try decoder.decode(TypeQuickerAPIResponse.self, from: data)
        return apiResponse.toStats()
    }

    public func fetchLatestStats() async throws -> TypeQuickerStats? {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        let stats = try await fetchStats(from: startDate, to: endDate)
        return stats.last
    }
}

// MARK: - API Response Models

/// API response structure from TypeQuicker
private struct TypeQuickerAPIResponse: Codable {
    let dailyStats: [DailyStat]?

    enum CodingKeys: String, CodingKey {
        case dailyStats = "daily_stats"
    }

    struct DailyStat: Codable {
        let date: String
        let wpm: Double?
        let accuracy: Double?
        let practiceMinutes: Int?
        let sessions: Int?

        enum CodingKeys: String, CodingKey {
            case date
            case wpm
            case accuracy
            case practiceMinutes = "practice_minutes"
            case sessions
        }
    }

    func toStats() -> [TypeQuickerStats] {
        guard let dailyStats = dailyStats else { return [] }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return dailyStats.compactMap { stat -> TypeQuickerStats? in
            guard let date = dateFormatter.date(from: stat.date) else { return nil }
            return TypeQuickerStats(
                date: date,
                wordsPerMinute: stat.wpm ?? 0,
                accuracy: stat.accuracy ?? 0,
                practiceTimeMinutes: stat.practiceMinutes ?? 0,
                sessionsCount: stat.sessions ?? 0
            )
        }
    }
}

/// Errors that can occur with data sources
public enum DataSourceError: Error, Sendable {
    case notConfigured
    case invalidConfiguration
    case missingCredentials
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case parseError(String)
}
