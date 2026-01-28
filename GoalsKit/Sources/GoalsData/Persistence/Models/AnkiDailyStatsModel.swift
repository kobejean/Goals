import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for caching Anki daily learning statistics
@Model
public final class AnkiDailyStatsModel {
    /// Unique cache key for this record (e.g., "anki:dailyStats:2025-01-15")
    @Attribute(.unique)
    public var cacheKey: String = ""

    /// Date for this stats record
    public var recordDate: Date = Date()

    /// When this record was fetched from the remote API
    public var fetchedAt: Date = Date()

    // MARK: - Stats Fields

    /// Number of reviews completed
    public var reviewCount: Int = 0

    /// Total study time in seconds
    public var studyTimeSeconds: Int = 0

    /// Number of correct reviews
    public var correctCount: Int = 0

    /// Number of new cards studied
    public var newCardsCount: Int = 0

    public init(
        cacheKey: String,
        recordDate: Date,
        fetchedAt: Date = Date(),
        reviewCount: Int,
        studyTimeSeconds: Int,
        correctCount: Int,
        newCardsCount: Int
    ) {
        self.cacheKey = cacheKey
        self.recordDate = recordDate
        self.fetchedAt = fetchedAt
        self.reviewCount = reviewCount
        self.studyTimeSeconds = studyTimeSeconds
        self.correctCount = correctCount
        self.newCardsCount = newCardsCount
    }
}

// MARK: - CacheableModel Conformance

extension AnkiDailyStatsModel: CacheableModel {
    public typealias DomainType = AnkiDailyStats
}

// MARK: - Domain Conversion

public extension AnkiDailyStatsModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> AnkiDailyStats {
        AnkiDailyStats(
            date: recordDate,
            reviewCount: reviewCount,
            studyTimeSeconds: studyTimeSeconds,
            correctCount: correctCount,
            newCardsCount: newCardsCount
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ record: AnkiDailyStats, fetchedAt: Date = Date()) -> AnkiDailyStatsModel {
        AnkiDailyStatsModel(
            cacheKey: record.cacheKey,
            recordDate: record.recordDate,
            fetchedAt: fetchedAt,
            reviewCount: record.reviewCount,
            studyTimeSeconds: record.studyTimeSeconds,
            correctCount: record.correctCount,
            newCardsCount: record.newCardsCount
        )
    }

    /// Updates model from domain entity
    func update(from record: AnkiDailyStats, fetchedAt: Date = Date()) {
        self.recordDate = record.recordDate
        self.fetchedAt = fetchedAt
        self.reviewCount = record.reviewCount
        self.studyTimeSeconds = record.studyTimeSeconds
        self.correctCount = record.correctCount
        self.newCardsCount = record.newCardsCount
    }
}
