import Testing
import Foundation
@testable import GoalsData
@testable import GoalsDomain

@Suite("ZoteroDataSource Tests")
struct ZoteroDataSourceTests {

    // MARK: - Configuration Tests

    @Test("configure stores collection keys for reading status")
    func configureStoresCollectionKeys() async throws {
        let dataSource = ZoteroDataSource()

        try await dataSource.configure(settings: DataSourceSettings(
            dataSourceType: .zotero,
            credentials: [
                "apiKey": "test_api_key",
                "userID": "12345"
            ],
            options: [
                "toReadCollection": "TOREAD01",
                "inProgressCollection": "INPROG01",
                "readCollection": "READ0001"
            ]
        ))

        let isConfigured = await dataSource.isConfigured()
        #expect(isConfigured)
    }

    @Test("configure throws for invalid data source type")
    func configureThrowsForInvalidType() async throws {
        let dataSource = ZoteroDataSource()

        await #expect(throws: DataSourceError.self) {
            try await dataSource.configure(settings: DataSourceSettings(
                dataSourceType: .typeQuicker,
                credentials: ["apiKey": "key", "userID": "123"]
            ))
        }
    }

    @Test("configure throws for missing API key")
    func configureThrowsForMissingApiKey() async throws {
        let dataSource = ZoteroDataSource()

        await #expect(throws: DataSourceError.self) {
            try await dataSource.configure(settings: DataSourceSettings(
                dataSourceType: .zotero,
                credentials: ["userID": "12345"]
            ))
        }
    }

    @Test("configure throws for missing user ID")
    func configureThrowsForMissingUserId() async throws {
        let dataSource = ZoteroDataSource()

        await #expect(throws: DataSourceError.self) {
            try await dataSource.configure(settings: DataSourceSettings(
                dataSourceType: .zotero,
                credentials: ["apiKey": "test_key"]
            ))
        }
    }

    @Test("configure throws for empty API key")
    func configureThrowsForEmptyApiKey() async throws {
        let dataSource = ZoteroDataSource()

        await #expect(throws: DataSourceError.self) {
            try await dataSource.configure(settings: DataSourceSettings(
                dataSourceType: .zotero,
                credentials: ["apiKey": "", "userID": "12345"]
            ))
        }
    }

    @Test("configure throws for empty user ID")
    func configureThrowsForEmptyUserId() async throws {
        let dataSource = ZoteroDataSource()

        await #expect(throws: DataSourceError.self) {
            try await dataSource.configure(settings: DataSourceSettings(
                dataSourceType: .zotero,
                credentials: ["apiKey": "test_key", "userID": ""]
            ))
        }
    }

    @Test("clearConfiguration resets state")
    func clearConfigurationResetsState() async throws {
        let dataSource = ZoteroDataSource()

        try await dataSource.configure(settings: DataSourceSettings(
            dataSourceType: .zotero,
            credentials: ["apiKey": "test_key", "userID": "12345"]
        ))

        try await dataSource.clearConfiguration()

        let isConfigured = await dataSource.isConfigured()
        #expect(!isConfigured)
    }

    // MARK: - Metric Value Tests (ZoteroDailyStats)

    @Test("metricValue extracts annotations count correctly")
    func metricValueExtractsAnnotations() async {
        let dataSource = ZoteroDataSource()
        let stats = ZoteroDailyStats(
            date: Date(),
            annotationCount: 15,
            noteCount: 5,
            readingProgressScore: 2.5
        )

        let value = dataSource.metricValue(for: "annotations", from: stats)
        #expect(value == 15.0)
    }

    @Test("metricValue extracts notes count correctly")
    func metricValueExtractsNotes() async {
        let dataSource = ZoteroDataSource()
        let stats = ZoteroDailyStats(
            date: Date(),
            annotationCount: 15,
            noteCount: 5,
            readingProgressScore: 2.5
        )

        let value = dataSource.metricValue(for: "notes", from: stats)
        #expect(value == 5.0)
    }

    // MARK: - Metric Value Tests (ZoteroReadingStatus)

    @Test("metricValue extracts toRead count correctly")
    func metricValueExtractsToRead() async {
        let dataSource = ZoteroDataSource()
        let status = ZoteroReadingStatus(
            date: Date(),
            toReadCount: 20,
            inProgressCount: 5,
            readCount: 30
        )

        let value = dataSource.metricValue(for: "toRead", from: status)
        #expect(value == 20.0)
    }

    @Test("metricValue extracts inProgress count correctly")
    func metricValueExtractsInProgress() async {
        let dataSource = ZoteroDataSource()
        let status = ZoteroReadingStatus(
            date: Date(),
            toReadCount: 20,
            inProgressCount: 5,
            readCount: 30
        )

        let value = dataSource.metricValue(for: "inProgress", from: status)
        #expect(value == 5.0)
    }

    @Test("metricValue extracts read count correctly")
    func metricValueExtractsRead() async {
        let dataSource = ZoteroDataSource()
        let status = ZoteroReadingStatus(
            date: Date(),
            toReadCount: 20,
            inProgressCount: 5,
            readCount: 30
        )

        let value = dataSource.metricValue(for: "read", from: status)
        #expect(value == 30.0)
    }

    @Test("metricValue returns nil for unknown key")
    func metricValueReturnsNilForUnknownKey() async {
        let dataSource = ZoteroDataSource()
        let stats = ZoteroDailyStats(
            date: Date(),
            annotationCount: 15,
            noteCount: 5
        )

        let value = dataSource.metricValue(for: "unknown", from: stats)
        #expect(value == nil)
    }

    @Test("metricValue returns nil for wrong type")
    func metricValueReturnsNilForWrongType() async {
        let dataSource = ZoteroDataSource()

        let value = dataSource.metricValue(for: "annotations", from: "not a stats object")
        #expect(value == nil)
    }

    // MARK: - Available Metrics Tests

    @Test("availableMetrics returns expected metrics")
    func availableMetricsReturnsExpectedMetrics() async {
        let dataSource = ZoteroDataSource()
        let metrics = dataSource.availableMetrics

        #expect(metrics.count == 5)
        #expect(metrics.contains { $0.key == "annotations" })
        #expect(metrics.contains { $0.key == "notes" })
        #expect(metrics.contains { $0.key == "toRead" })
        #expect(metrics.contains { $0.key == "inProgress" })
        #expect(metrics.contains { $0.key == "read" })
    }

    // MARK: - ZoteroReadingStatus Computed Properties Tests

    @Test("ZoteroReadingStatus totalItems sums all counts")
    func readingStatusTotalItems() {
        let status = ZoteroReadingStatus(
            date: Date(),
            toReadCount: 10,
            inProgressCount: 5,
            readCount: 15
        )

        #expect(status.totalItems == 30)
    }

    @Test("ZoteroReadingStatus completionPercentage calculates correctly")
    func readingStatusCompletionPercentage() {
        let status = ZoteroReadingStatus(
            date: Date(),
            toReadCount: 20,
            inProgressCount: 30,
            readCount: 50
        )

        #expect(status.completionPercentage == 50.0) // 50/100 * 100 = 50%
    }

    @Test("ZoteroReadingStatus completionPercentage handles zero items")
    func readingStatusCompletionPercentageZeroItems() {
        let status = ZoteroReadingStatus(
            date: Date(),
            toReadCount: 0,
            inProgressCount: 0,
            readCount: 0
        )

        #expect(status.completionPercentage == 0.0)
    }

    @Test("ZoteroReadingStatus progressPercentage calculates correctly")
    func readingStatusProgressPercentage() {
        let status = ZoteroReadingStatus(
            date: Date(),
            toReadCount: 20,
            inProgressCount: 30,
            readCount: 50
        )

        #expect(status.progressPercentage == 80.0) // (30+50)/100 * 100 = 80%
    }

    // MARK: - ZoteroDailyStats Computed Properties Tests

    @Test("ZoteroDailyStats totalActivity includes reading progress")
    func dailyStatsTotalActivity() {
        let stats = ZoteroDailyStats(
            date: Date(),
            annotationCount: 5,
            noteCount: 3,
            readingProgressScore: 1.5
        )

        #expect(stats.totalActivity == 9) // 5 + 3 + 1 (reading progress > 0)
    }

    @Test("ZoteroDailyStats totalActivity without reading progress")
    func dailyStatsTotalActivityNoProgress() {
        let stats = ZoteroDailyStats(
            date: Date(),
            annotationCount: 5,
            noteCount: 3,
            readingProgressScore: 0
        )

        #expect(stats.totalActivity == 8) // 5 + 3 + 0
    }

    @Test("ZoteroDailyStats weightedPoints calculates correctly")
    func dailyStatsWeightedPoints() {
        let stats = ZoteroDailyStats(
            date: Date(),
            annotationCount: 20, // capped at 10 -> 1.0
            noteCount: 10,        // capped at 5 -> 1.0
            readingProgressScore: 2.5
        )

        // 0.1 * 10 + 0.2 * 5 + 2.5 = 1.0 + 1.0 + 2.5 = 4.5
        #expect(stats.weightedPoints == 4.5)
    }

    // MARK: - Cache Key Tests

    @Test("ZoteroDailyStats generates correct cache key")
    func zoteroDailyStatsCacheKey() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2026-01-15")!

        let stats = ZoteroDailyStats(
            date: date,
            annotationCount: 10,
            noteCount: 5
        )

        #expect(stats.cacheKey == "zotero:dailyStats:2026-01-15")
    }

    @Test("ZoteroReadingStatus generates correct cache key")
    func zoteroReadingStatusCacheKey() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2026-01-15")!

        let status = ZoteroReadingStatus(
            date: date,
            toReadCount: 10,
            inProgressCount: 5,
            readCount: 15
        )

        #expect(status.cacheKey == "zotero:readingStatus:2026-01-15")
    }
}
