import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for caching daily task summaries
@Model
public final class TaskDailySummaryModel {
    /// Unique cache key for this record (e.g., "tasks:daily:2025-01-15")
    @Attribute(.unique)
    public var cacheKey: String = ""

    /// Date for this summary
    public var recordDate: Date = Date()

    /// When this record was written to cache
    public var fetchedAt: Date = Date()

    // MARK: - Task Data

    /// JSON-encoded array of CachedTaskSession
    /// Contains session data with embedded task info for widget display
    @Attribute(.externalStorage)
    public var sessionsData: Data = Data()

    public init(
        cacheKey: String,
        recordDate: Date,
        fetchedAt: Date = Date(),
        sessionsData: Data
    ) {
        self.cacheKey = cacheKey
        self.recordDate = recordDate
        self.fetchedAt = fetchedAt
        self.sessionsData = sessionsData
    }
}

// MARK: - CacheableModel Conformance

extension TaskDailySummaryModel: CacheableModel {
    public typealias DomainType = TaskDailySummary
}

// MARK: - Domain Conversion

public extension TaskDailySummaryModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> TaskDailySummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sessions = (try? decoder.decode([CachedTaskSession].self, from: sessionsData)) ?? []

        return TaskDailySummary(
            date: recordDate,
            sessions: sessions
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ record: TaskDailySummary, fetchedAt: Date = Date()) -> TaskDailySummaryModel {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(record.sessions)) ?? Data()

        return TaskDailySummaryModel(
            cacheKey: record.cacheKey,
            recordDate: record.recordDate,
            fetchedAt: fetchedAt,
            sessionsData: data
        )
    }

    /// Updates model from domain entity
    func update(from record: TaskDailySummary, fetchedAt: Date = Date()) {
        self.recordDate = record.recordDate
        self.fetchedAt = fetchedAt

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.sessionsData = (try? encoder.encode(record.sessions)) ?? Data()
    }
}
