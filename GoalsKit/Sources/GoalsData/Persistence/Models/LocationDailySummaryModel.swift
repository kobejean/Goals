import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for caching daily location summaries
@Model
public final class LocationDailySummaryModel {
    /// Unique cache key for this record (e.g., "locations:daily:2025-01-15")
    @Attribute(.unique)
    public var cacheKey: String = ""

    /// Date for this summary
    public var recordDate: Date = Date()

    /// When this record was written to cache
    public var fetchedAt: Date = Date()

    // MARK: - Location Data

    /// JSON-encoded array of CachedLocationSession
    /// Contains session data with embedded location info for widget display
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

extension LocationDailySummaryModel: CacheableModel {
    public typealias DomainType = LocationDailySummary
}

// MARK: - Domain Conversion

public extension LocationDailySummaryModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> LocationDailySummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sessions = (try? decoder.decode([CachedLocationSession].self, from: sessionsData)) ?? []

        return LocationDailySummary(
            date: recordDate,
            sessions: sessions
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ record: LocationDailySummary, fetchedAt: Date = Date()) -> LocationDailySummaryModel {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(record.sessions)) ?? Data()

        return LocationDailySummaryModel(
            cacheKey: record.cacheKey,
            recordDate: record.recordDate,
            fetchedAt: fetchedAt,
            sessionsData: data
        )
    }

    /// Updates model from domain entity
    func update(from record: LocationDailySummary, fetchedAt: Date = Date()) {
        self.recordDate = record.recordDate
        self.fetchedAt = fetchedAt

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.sessionsData = (try? encoder.encode(record.sessions)) ?? Data()
    }
}

