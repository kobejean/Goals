import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for storing cached domain records as JSON
/// Each entry represents a single domain object (e.g., TypeQuickerStats, AtCoderSubmission)
@Model
public final class CachedDataEntry {
    /// Identifier combining data source, record type, and record-specific key
    /// Format: "{dataSource}:{recordType}:{uniqueKey}"
    public var cacheKey: String = ""

    /// Raw value of the DataSourceType enum
    public var dataSourceRaw: String = ""

    /// Type of record (e.g., "stats", "submission", "effort")
    public var recordType: String = ""

    /// Date associated with the record (for date range queries)
    public var recordDate: Date = Date()

    /// JSON-encoded domain object
    public var payload: Data = Data()

    /// When this record was fetched from the remote API
    public var fetchedAt: Date = Date()

    public init(
        cacheKey: String,
        dataSourceRaw: String,
        recordType: String,
        recordDate: Date,
        payload: Data,
        fetchedAt: Date = Date()
    ) {
        self.cacheKey = cacheKey
        self.dataSourceRaw = dataSourceRaw
        self.recordType = recordType
        self.recordDate = recordDate
        self.payload = payload
        self.fetchedAt = fetchedAt
    }
}

// MARK: - Convenience Initializer

public extension CachedDataEntry {
    /// Creates a CachedDataEntry from a CacheableRecord
    convenience init<T: CacheableRecord>(record: T, fetchedAt: Date = Date()) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = try encoder.encode(record)

        self.init(
            cacheKey: record.cacheKey,
            dataSourceRaw: T.dataSource.rawValue,
            recordType: T.recordType,
            recordDate: record.recordDate,
            payload: payload,
            fetchedAt: fetchedAt
        )
    }

    /// Decodes the stored payload back to its domain type
    func decode<T: CacheableRecord>(as type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: payload)
    }
}
