import Foundation

/// Strategy for backing up cache data incrementally
/// Since CachedDataEntry can have 1000+ records, we need special handling
public struct CacheBackupStrategy: Sendable {
    /// Maximum number of cache records to sync per batch
    public let batchSize: Int

    /// How old cache records must be before backup (avoids backing up temporary data)
    public let minimumAge: TimeInterval

    /// Maximum age for cache records to backup (very old data may be stale)
    public let maximumAge: TimeInterval

    public init(
        batchSize: Int = 100,
        minimumAge: TimeInterval = 60 * 60,         // 1 hour
        maximumAge: TimeInterval = 60 * 60 * 24 * 365  // 1 year
    ) {
        self.batchSize = batchSize
        self.minimumAge = minimumAge
        self.maximumAge = maximumAge
    }

    /// Default strategy for cache backup
    public static let `default` = CacheBackupStrategy()

    /// Strategy that backs up more aggressively (for manual backup)
    public static let aggressive = CacheBackupStrategy(
        batchSize: 200,
        minimumAge: 0,
        maximumAge: .infinity
    )

    /// Determines if a cache record should be backed up based on its fetchedAt date
    public func shouldBackup(fetchedAt: Date, now: Date = Date()) -> Bool {
        let age = now.timeIntervalSince(fetchedAt)
        return age >= minimumAge && age <= maximumAge
    }
}

/// Represents a cached data entry for CloudKit backup
/// This is a simpler representation than CachedDataEntry for serialization
public struct CacheBackupRecord: Codable, Sendable {
    public let cacheKey: String
    public let dataSourceRaw: String
    public let recordType: String
    public let recordDate: Date
    public let payload: Data
    public let fetchedAt: Date

    public init(
        cacheKey: String,
        dataSourceRaw: String,
        recordType: String,
        recordDate: Date,
        payload: Data,
        fetchedAt: Date
    ) {
        self.cacheKey = cacheKey
        self.dataSourceRaw = dataSourceRaw
        self.recordType = recordType
        self.recordDate = recordDate
        self.payload = payload
        self.fetchedAt = fetchedAt
    }

    /// Unique identifier derived from cache key
    public var id: UUID {
        // Generate deterministic UUID from cache key
        UUID(uuidString: cacheKey.data(using: .utf8)?.base64EncodedString().prefix(36).description ?? "") ?? UUID()
    }
}

/// Tracks the last backup state for incremental sync
public struct CacheBackupState: Codable, Sendable {
    /// Last fetchedAt timestamp that was backed up per data source
    public var lastBackedUpAt: [String: Date]

    /// Total records backed up per data source
    public var recordCounts: [String: Int]

    public init(
        lastBackedUpAt: [String: Date] = [:],
        recordCounts: [String: Int] = [:]
    ) {
        self.lastBackedUpAt = lastBackedUpAt
        self.recordCounts = recordCounts
    }

    /// Update state after backing up records from a data source
    public mutating func updateState(
        dataSource: String,
        lastFetchedAt: Date,
        count: Int
    ) {
        lastBackedUpAt[dataSource] = lastFetchedAt
        recordCounts[dataSource] = (recordCounts[dataSource] ?? 0) + count
    }

    /// Get the cutoff date for a data source (only backup newer records)
    public func cutoffDate(for dataSource: String) -> Date? {
        lastBackedUpAt[dataSource]
    }
}
