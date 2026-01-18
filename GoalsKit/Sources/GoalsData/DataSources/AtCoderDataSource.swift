import Foundation
import GoalsDomain

/// Data source implementation for AtCoder competitive programming statistics
public actor AtCoderDataSource: AtCoderDataSourceProtocol {
    public let dataSourceType: DataSourceType = .atCoder

    private var username: String?
    private let urlSession: URLSession
    private let baseURL = URL(string: "https://atcoder.jp")!

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
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

    public func fetchData(from startDate: Date, to endDate: Date) async throws -> [DataPoint] {
        guard let stats = try await fetchStats() else { return [] }

        return [
            DataPoint(
                goalId: UUID(),
                value: Double(stats.rating),
                timestamp: stats.date,
                source: .atCoder,
                metadata: [
                    "highestRating": "\(stats.highestRating)",
                    "contests": "\(stats.contestsParticipated)",
                    "problemsSolved": "\(stats.problemsSolved)"
                ]
            )
        ]
    }

    public func fetchLatest() async throws -> DataPoint? {
        guard let stats = try await fetchStats() else { return nil }

        return DataPoint(
            goalId: UUID(),
            value: Double(stats.rating),
            timestamp: stats.date,
            source: .atCoder,
            metadata: [
                "highestRating": "\(stats.highestRating)",
                "contests": "\(stats.contestsParticipated)",
                "problemsSolved": "\(stats.problemsSolved)"
            ]
        )
    }

    public func fetchStats() async throws -> AtCoderStats? {
        guard let username = username else {
            throw DataSourceError.notConfigured
        }

        // Fetch user profile data from AtCoder API
        // Note: AtCoder doesn't have an official API, so we'd typically scrape
        // or use a third-party service. For now, we'll use a common pattern.
        let profileURL = URL(string: "https://atcoder.jp/users/\(username)/history/json")!

        let (data, response) = try await urlSession.data(from: profileURL)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DataSourceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw DataSourceError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let history = try decoder.decode([AtCoderContestResult].self, from: data)

        guard let latest = history.last else {
            return nil
        }

        return AtCoderStats(
            date: Date(),
            rating: latest.NewRating,
            highestRating: history.map { $0.NewRating }.max() ?? 0,
            contestsParticipated: history.count,
            problemsSolved: 0 // Would need separate API call
        )
    }

    public func fetchContestHistory() async throws -> [AtCoderStats] {
        guard let username = username else {
            throw DataSourceError.notConfigured
        }

        let profileURL = URL(string: "https://atcoder.jp/users/\(username)/history/json")!

        let (data, response) = try await urlSession.data(from: profileURL)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DataSourceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw DataSourceError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let history = try decoder.decode([AtCoderContestResult].self, from: data)

        var highestSoFar = 0
        return history.enumerated().map { (index, result) in
            highestSoFar = max(highestSoFar, result.NewRating)
            return AtCoderStats(
                date: result.endTime,
                rating: result.NewRating,
                highestRating: highestSoFar,
                contestsParticipated: index + 1,
                problemsSolved: 0
            )
        }
    }
}

// MARK: - API Response Models

/// AtCoder contest result from history API
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
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: EndTime) ?? Date()
    }
}
