import Testing
import Foundation
@testable import GoalsData
@testable import GoalsDomain

@Suite("TypeQuickerDataSource Tests")
struct TypeQuickerDataSourceTests {

    // MARK: - Configuration Tests

    @Test("configure stores username from credentials")
    func configureStoresUsername() async throws {
        let dataSource = TypeQuickerDataSource()

        try await dataSource.configure(settings: DataSourceSettings(
            dataSourceType: .typeQuicker,
            credentials: ["username": "testuser"]
        ))

        let isConfigured = await dataSource.isConfigured()
        #expect(isConfigured)
    }

    @Test("configure throws for invalid data source type")
    func configureThrowsForInvalidType() async throws {
        let dataSource = TypeQuickerDataSource()

        await #expect(throws: DataSourceError.self) {
            try await dataSource.configure(settings: DataSourceSettings(
                dataSourceType: .atCoder,
                credentials: ["username": "testuser"]
            ))
        }
    }

    @Test("configure throws for missing credentials")
    func configureThrowsForMissingCredentials() async throws {
        let dataSource = TypeQuickerDataSource()

        await #expect(throws: DataSourceError.self) {
            try await dataSource.configure(settings: DataSourceSettings(
                dataSourceType: .typeQuicker,
                credentials: [:]
            ))
        }
    }

    @Test("configure throws for empty username")
    func configureThrowsForEmptyUsername() async throws {
        let dataSource = TypeQuickerDataSource()

        await #expect(throws: DataSourceError.self) {
            try await dataSource.configure(settings: DataSourceSettings(
                dataSourceType: .typeQuicker,
                credentials: ["username": ""]
            ))
        }
    }

    @Test("clearConfiguration resets state")
    func clearConfigurationResetsState() async throws {
        let dataSource = TypeQuickerDataSource()

        try await dataSource.configure(settings: DataSourceSettings(
            dataSourceType: .typeQuicker,
            credentials: ["username": "testuser"]
        ))

        try await dataSource.clearConfiguration()

        let isConfigured = await dataSource.isConfigured()
        #expect(!isConfigured)
    }

    // MARK: - Metric Value Tests

    @Test("metricValue extracts wpm correctly")
    func metricValueExtractsWpm() async {
        let dataSource = TypeQuickerDataSource()
        let stats = TypeQuickerStats(
            date: Date(),
            wordsPerMinute: 85.5,
            accuracy: 97.2,
            practiceTimeMinutes: 30,
            sessionsCount: 5
        )

        let value = dataSource.metricValue(for: "wpm", from: stats)
        #expect(value == 85.5)
    }

    @Test("metricValue extracts accuracy correctly")
    func metricValueExtractsAccuracy() async {
        let dataSource = TypeQuickerDataSource()
        let stats = TypeQuickerStats(
            date: Date(),
            wordsPerMinute: 85.5,
            accuracy: 97.2,
            practiceTimeMinutes: 30,
            sessionsCount: 5
        )

        let value = dataSource.metricValue(for: "accuracy", from: stats)
        #expect(value == 97.2)
    }

    @Test("metricValue extracts practiceTime correctly")
    func metricValueExtractsPracticeTime() async {
        let dataSource = TypeQuickerDataSource()
        let stats = TypeQuickerStats(
            date: Date(),
            wordsPerMinute: 85.5,
            accuracy: 97.2,
            practiceTimeMinutes: 30,
            sessionsCount: 5
        )

        let value = dataSource.metricValue(for: "practiceTime", from: stats)
        #expect(value == 30.0)
    }

    @Test("metricValue returns nil for unknown key")
    func metricValueReturnsNilForUnknownKey() async {
        let dataSource = TypeQuickerDataSource()
        let stats = TypeQuickerStats(
            date: Date(),
            wordsPerMinute: 85.5,
            accuracy: 97.2,
            practiceTimeMinutes: 30,
            sessionsCount: 5
        )

        let value = dataSource.metricValue(for: "unknown", from: stats)
        #expect(value == nil)
    }

    @Test("metricValue returns nil for wrong type")
    func metricValueReturnsNilForWrongType() async {
        let dataSource = TypeQuickerDataSource()

        let value = dataSource.metricValue(for: "wpm", from: "not a stats object")
        #expect(value == nil)
    }

    // MARK: - Available Metrics Tests

    @Test("availableMetrics returns expected metrics")
    func availableMetricsReturnsExpectedMetrics() async {
        let dataSource = TypeQuickerDataSource()
        let metrics = dataSource.availableMetrics

        #expect(metrics.count == 3)
        #expect(metrics.contains { $0.key == "wpm" })
        #expect(metrics.contains { $0.key == "accuracy" })
        #expect(metrics.contains { $0.key == "practiceTime" })
    }
}
