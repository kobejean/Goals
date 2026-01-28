import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for caching AtCoder contest results
@Model
public final class AtCoderContestResultModel {
    /// Unique cache key for this record (e.g., "ac:contest:abc123")
    @Attribute(.unique)
    public var cacheKey: String = ""

    /// Date of the contest
    public var recordDate: Date = Date()

    /// When this record was fetched from the remote API
    public var fetchedAt: Date = Date()

    // MARK: - Contest Result Fields

    /// Contest screen name (unique identifier)
    public var contestScreenName: String = ""

    /// Rating after this contest
    public var rating: Int = 0

    /// Highest rating achieved (as of this contest)
    public var highestRating: Int = 0

    /// Total contests participated (as of this contest)
    public var contestsParticipated: Int = 0

    /// Total problems solved (as of this contest)
    public var problemsSolved: Int = 0

    /// Longest submission streak (optional)
    public var longestStreak: Int?

    public init(
        cacheKey: String,
        recordDate: Date,
        fetchedAt: Date = Date(),
        contestScreenName: String,
        rating: Int,
        highestRating: Int,
        contestsParticipated: Int,
        problemsSolved: Int,
        longestStreak: Int? = nil
    ) {
        self.cacheKey = cacheKey
        self.recordDate = recordDate
        self.fetchedAt = fetchedAt
        self.contestScreenName = contestScreenName
        self.rating = rating
        self.highestRating = highestRating
        self.contestsParticipated = contestsParticipated
        self.problemsSolved = problemsSolved
        self.longestStreak = longestStreak
    }
}

// MARK: - Domain Conversion

public extension AtCoderContestResultModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> AtCoderContestResult {
        AtCoderContestResult(
            date: recordDate,
            rating: rating,
            highestRating: highestRating,
            contestsParticipated: contestsParticipated,
            problemsSolved: problemsSolved,
            longestStreak: longestStreak,
            contestScreenName: contestScreenName
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ record: AtCoderContestResult, fetchedAt: Date = Date()) -> AtCoderContestResultModel {
        AtCoderContestResultModel(
            cacheKey: record.cacheKey,
            recordDate: record.recordDate,
            fetchedAt: fetchedAt,
            contestScreenName: record.contestScreenName,
            rating: record.rating,
            highestRating: record.highestRating,
            contestsParticipated: record.contestsParticipated,
            problemsSolved: record.problemsSolved,
            longestStreak: record.longestStreak
        )
    }

    /// Updates model from domain entity
    func update(from record: AtCoderContestResult, fetchedAt: Date = Date()) {
        self.recordDate = record.recordDate
        self.fetchedAt = fetchedAt
        self.contestScreenName = record.contestScreenName
        self.rating = record.rating
        self.highestRating = record.highestRating
        self.contestsParticipated = record.contestsParticipated
        self.problemsSolved = record.problemsSolved
        self.longestStreak = record.longestStreak
    }
}
