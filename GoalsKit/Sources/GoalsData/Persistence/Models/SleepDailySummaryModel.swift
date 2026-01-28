import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for caching daily sleep summaries
@Model
public final class SleepDailySummaryModel {
    /// Unique cache key for this record (e.g., "hk:sleep:2025-01-15")
    @Attribute(.unique)
    public var cacheKey: String = ""

    /// Wake date (the date this sleep is attributed to)
    public var recordDate: Date = Date()

    /// When this record was fetched from HealthKit
    public var fetchedAt: Date = Date()

    // MARK: - Sleep Data

    /// JSON-encoded array of SleepSession
    /// Contains detailed session data including start/end times and sleep stages
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

// MARK: - Domain Conversion

public extension SleepDailySummaryModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> SleepDailySummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sessions = (try? decoder.decode([SleepSession].self, from: sessionsData)) ?? []

        return SleepDailySummary(
            date: recordDate,
            sessions: sessions
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ record: SleepDailySummary, fetchedAt: Date = Date()) -> SleepDailySummaryModel {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(record.sessions)) ?? Data()

        return SleepDailySummaryModel(
            cacheKey: record.cacheKey,
            recordDate: record.recordDate,
            fetchedAt: fetchedAt,
            sessionsData: data
        )
    }

    /// Updates model from domain entity
    func update(from record: SleepDailySummary, fetchedAt: Date = Date()) {
        self.recordDate = record.recordDate
        self.fetchedAt = fetchedAt

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.sessionsData = (try? encoder.encode(record.sessions)) ?? Data()
    }
}
