import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for caching Zotero daily activity statistics
@Model
public final class ZoteroDailyStatsModel {
    /// Unique cache key for this record (e.g., "zotero:dailyStats:2025-01-15")
    @Attribute(.unique)
    public var cacheKey: String = ""

    /// Date for this stats record
    public var recordDate: Date = Date()

    /// When this record was fetched from the remote API
    public var fetchedAt: Date = Date()

    // MARK: - Stats Fields

    /// Number of annotations created
    public var annotationCount: Int = 0

    /// Number of notes created
    public var noteCount: Int = 0

    /// Reading progress delta (change in score from previous day)
    /// Score formula: toRead×0.25 + inProgress×0.5 + read×1.0
    public var readingProgressScore: Double = 0

    public init(
        cacheKey: String,
        recordDate: Date,
        fetchedAt: Date = Date(),
        annotationCount: Int,
        noteCount: Int,
        readingProgressScore: Double
    ) {
        self.cacheKey = cacheKey
        self.recordDate = recordDate
        self.fetchedAt = fetchedAt
        self.annotationCount = annotationCount
        self.noteCount = noteCount
        self.readingProgressScore = readingProgressScore
    }
}

// MARK: - CacheableModel Conformance

extension ZoteroDailyStatsModel: CacheableModel {
    public typealias DomainType = ZoteroDailyStats
}

// MARK: - Domain Conversion

public extension ZoteroDailyStatsModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> ZoteroDailyStats {
        ZoteroDailyStats(
            date: recordDate,
            annotationCount: annotationCount,
            noteCount: noteCount,
            readingProgressScore: readingProgressScore
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ record: ZoteroDailyStats, fetchedAt: Date = Date()) -> ZoteroDailyStatsModel {
        ZoteroDailyStatsModel(
            cacheKey: record.cacheKey,
            recordDate: record.recordDate,
            fetchedAt: fetchedAt,
            annotationCount: record.annotationCount,
            noteCount: record.noteCount,
            readingProgressScore: record.readingProgressScore
        )
    }

    /// Updates model from domain entity
    func update(from record: ZoteroDailyStats, fetchedAt: Date = Date()) {
        self.recordDate = record.recordDate
        self.fetchedAt = fetchedAt
        self.annotationCount = record.annotationCount
        self.noteCount = record.noteCount
        self.readingProgressScore = record.readingProgressScore
    }
}
