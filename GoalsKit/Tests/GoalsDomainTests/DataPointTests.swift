import Testing
import Foundation
@testable import GoalsDomain

@Suite("DataPoint Entity Tests")
struct DataPointTests {

    @Test("DataPoint initializes with correct values")
    func dataPointInitialization() {
        let goalId = UUID()
        let timestamp = Date()

        let dataPoint = DataPoint(
            goalId: goalId,
            value: 100.5,
            timestamp: timestamp,
            source: .manual,
            note: "Test note"
        )

        #expect(dataPoint.goalId == goalId)
        #expect(dataPoint.value == 100.5)
        #expect(dataPoint.timestamp == timestamp)
        #expect(dataPoint.source == .manual)
        #expect(dataPoint.note == "Test note")
    }

    @Test("DataPoint with metadata stores correctly")
    func dataPointWithMetadata() {
        let dataPoint = DataPoint(
            goalId: UUID(),
            value: 85.0,
            source: .typeQuicker,
            metadata: [
                "wpm": "85",
                "accuracy": "98.5"
            ]
        )

        #expect(dataPoint.metadata?["wpm"] == "85")
        #expect(dataPoint.metadata?["accuracy"] == "98.5")
    }

    @Test("TypeQuickerStats calculates correctly")
    func typeQuickerStats() {
        let stats = TypeQuickerStats(
            date: Date(),
            wordsPerMinute: 75.5,
            accuracy: 98.2,
            practiceTimeMinutes: 30,
            sessionsCount: 3
        )

        #expect(stats.wordsPerMinute == 75.5)
        #expect(stats.accuracy == 98.2)
        #expect(stats.practiceTimeMinutes == 30)
        #expect(stats.sessionsCount == 3)
    }

    @Test("AtCoderCurrentStats determines rank color correctly")
    func atCoderRankColor() {
        let grayRating = AtCoderCurrentStats(
            date: Date(),
            rating: 350,
            highestRating: 350,
            contestsParticipated: 5,
            problemsSolved: 20
        )
        #expect(grayRating.rankColor == .gray)

        let greenRating = AtCoderCurrentStats(
            date: Date(),
            rating: 1000,
            highestRating: 1000,
            contestsParticipated: 20,
            problemsSolved: 100
        )
        #expect(greenRating.rankColor == .green)

        let blueRating = AtCoderCurrentStats(
            date: Date(),
            rating: 1700,
            highestRating: 1700,
            contestsParticipated: 50,
            problemsSolved: 300
        )
        #expect(blueRating.rankColor == .blue)

        let redRating = AtCoderCurrentStats(
            date: Date(),
            rating: 2900,
            highestRating: 2900,
            contestsParticipated: 100,
            problemsSolved: 1000
        )
        #expect(redRating.rankColor == .red)
    }

    @Test("AtCoderContestResult has valid cache key")
    func atCoderContestResultCacheKey() {
        let contestResult = AtCoderContestResult(
            date: Date(),
            rating: 1500,
            highestRating: 1500,
            contestsParticipated: 10,
            problemsSolved: 50,
            contestScreenName: "abc123"
        )
        #expect(contestResult.cacheKey == "ac:contest:abc123")
        #expect(contestResult.rankColor == .cyan)
    }

    @Test("FinanceStats calculates net income and savings rate")
    func financeStatsCalculations() {
        let stats = FinanceStats(
            date: Date(),
            income: 5000,
            expenses: 3500,
            savings: 1000
        )

        #expect(stats.netIncome == 1500)
        #expect(stats.savingsRate == 0.2)
    }

    @Test("FinanceStats handles zero income gracefully")
    func financeStatsZeroIncome() {
        let stats = FinanceStats(
            date: Date(),
            income: 0,
            expenses: 100,
            savings: 0
        )

        #expect(stats.savingsRate == 0)
    }
}
