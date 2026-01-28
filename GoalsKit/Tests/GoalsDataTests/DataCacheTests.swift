import Testing
import Foundation
import SwiftData
@testable import GoalsData
@testable import GoalsDomain

@Suite("CacheableModel Tests")
struct CacheableModelTests {

    // Helper to create in-memory model container for cache testing
    private func makeCacheContainer() throws -> ModelContainer {
        let schema = Schema([
            TypeQuickerStatsModel.self,
            AnkiDailyStatsModel.self,
            ZoteroDailyStatsModel.self,
            ZoteroReadingStatusModel.self,
            AtCoderContestResultModel.self,
            AtCoderSubmissionModel.self,
            AtCoderDailyEffortModel.self,
            SleepDailySummaryModel.self,
            TaskDailySummaryModel.self,
            NutritionDailySummaryModel.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - Store Tests

    @Test("store inserts new record with cache key")
    func storeInsertsNewRecord() throws {
        let container = try makeCacheContainer()

        let date = Date()
        let stats = TypeQuickerStats(
            date: date,
            wordsPerMinute: 85.0,
            accuracy: 97.5,
            practiceTimeMinutes: 30,
            sessionsCount: 5
        )

        try TypeQuickerStatsModel.store([stats], in: container)

        let fetched = try TypeQuickerStatsModel.fetch(in: container)
        #expect(fetched.count == 1)
        #expect(fetched.first?.wordsPerMinute == 85.0)
        #expect(fetched.first?.accuracy == 97.5)
    }

    @Test("store updates existing record if fetchedAt is newer")
    func storeUpdatesIfNewer() throws {
        let container = try makeCacheContainer()

        let date = Date()
        let stats1 = TypeQuickerStats(
            date: date,
            wordsPerMinute: 80.0,
            accuracy: 95.0,
            practiceTimeMinutes: 20,
            sessionsCount: 3
        )

        try TypeQuickerStatsModel.store([stats1], in: container)

        // Store with same cache key but different values
        let stats2 = TypeQuickerStats(
            date: date,
            wordsPerMinute: 90.0,
            accuracy: 98.0,
            practiceTimeMinutes: 40,
            sessionsCount: 8
        )

        try TypeQuickerStatsModel.store([stats2], in: container)

        let fetched = try TypeQuickerStatsModel.fetch(in: container)
        #expect(fetched.count == 1) // Should still be 1, not 2
        #expect(fetched.first?.wordsPerMinute == 90.0) // Updated value
    }

    @Test("store multiple records")
    func storeMultipleRecords() throws {
        let container = try makeCacheContainer()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let stats = [
            TypeQuickerStats(
                date: today,
                wordsPerMinute: 85.0,
                accuracy: 97.0,
                practiceTimeMinutes: 30,
                sessionsCount: 5
            ),
            TypeQuickerStats(
                date: yesterday,
                wordsPerMinute: 80.0,
                accuracy: 95.0,
                practiceTimeMinutes: 25,
                sessionsCount: 4
            )
        ]

        try TypeQuickerStatsModel.store(stats, in: container)

        let fetched = try TypeQuickerStatsModel.fetch(in: container)
        #expect(fetched.count == 2)
    }

    // MARK: - Fetch Tests

    @Test("fetch filters by date range correctly")
    func fetchFiltersByDateRange() throws {
        let container = try makeCacheContainer()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let stats = [
            TypeQuickerStats(date: today, wordsPerMinute: 90.0, accuracy: 98.0, practiceTimeMinutes: 30, sessionsCount: 5),
            TypeQuickerStats(date: yesterday, wordsPerMinute: 85.0, accuracy: 97.0, practiceTimeMinutes: 25, sessionsCount: 4),
            TypeQuickerStats(date: twoDaysAgo, wordsPerMinute: 80.0, accuracy: 95.0, practiceTimeMinutes: 20, sessionsCount: 3)
        ]

        try TypeQuickerStatsModel.store(stats, in: container)

        // Fetch only yesterday and today
        let filtered = try TypeQuickerStatsModel.fetch(from: yesterday, to: today, in: container)
        #expect(filtered.count == 2)
    }

    @Test("fetch by cacheKey returns specific record")
    func fetchByCacheKeyReturnsRecord() throws {
        let container = try makeCacheContainer()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let todayStats = TypeQuickerStats(date: today, wordsPerMinute: 90.0, accuracy: 98.0, practiceTimeMinutes: 30, sessionsCount: 5)
        let yesterdayStats = TypeQuickerStats(date: yesterday, wordsPerMinute: 80.0, accuracy: 95.0, practiceTimeMinutes: 20, sessionsCount: 3)

        try TypeQuickerStatsModel.store([todayStats, yesterdayStats], in: container)

        let fetched = try TypeQuickerStatsModel.fetchByCacheKey(todayStats.cacheKey, in: container)
        #expect(fetched != nil)
        #expect(fetched?.wordsPerMinute == 90.0)
    }

    // MARK: - Query Tests

    @Test("latestRecordDate returns most recent date")
    func latestRecordDateReturnsMostRecent() throws {
        let container = try makeCacheContainer()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let stats = [
            TypeQuickerStats(date: today, wordsPerMinute: 90.0, accuracy: 98.0, practiceTimeMinutes: 30, sessionsCount: 5),
            TypeQuickerStats(date: yesterday, wordsPerMinute: 80.0, accuracy: 95.0, practiceTimeMinutes: 20, sessionsCount: 3)
        ]

        try TypeQuickerStatsModel.store(stats, in: container)

        let latestDate = try TypeQuickerStatsModel.latestRecordDate(in: container)
        #expect(latestDate == today)
    }

    @Test("hasData returns true when records exist")
    func hasDataReturnsTrue() throws {
        let container = try makeCacheContainer()

        let stats = TypeQuickerStats(date: Date(), wordsPerMinute: 85.0, accuracy: 97.0, practiceTimeMinutes: 30, sessionsCount: 5)
        try TypeQuickerStatsModel.store([stats], in: container)

        let hasData = try TypeQuickerStatsModel.hasData(in: container)
        #expect(hasData)
    }

    @Test("hasData returns false when empty")
    func hasDataReturnsFalse() throws {
        let container = try makeCacheContainer()

        let hasData = try TypeQuickerStatsModel.hasData(in: container)
        #expect(!hasData)
    }

    @Test("count returns correct number of records")
    func countReturnsCorrectNumber() throws {
        let container = try makeCacheContainer()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let stats = [
            TypeQuickerStats(date: today, wordsPerMinute: 90.0, accuracy: 98.0, practiceTimeMinutes: 30, sessionsCount: 5),
            TypeQuickerStats(date: yesterday, wordsPerMinute: 85.0, accuracy: 97.0, practiceTimeMinutes: 25, sessionsCount: 4),
            TypeQuickerStats(date: twoDaysAgo, wordsPerMinute: 80.0, accuracy: 95.0, practiceTimeMinutes: 20, sessionsCount: 3)
        ]

        try TypeQuickerStatsModel.store(stats, in: container)

        let count = try TypeQuickerStatsModel.count(in: container)
        #expect(count == 3)
    }

    // MARK: - Delete Tests

    @Test("deleteAll removes all records of type")
    func deleteAllRemovesRecords() throws {
        let container = try makeCacheContainer()

        let stats = [
            TypeQuickerStats(date: Date(), wordsPerMinute: 90.0, accuracy: 98.0, practiceTimeMinutes: 30, sessionsCount: 5),
            TypeQuickerStats(date: Date().addingTimeInterval(-86400), wordsPerMinute: 85.0, accuracy: 97.0, practiceTimeMinutes: 25, sessionsCount: 4)
        ]

        try TypeQuickerStatsModel.store(stats, in: container)

        var count = try TypeQuickerStatsModel.count(in: container)
        #expect(count == 2)

        try TypeQuickerStatsModel.deleteAll(in: container)

        count = try TypeQuickerStatsModel.count(in: container)
        #expect(count == 0)
    }

    @Test("deleteOlderThan removes records before date")
    func deleteOlderThanRemovesRecords() throws {
        let container = try makeCacheContainer()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: today)!

        let stats = [
            TypeQuickerStats(date: today, wordsPerMinute: 90.0, accuracy: 98.0, practiceTimeMinutes: 30, sessionsCount: 5),
            TypeQuickerStats(date: threeDaysAgo, wordsPerMinute: 85.0, accuracy: 97.0, practiceTimeMinutes: 25, sessionsCount: 4),
            TypeQuickerStats(date: fiveDaysAgo, wordsPerMinute: 80.0, accuracy: 95.0, practiceTimeMinutes: 20, sessionsCount: 3)
        ]

        try TypeQuickerStatsModel.store(stats, in: container)

        let countBefore = try TypeQuickerStatsModel.count(in: container)
        #expect(countBefore == 3)

        // Delete records older than 4 days ago
        let fourDaysAgo = calendar.date(byAdding: .day, value: -4, to: today)!
        try TypeQuickerStatsModel.deleteOlderThan(fourDaysAgo, in: container)

        let countAfter = try TypeQuickerStatsModel.count(in: container)
        #expect(countAfter == 2) // today and threeDaysAgo remain
    }

    // MARK: - Multiple Type Tests

    @Test("cache supports multiple record types independently")
    func cacheSupportsMultipleTypes() throws {
        let container = try makeCacheContainer()

        let typeQuickerStats = TypeQuickerStats(
            date: Date(),
            wordsPerMinute: 85.0,
            accuracy: 97.0,
            practiceTimeMinutes: 30,
            sessionsCount: 5
        )

        let ankiStats = AnkiDailyStats(
            date: Date(),
            reviewCount: 50,
            studyTimeSeconds: 1800,
            correctCount: 45,
            newCardsCount: 10
        )

        try TypeQuickerStatsModel.store([typeQuickerStats], in: container)
        try AnkiDailyStatsModel.store([ankiStats], in: container)

        let typeQuickerCount = try TypeQuickerStatsModel.count(in: container)
        let ankiCount = try AnkiDailyStatsModel.count(in: container)

        #expect(typeQuickerCount == 1)
        #expect(ankiCount == 1)

        // Delete one type shouldn't affect the other
        try TypeQuickerStatsModel.deleteAll(in: container)

        let typeQuickerCountAfter = try TypeQuickerStatsModel.count(in: container)
        let ankiCountAfter = try AnkiDailyStatsModel.count(in: container)

        #expect(typeQuickerCountAfter == 0)
        #expect(ankiCountAfter == 1)
    }

    // MARK: - Earliest Record Date Tests

    @Test("earliestRecordDate returns oldest date")
    func earliestRecordDateReturnsOldest() throws {
        let container = try makeCacheContainer()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let stats = [
            TypeQuickerStats(date: today, wordsPerMinute: 90.0, accuracy: 98.0, practiceTimeMinutes: 30, sessionsCount: 5),
            TypeQuickerStats(date: yesterday, wordsPerMinute: 85.0, accuracy: 97.0, practiceTimeMinutes: 25, sessionsCount: 4),
            TypeQuickerStats(date: twoDaysAgo, wordsPerMinute: 80.0, accuracy: 95.0, practiceTimeMinutes: 20, sessionsCount: 3)
        ]

        try TypeQuickerStatsModel.store(stats, in: container)

        let earliestDate = try TypeQuickerStatsModel.earliestRecordDate(in: container)
        #expect(earliestDate == twoDaysAgo)
    }

    @Test("earliestRecordDate returns nil when empty")
    func earliestRecordDateReturnsNilWhenEmpty() throws {
        let container = try makeCacheContainer()

        let earliestDate = try TypeQuickerStatsModel.earliestRecordDate(in: container)
        #expect(earliestDate == nil)
    }

    // MARK: - AtCoder Model Tests

    @Test("AtCoderContestResultModel store and fetch")
    func atCoderContestResultModelStoreAndFetch() throws {
        let container = try makeCacheContainer()

        let result = AtCoderContestResult(
            date: Date(),
            rating: 1250,
            highestRating: 1300,
            contestsParticipated: 10,
            problemsSolved: 50,
            longestStreak: 5,
            contestScreenName: "abc123"
        )

        try AtCoderContestResultModel.store([result], in: container)

        let fetched = try AtCoderContestResultModel.fetch(in: container)
        #expect(fetched.count == 1)
        #expect(fetched.first?.contestScreenName == "abc123")
        #expect(fetched.first?.rating == 1250)
    }

    @Test("AtCoderDailyEffortModel store and fetch")
    func atCoderDailyEffortModelStoreAndFetch() throws {
        let container = try makeCacheContainer()

        let effort = AtCoderDailyEffort(
            date: Date(),
            submissionsByDifficulty: [.green: 5, .cyan: 3, .blue: 2]
        )

        try AtCoderDailyEffortModel.store([effort], in: container)

        let fetched = try AtCoderDailyEffortModel.fetch(in: container)
        #expect(fetched.count == 1)
        #expect(fetched.first?.totalSubmissions == 10)
    }

    // MARK: - Zotero Model Tests

    @Test("ZoteroDailyStatsModel store and fetch")
    func zoteroDailyStatsModelStoreAndFetch() throws {
        let container = try makeCacheContainer()

        let stats = ZoteroDailyStats(
            date: Date(),
            annotationCount: 10,
            noteCount: 5,
            readingProgressScore: 2.5
        )

        try ZoteroDailyStatsModel.store([stats], in: container)

        let fetched = try ZoteroDailyStatsModel.fetch(in: container)
        #expect(fetched.count == 1)
        #expect(fetched.first?.annotationCount == 10)
    }

    @Test("ZoteroReadingStatusModel store and fetch")
    func zoteroReadingStatusModelStoreAndFetch() throws {
        let container = try makeCacheContainer()

        let status = ZoteroReadingStatus(
            date: Date(),
            toReadCount: 10,
            inProgressCount: 5,
            readCount: 20
        )

        try ZoteroReadingStatusModel.store([status], in: container)

        let fetched = try ZoteroReadingStatusModel.fetch(in: container)
        #expect(fetched.count == 1)
        #expect(fetched.first?.toReadCount == 10)
    }

    // MARK: - Sleep Model Tests

    @Test("SleepDailySummaryModel store and fetch")
    func sleepDailySummaryModelStoreAndFetch() throws {
        let container = try makeCacheContainer()

        // Create a sleep session for testing
        let now = Date()
        let startDate = now.addingTimeInterval(-8 * 3600)  // 8 hours ago
        let session = SleepSession(
            startDate: startDate,
            endDate: now,
            stages: [
                SleepStage(type: .rem, startDate: startDate, endDate: startDate.addingTimeInterval(1.5 * 3600)),
                SleepStage(type: .deep, startDate: startDate.addingTimeInterval(1.5 * 3600), endDate: startDate.addingTimeInterval(2.5 * 3600)),
                SleepStage(type: .core, startDate: startDate.addingTimeInterval(2.5 * 3600), endDate: startDate.addingTimeInterval(6.5 * 3600)),
                SleepStage(type: .awake, startDate: startDate.addingTimeInterval(6.5 * 3600), endDate: now)
            ]
        )

        let summary = SleepDailySummary(
            date: Calendar.current.startOfDay(for: now),
            sessions: [session]
        )

        try SleepDailySummaryModel.store([summary], in: container)

        let fetched = try SleepDailySummaryModel.fetch(in: container)
        #expect(fetched.count == 1)
        #expect(fetched.first?.sessions.count == 1)
    }

    // MARK: - Anki Model Tests

    @Test("AnkiDailyStatsModel store and fetch")
    func ankiDailyStatsModelStoreAndFetch() throws {
        let container = try makeCacheContainer()

        let stats = AnkiDailyStats(
            date: Date(),
            reviewCount: 100,
            studyTimeSeconds: 3600,
            correctCount: 90,
            newCardsCount: 20
        )

        try AnkiDailyStatsModel.store([stats], in: container)

        let fetched = try AnkiDailyStatsModel.fetch(in: container)
        #expect(fetched.count == 1)
        #expect(fetched.first?.reviewCount == 100)
        #expect(fetched.first?.correctCount == 90)
    }
}
