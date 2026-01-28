import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for caching TypeQuicker daily statistics
@Model
public final class TypeQuickerStatsModel {
    /// Unique cache key for this record (e.g., "tq:stats:2025-01-15")
    @Attribute(.unique)
    public var cacheKey: String = ""

    /// Date for this stats record
    public var recordDate: Date = Date()

    /// When this record was fetched from the remote API
    public var fetchedAt: Date = Date()

    // MARK: - Stats Fields

    /// Words per minute
    public var wordsPerMinute: Double = 0

    /// Accuracy percentage (0-100)
    public var accuracy: Double = 0

    /// Total practice time in minutes
    public var practiceTimeMinutes: Int = 0

    /// Number of sessions
    public var sessionsCount: Int = 0

    /// JSON-encoded array of TypeQuickerModeStats for per-mode breakdown
    @Attribute(.externalStorage)
    public var byModeData: Data?

    public init(
        cacheKey: String,
        recordDate: Date,
        fetchedAt: Date = Date(),
        wordsPerMinute: Double,
        accuracy: Double,
        practiceTimeMinutes: Int,
        sessionsCount: Int,
        byModeData: Data? = nil
    ) {
        self.cacheKey = cacheKey
        self.recordDate = recordDate
        self.fetchedAt = fetchedAt
        self.wordsPerMinute = wordsPerMinute
        self.accuracy = accuracy
        self.practiceTimeMinutes = practiceTimeMinutes
        self.sessionsCount = sessionsCount
        self.byModeData = byModeData
    }
}

// MARK: - CacheableModel Conformance

extension TypeQuickerStatsModel: CacheableModel {
    public typealias DomainType = TypeQuickerStats
}

// MARK: - Domain Conversion

public extension TypeQuickerStatsModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> TypeQuickerStats {
        var byMode: [TypeQuickerModeStats]?
        if let data = byModeData {
            let decoder = JSONDecoder()
            byMode = try? decoder.decode([TypeQuickerModeStats].self, from: data)
        }

        return TypeQuickerStats(
            date: recordDate,
            wordsPerMinute: wordsPerMinute,
            accuracy: accuracy,
            practiceTimeMinutes: practiceTimeMinutes,
            sessionsCount: sessionsCount,
            byMode: byMode
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ record: TypeQuickerStats, fetchedAt: Date = Date()) -> TypeQuickerStatsModel {
        var byModeData: Data?
        if let byMode = record.byMode {
            let encoder = JSONEncoder()
            byModeData = try? encoder.encode(byMode)
        }

        return TypeQuickerStatsModel(
            cacheKey: record.cacheKey,
            recordDate: record.recordDate,
            fetchedAt: fetchedAt,
            wordsPerMinute: record.wordsPerMinute,
            accuracy: record.accuracy,
            practiceTimeMinutes: record.practiceTimeMinutes,
            sessionsCount: record.sessionsCount,
            byModeData: byModeData
        )
    }

    /// Updates model from domain entity
    func update(from record: TypeQuickerStats, fetchedAt: Date = Date()) {
        self.recordDate = record.recordDate
        self.fetchedAt = fetchedAt
        self.wordsPerMinute = record.wordsPerMinute
        self.accuracy = record.accuracy
        self.practiceTimeMinutes = record.practiceTimeMinutes
        self.sessionsCount = record.sessionsCount

        if let byMode = record.byMode {
            let encoder = JSONEncoder()
            self.byModeData = try? encoder.encode(byMode)
        } else {
            self.byModeData = nil
        }
    }
}
