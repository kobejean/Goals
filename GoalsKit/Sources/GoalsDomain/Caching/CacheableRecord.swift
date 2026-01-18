import Foundation

/// Protocol for domain objects that can be cached in SwiftData
/// Each conforming type must be Codable (for JSON serialization) and Sendable (for concurrency)
public protocol CacheableRecord: Codable, Sendable {
    /// The data source that provides this record type
    static var dataSource: DataSourceType { get }

    /// A string identifier for this record type (e.g., "stats", "submission", "effort")
    static var recordType: String { get }

    /// Unique cache key for this specific record (e.g., "tq:stats:2025-01-15")
    var cacheKey: String { get }

    /// The date associated with this record (used for date range queries)
    var recordDate: Date { get }
}
