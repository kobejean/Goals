import Testing
import Foundation
@testable import GoalsData
@testable import GoalsDomain

@Suite("AtCoderDataSource Tests")
struct AtCoderDataSourceTests {

    // MARK: - Configuration Tests

    @Test("configure stores username from credentials")
    func configureStoresUsername() async throws {
        let dataSource = AtCoderDataSource()

        try await dataSource.configure(settings: DataSourceSettings(
            dataSourceType: .atCoder,
            credentials: ["username": "testuser"]
        ))

        let isConfigured = await dataSource.isConfigured()
        #expect(isConfigured)
    }

    @Test("configure throws for invalid data source type")
    func configureThrowsForInvalidType() async throws {
        let dataSource = AtCoderDataSource()

        await #expect(throws: DataSourceError.self) {
            try await dataSource.configure(settings: DataSourceSettings(
                dataSourceType: .typeQuicker,
                credentials: ["username": "testuser"]
            ))
        }
    }

    @Test("configure throws for missing credentials")
    func configureThrowsForMissingCredentials() async throws {
        let dataSource = AtCoderDataSource()

        await #expect(throws: DataSourceError.self) {
            try await dataSource.configure(settings: DataSourceSettings(
                dataSourceType: .atCoder,
                credentials: [:]
            ))
        }
    }

    @Test("configure throws for empty username")
    func configureThrowsForEmptyUsername() async throws {
        let dataSource = AtCoderDataSource()

        await #expect(throws: DataSourceError.self) {
            try await dataSource.configure(settings: DataSourceSettings(
                dataSourceType: .atCoder,
                credentials: ["username": ""]
            ))
        }
    }

    @Test("clearConfiguration resets state")
    func clearConfigurationResetsState() async throws {
        let dataSource = AtCoderDataSource()

        try await dataSource.configure(settings: DataSourceSettings(
            dataSourceType: .atCoder,
            credentials: ["username": "testuser"]
        ))

        try await dataSource.clearConfiguration()

        let isConfigured = await dataSource.isConfigured()
        #expect(!isConfigured)
    }

    // MARK: - Metric Value Tests

    @Test("metricValue extracts rating correctly")
    func metricValueExtractsRating() async {
        let dataSource = AtCoderDataSource()
        let stats = AtCoderCurrentStats(
            date: Date(),
            rating: 1523,
            highestRating: 1650,
            contestsParticipated: 25,
            problemsSolved: 200,
            longestStreak: 14
        )

        let value = dataSource.metricValue(for: "rating", from: stats)
        #expect(value == 1523.0)
    }

    @Test("metricValue extracts highestRating correctly")
    func metricValueExtractsHighestRating() async {
        let dataSource = AtCoderDataSource()
        let stats = AtCoderCurrentStats(
            date: Date(),
            rating: 1523,
            highestRating: 1650,
            contestsParticipated: 25,
            problemsSolved: 200,
            longestStreak: 14
        )

        let value = dataSource.metricValue(for: "highestRating", from: stats)
        #expect(value == 1650.0)
    }

    @Test("metricValue extracts contestsParticipated correctly")
    func metricValueExtractsContestsParticipated() async {
        let dataSource = AtCoderDataSource()
        let stats = AtCoderCurrentStats(
            date: Date(),
            rating: 1523,
            highestRating: 1650,
            contestsParticipated: 25,
            problemsSolved: 200,
            longestStreak: 14
        )

        let value = dataSource.metricValue(for: "contestsParticipated", from: stats)
        #expect(value == 25.0)
    }

    @Test("metricValue extracts problemsSolved correctly")
    func metricValueExtractsProblemsSolved() async {
        let dataSource = AtCoderDataSource()
        let stats = AtCoderCurrentStats(
            date: Date(),
            rating: 1523,
            highestRating: 1650,
            contestsParticipated: 25,
            problemsSolved: 200,
            longestStreak: 14
        )

        let value = dataSource.metricValue(for: "problemsSolved", from: stats)
        #expect(value == 200.0)
    }

    @Test("metricValue extracts longestStreak correctly")
    func metricValueExtractsLongestStreak() async {
        let dataSource = AtCoderDataSource()
        let stats = AtCoderCurrentStats(
            date: Date(),
            rating: 1523,
            highestRating: 1650,
            contestsParticipated: 25,
            problemsSolved: 200,
            longestStreak: 14
        )

        let value = dataSource.metricValue(for: "longestStreak", from: stats)
        #expect(value == 14.0)
    }

    @Test("metricValue returns 0 for nil longestStreak")
    func metricValueReturnsZeroForNilStreak() async {
        let dataSource = AtCoderDataSource()
        let stats = AtCoderCurrentStats(
            date: Date(),
            rating: 1523,
            highestRating: 1650,
            contestsParticipated: 25,
            problemsSolved: 200,
            longestStreak: nil
        )

        let value = dataSource.metricValue(for: "longestStreak", from: stats)
        #expect(value == 0.0)
    }

    @Test("metricValue works with AtCoderContestResult")
    func metricValueWorksWithContestResult() async {
        let dataSource = AtCoderDataSource()
        let result = AtCoderContestResult(
            date: Date(),
            rating: 1200,
            highestRating: 1200,
            contestsParticipated: 10,
            problemsSolved: 100,
            longestStreak: 7,
            contestScreenName: "abc300"
        )

        let ratingValue = dataSource.metricValue(for: "rating", from: result)
        #expect(ratingValue == 1200.0)

        let contestsValue = dataSource.metricValue(for: "contestsParticipated", from: result)
        #expect(contestsValue == 10.0)
    }

    @Test("metricValue returns nil for unknown key")
    func metricValueReturnsNilForUnknownKey() async {
        let dataSource = AtCoderDataSource()
        let stats = AtCoderCurrentStats(
            date: Date(),
            rating: 1523,
            highestRating: 1650,
            contestsParticipated: 25,
            problemsSolved: 200,
            longestStreak: 14
        )

        let value = dataSource.metricValue(for: "unknown", from: stats)
        #expect(value == nil)
    }

    @Test("metricValue returns nil for wrong type")
    func metricValueReturnsNilForWrongType() async {
        let dataSource = AtCoderDataSource()

        let value = dataSource.metricValue(for: "rating", from: "not a stats object")
        #expect(value == nil)
    }

    // MARK: - Available Metrics Tests

    @Test("availableMetrics returns expected metrics")
    func availableMetricsReturnsExpectedMetrics() async {
        let dataSource = AtCoderDataSource()
        let metrics = dataSource.availableMetrics

        #expect(metrics.count == 5)
        #expect(metrics.contains { $0.key == "rating" })
        #expect(metrics.contains { $0.key == "highestRating" })
        #expect(metrics.contains { $0.key == "contestsParticipated" })
        #expect(metrics.contains { $0.key == "problemsSolved" })
        #expect(metrics.contains { $0.key == "longestStreak" })
    }

    // MARK: - Rank Color Tests

    @Test("AtCoderRankColor returns correct color for difficulty")
    func atCoderRankColorReturnsCorrectColor() {
        #expect(AtCoderRankColor.from(difficulty: nil) == .gray)
        #expect(AtCoderRankColor.from(difficulty: 300) == .gray)
        #expect(AtCoderRankColor.from(difficulty: 400) == .brown)
        #expect(AtCoderRankColor.from(difficulty: 800) == .green)
        #expect(AtCoderRankColor.from(difficulty: 1200) == .cyan)
        #expect(AtCoderRankColor.from(difficulty: 1600) == .blue)
        #expect(AtCoderRankColor.from(difficulty: 2000) == .yellow)
        #expect(AtCoderRankColor.from(difficulty: 2400) == .orange)
        #expect(AtCoderRankColor.from(difficulty: 2800) == .red)
        #expect(AtCoderRankColor.from(difficulty: 3500) == .red)
    }

    @Test("AtCoderStatsProtocol rankColor computed property")
    func atCoderStatsProtocolRankColor() {
        let stats1 = AtCoderCurrentStats(
            date: Date(),
            rating: 300,
            highestRating: 300,
            contestsParticipated: 5,
            problemsSolved: 50
        )
        #expect(stats1.rankColor == .gray)

        let stats2 = AtCoderCurrentStats(
            date: Date(),
            rating: 1500,
            highestRating: 1500,
            contestsParticipated: 20,
            problemsSolved: 150
        )
        #expect(stats2.rankColor == .cyan)

        let stats3 = AtCoderCurrentStats(
            date: Date(),
            rating: 2500,
            highestRating: 2500,
            contestsParticipated: 50,
            problemsSolved: 500
        )
        #expect(stats3.rankColor == .orange)
    }

    // MARK: - Cache Key Tests

    @Test("AtCoderContestResult generates correct cache key")
    func atCoderContestResultCacheKey() {
        let result = AtCoderContestResult(
            date: Date(),
            rating: 1200,
            highestRating: 1200,
            contestsParticipated: 10,
            problemsSolved: 100,
            contestScreenName: "abc300"
        )

        #expect(result.cacheKey == "ac:contest:abc300")
    }
}
