import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for caching daily nutrition summaries
@Model
public final class NutritionDailySummaryModel {
    /// Unique cache key for this record (e.g., "nutrition:daily:2025-01-15")
    @Attribute(.unique)
    public var cacheKey: String = ""

    /// Date for this summary (start of day)
    public var recordDate: Date = Date()

    /// When this record was written to cache
    public var fetchedAt: Date = Date()

    // MARK: - Nutrition Data

    /// JSON-encoded array of NutritionEntry
    /// Contains all nutrition entries for this day
    @Attribute(.externalStorage)
    public var entriesData: Data = Data()

    public init(
        cacheKey: String,
        recordDate: Date,
        fetchedAt: Date = Date(),
        entriesData: Data
    ) {
        self.cacheKey = cacheKey
        self.recordDate = recordDate
        self.fetchedAt = fetchedAt
        self.entriesData = entriesData
    }
}

// MARK: - CacheableModel Conformance

extension NutritionDailySummaryModel: CacheableModel {
    public typealias DomainType = NutritionDailySummary
}

// MARK: - Domain Conversion

public extension NutritionDailySummaryModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> NutritionDailySummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = (try? decoder.decode([NutritionEntry].self, from: entriesData)) ?? []

        return NutritionDailySummary(
            date: recordDate,
            entries: entries
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ record: NutritionDailySummary, fetchedAt: Date = Date()) -> NutritionDailySummaryModel {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(record.entries)) ?? Data()

        return NutritionDailySummaryModel(
            cacheKey: record.cacheKey,
            recordDate: record.recordDate,
            fetchedAt: fetchedAt,
            entriesData: data
        )
    }

    /// Updates model from domain entity
    func update(from record: NutritionDailySummary, fetchedAt: Date = Date()) {
        self.recordDate = record.recordDate
        self.fetchedAt = fetchedAt

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.entriesData = (try? encoder.encode(record.entries)) ?? Data()
    }
}
