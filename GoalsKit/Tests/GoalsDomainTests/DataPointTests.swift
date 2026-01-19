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
            source: .typeQuicker,
            note: "Test note"
        )

        #expect(dataPoint.goalId == goalId)
        #expect(dataPoint.value == 100.5)
        #expect(dataPoint.timestamp == timestamp)
        #expect(dataPoint.source == .typeQuicker)
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
        // Gray: 0-399
        let grayRating = AtCoderCurrentStats(
            date: Date(),
            rating: 350,
            highestRating: 350,
            contestsParticipated: 5,
            problemsSolved: 20
        )
        #expect(grayRating.rankColor == .gray)

        // Green: 800-1199
        let greenRating = AtCoderCurrentStats(
            date: Date(),
            rating: 1000,
            highestRating: 1000,
            contestsParticipated: 20,
            problemsSolved: 100
        )
        #expect(greenRating.rankColor == .green)

        // Blue: 1600-1999
        let blueRating = AtCoderCurrentStats(
            date: Date(),
            rating: 1700,
            highestRating: 1700,
            contestsParticipated: 50,
            problemsSolved: 300
        )
        #expect(blueRating.rankColor == .blue)

        // Red: 2800+
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
        // Cyan: 1200-1599
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

    @Test("AtCoderRankColor from difficulty")
    func atCoderRankColorFromDifficulty() {
        #expect(AtCoderRankColor.from(difficulty: nil) == .gray)
        #expect(AtCoderRankColor.from(difficulty: 200) == .gray)
        #expect(AtCoderRankColor.from(difficulty: 500) == .brown)
        #expect(AtCoderRankColor.from(difficulty: 900) == .green)
        #expect(AtCoderRankColor.from(difficulty: 1300) == .cyan)
        #expect(AtCoderRankColor.from(difficulty: 1800) == .blue)
        #expect(AtCoderRankColor.from(difficulty: 2200) == .yellow)
        #expect(AtCoderRankColor.from(difficulty: 2600) == .orange)
        #expect(AtCoderRankColor.from(difficulty: 3000) == .red)
    }

    @Test("AtCoderRankColor has correct rating ranges")
    func atCoderRankColorRatingRanges() {
        #expect(AtCoderRankColor.gray.ratingRange == "0-399")
        #expect(AtCoderRankColor.brown.ratingRange == "400-799")
        #expect(AtCoderRankColor.green.ratingRange == "800-1199")
        #expect(AtCoderRankColor.cyan.ratingRange == "1200-1599")
        #expect(AtCoderRankColor.blue.ratingRange == "1600-1999")
        #expect(AtCoderRankColor.yellow.ratingRange == "2000-2399")
        #expect(AtCoderRankColor.orange.ratingRange == "2400-2799")
        #expect(AtCoderRankColor.red.ratingRange == "2800+")
    }
}
