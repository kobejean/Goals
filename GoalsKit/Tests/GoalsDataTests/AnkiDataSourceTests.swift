import Testing
import Foundation
@testable import GoalsData
@testable import GoalsDomain

@Suite("AnkiDataSource Tests")
struct AnkiDataSourceTests {

    // MARK: - Configuration Tests

    @Test("configure parses host, port, and decks from settings")
    func configureParseSettings() async throws {
        let dataSource = AnkiDataSource()

        try await dataSource.configure(settings: DataSourceSettings(
            dataSourceType: .anki,
            options: [
                "host": "192.168.1.100",
                "port": "9000",
                "decks": "Japanese, Programming, Math"
            ]
        ))

        let isConfigured = await dataSource.isConfigured()
        #expect(isConfigured)
    }

    @Test("configure uses default port 8765 when not specified")
    func configureUsesDefaultPort() async throws {
        let dataSource = AnkiDataSource()

        try await dataSource.configure(settings: DataSourceSettings(
            dataSourceType: .anki,
            options: ["host": "127.0.0.1"]
        ))

        let isConfigured = await dataSource.isConfigured()
        #expect(isConfigured)
    }

    @Test("configure throws for invalid data source type")
    func configureThrowsForInvalidType() async throws {
        let dataSource = AnkiDataSource()

        await #expect(throws: DataSourceError.self) {
            try await dataSource.configure(settings: DataSourceSettings(
                dataSourceType: .typeQuicker,
                options: ["host": "127.0.0.1"]
            ))
        }
    }

    @Test("configure throws for missing host")
    func configureThrowsForMissingHost() async throws {
        let dataSource = AnkiDataSource()

        await #expect(throws: DataSourceError.self) {
            try await dataSource.configure(settings: DataSourceSettings(
                dataSourceType: .anki,
                options: ["port": "8765"]
            ))
        }
    }

    @Test("configure throws for empty host")
    func configureThrowsForEmptyHost() async throws {
        let dataSource = AnkiDataSource()

        await #expect(throws: DataSourceError.self) {
            try await dataSource.configure(settings: DataSourceSettings(
                dataSourceType: .anki,
                options: ["host": "", "port": "8765"]
            ))
        }
    }

    @Test("configure throws for invalid port")
    func configureThrowsForInvalidPort() async throws {
        let dataSource = AnkiDataSource()

        await #expect(throws: DataSourceError.self) {
            try await dataSource.configure(settings: DataSourceSettings(
                dataSourceType: .anki,
                options: ["host": "127.0.0.1", "port": "not-a-number"]
            ))
        }
    }

    @Test("clearConfiguration resets state")
    func clearConfigurationResetsState() async throws {
        let dataSource = AnkiDataSource()

        try await dataSource.configure(settings: DataSourceSettings(
            dataSourceType: .anki,
            options: ["host": "127.0.0.1", "port": "8765"]
        ))

        try await dataSource.clearConfiguration()

        let isConfigured = await dataSource.isConfigured()
        #expect(!isConfigured)
    }

    // MARK: - Metric Value Tests

    @Test("metricValue extracts reviews correctly")
    func metricValueExtractsReviews() async {
        let dataSource = AnkiDataSource()
        let stats = AnkiDailyStats(
            date: Date(),
            reviewCount: 50,
            studyTimeSeconds: 1800,
            correctCount: 45,
            newCardsCount: 10
        )

        let value = dataSource.metricValue(for: "reviews", from: stats)
        #expect(value == 50.0)
    }

    @Test("metricValue extracts studyTime in minutes correctly")
    func metricValueExtractsStudyTime() async {
        let dataSource = AnkiDataSource()
        let stats = AnkiDailyStats(
            date: Date(),
            reviewCount: 50,
            studyTimeSeconds: 1800, // 30 minutes
            correctCount: 45,
            newCardsCount: 10
        )

        let value = dataSource.metricValue(for: "studyTime", from: stats)
        #expect(value == 30.0) // 1800 seconds / 60 = 30 minutes
    }

    @Test("metricValue extracts retention rate correctly")
    func metricValueExtractsRetention() async {
        let dataSource = AnkiDataSource()
        let stats = AnkiDailyStats(
            date: Date(),
            reviewCount: 100,
            studyTimeSeconds: 1800,
            correctCount: 90,
            newCardsCount: 10
        )

        let value = dataSource.metricValue(for: "retention", from: stats)
        #expect(value == 90.0) // 90/100 * 100 = 90%
    }

    @Test("metricValue extracts newCards correctly")
    func metricValueExtractsNewCards() async {
        let dataSource = AnkiDataSource()
        let stats = AnkiDailyStats(
            date: Date(),
            reviewCount: 50,
            studyTimeSeconds: 1800,
            correctCount: 45,
            newCardsCount: 10
        )

        let value = dataSource.metricValue(for: "newCards", from: stats)
        #expect(value == 10.0)
    }

    @Test("metricValue returns nil for unknown key")
    func metricValueReturnsNilForUnknownKey() async {
        let dataSource = AnkiDataSource()
        let stats = AnkiDailyStats(
            date: Date(),
            reviewCount: 50,
            studyTimeSeconds: 1800,
            correctCount: 45,
            newCardsCount: 10
        )

        let value = dataSource.metricValue(for: "unknown", from: stats)
        #expect(value == nil)
    }

    @Test("metricValue returns nil for wrong type")
    func metricValueReturnsNilForWrongType() async {
        let dataSource = AnkiDataSource()

        let value = dataSource.metricValue(for: "reviews", from: "not a stats object")
        #expect(value == nil)
    }

    // MARK: - AnkiDailyStats Computed Properties Tests

    @Test("AnkiDailyStats studyTimeMinutes converts seconds to minutes")
    func ankiDailyStatsStudyTimeMinutes() {
        let stats = AnkiDailyStats(
            date: Date(),
            reviewCount: 50,
            studyTimeSeconds: 900, // 15 minutes
            correctCount: 45,
            newCardsCount: 10
        )

        #expect(stats.studyTimeMinutes == 15.0)
    }

    @Test("AnkiDailyStats retentionRate calculates percentage")
    func ankiDailyStatsRetentionRate() {
        let stats = AnkiDailyStats(
            date: Date(),
            reviewCount: 80,
            studyTimeSeconds: 1200,
            correctCount: 72, // 90%
            newCardsCount: 5
        )

        #expect(stats.retentionRate == 90.0)
    }

    @Test("AnkiDailyStats retentionRate handles zero reviews")
    func ankiDailyStatsRetentionRateZeroReviews() {
        let stats = AnkiDailyStats(
            date: Date(),
            reviewCount: 0,
            studyTimeSeconds: 0,
            correctCount: 0,
            newCardsCount: 0
        )

        #expect(stats.retentionRate == 0.0)
    }

    // MARK: - Available Metrics Tests

    @Test("availableMetrics returns expected metrics")
    func availableMetricsReturnsExpectedMetrics() async {
        let dataSource = AnkiDataSource()
        let metrics = dataSource.availableMetrics

        #expect(metrics.count == 4)
        #expect(metrics.contains { $0.key == "reviews" })
        #expect(metrics.contains { $0.key == "studyTime" })
        #expect(metrics.contains { $0.key == "retention" })
        #expect(metrics.contains { $0.key == "newCards" })
    }
}
