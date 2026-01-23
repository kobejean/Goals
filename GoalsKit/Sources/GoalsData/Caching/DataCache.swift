import Foundation
import SwiftData
import GoalsDomain

/// Actor responsible for caching domain objects in SwiftData
/// Provides thread-safe operations for storing and retrieving cached records
public actor DataCache {
    private let modelContainer: ModelContainer

    /// UserDefaults key prefix for strategy metadata
    private static let metadataKeyPrefix = "cache.strategy."

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Strategy Metadata Storage

    /// Store metadata for an incremental fetch strategy.
    /// Metadata is stored in UserDefaults as JSON for simplicity and persistence.
    public func storeStrategyMetadata<S: IncrementalFetchStrategy>(
        _ metadata: S.Metadata,
        for strategy: S
    ) throws {
        let key = Self.metadataKeyPrefix + strategy.strategyKey
        let data = try JSONEncoder().encode(metadata)
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Fetch stored metadata for an incremental fetch strategy.
    /// Returns nil if no metadata has been stored yet.
    public func fetchStrategyMetadata<S: IncrementalFetchStrategy>(
        for strategy: S
    ) throws -> S.Metadata? {
        let key = Self.metadataKeyPrefix + strategy.strategyKey
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        return try JSONDecoder().decode(S.Metadata.self, from: data)
    }

    /// Clear stored metadata for an incremental fetch strategy.
    public func clearStrategyMetadata<S: IncrementalFetchStrategy>(
        for strategy: S
    ) {
        let key = Self.metadataKeyPrefix + strategy.strategyKey
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Store Operations

    /// Stores multiple records in the cache
    /// - Parameter records: Array of records conforming to CacheableRecord
    /// - Note: Uses conflict resolution based on fetchedAt timestamp (newer wins)
    public func store<T: CacheableRecord>(_ records: [T]) async throws {
        guard !records.isEmpty else { return }

        let context = ModelContext(modelContainer)
        let fetchedAt = Date()

        for record in records {
            let cacheKey = record.cacheKey

            // Check if record exists
            let existingDescriptor = FetchDescriptor<CachedDataEntry>(
                predicate: #Predicate { $0.cacheKey == cacheKey }
            )

            if let existing = try context.fetch(existingDescriptor).first {
                // Conflict resolution: prefer newer fetchedAt
                if fetchedAt > existing.fetchedAt {
                    let newEntry = try CachedDataEntry(record: record, fetchedAt: fetchedAt)
                    existing.payload = newEntry.payload
                    existing.fetchedAt = fetchedAt
                    existing.recordDate = record.recordDate
                }
            } else {
                // Insert new record
                let entry = try CachedDataEntry(record: record, fetchedAt: fetchedAt)
                context.insert(entry)
            }
        }

        try context.save()
    }

    /// Stores a single record in the cache
    public func store<T: CacheableRecord>(_ record: T) async throws {
        try await store([record])
    }

    // MARK: - Fetch Operations

    /// Fetches cached records within an optional date range
    /// - Parameters:
    ///   - type: The type of record to fetch
    ///   - from: Optional start date (inclusive)
    ///   - to: Optional end date (inclusive)
    /// - Returns: Array of decoded records sorted by recordDate
    public func fetch<T: CacheableRecord>(
        _ type: T.Type,
        from startDate: Date? = nil,
        to endDate: Date? = nil
    ) async throws -> [T] {
        let context = ModelContext(modelContainer)
        let dataSourceRaw = T.dataSource.rawValue
        let recordType = T.recordType

        var predicate: Predicate<CachedDataEntry>

        if let start = startDate, let end = endDate {
            predicate = #Predicate {
                $0.dataSourceRaw == dataSourceRaw &&
                $0.recordType == recordType &&
                $0.recordDate >= start &&
                $0.recordDate <= end
            }
        } else if let start = startDate {
            predicate = #Predicate {
                $0.dataSourceRaw == dataSourceRaw &&
                $0.recordType == recordType &&
                $0.recordDate >= start
            }
        } else if let end = endDate {
            predicate = #Predicate {
                $0.dataSourceRaw == dataSourceRaw &&
                $0.recordType == recordType &&
                $0.recordDate <= end
            }
        } else {
            predicate = #Predicate {
                $0.dataSourceRaw == dataSourceRaw &&
                $0.recordType == recordType
            }
        }

        var descriptor = FetchDescriptor<CachedDataEntry>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.recordDate)]

        let entries = try context.fetch(descriptor)
        return try entries.map { try $0.decode(as: T.self) }
    }

    /// Fetches a single record by its cache key
    public func fetch<T: CacheableRecord>(
        _ type: T.Type,
        cacheKey: String
    ) async throws -> T? {
        let context = ModelContext(modelContainer)

        let descriptor = FetchDescriptor<CachedDataEntry>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )

        guard let entry = try context.fetch(descriptor).first else {
            return nil
        }

        return try entry.decode(as: T.self)
    }

    // MARK: - Query Operations

    /// Returns the most recent record date for a given type
    /// Useful for determining what data to fetch incrementally
    public func latestRecordDate<T: CacheableRecord>(for type: T.Type) async throws -> Date? {
        let context = ModelContext(modelContainer)
        let dataSourceRaw = T.dataSource.rawValue
        let recordType = T.recordType

        var descriptor = FetchDescriptor<CachedDataEntry>(
            predicate: #Predicate {
                $0.dataSourceRaw == dataSourceRaw &&
                $0.recordType == recordType
            }
        )
        descriptor.sortBy = [SortDescriptor(\.recordDate, order: .reverse)]
        descriptor.fetchLimit = 1

        return try context.fetch(descriptor).first?.recordDate
    }

    /// Returns the earliest record date for a given type
    public func earliestRecordDate<T: CacheableRecord>(for type: T.Type) async throws -> Date? {
        let context = ModelContext(modelContainer)
        let dataSourceRaw = T.dataSource.rawValue
        let recordType = T.recordType

        var descriptor = FetchDescriptor<CachedDataEntry>(
            predicate: #Predicate {
                $0.dataSourceRaw == dataSourceRaw &&
                $0.recordType == recordType
            }
        )
        descriptor.sortBy = [SortDescriptor(\.recordDate, order: .forward)]
        descriptor.fetchLimit = 1

        return try context.fetch(descriptor).first?.recordDate
    }

    /// Checks if any cached data exists for a given record type
    public func hasCachedData<T: CacheableRecord>(for type: T.Type) async throws -> Bool {
        let context = ModelContext(modelContainer)
        let dataSourceRaw = T.dataSource.rawValue
        let recordType = T.recordType

        var descriptor = FetchDescriptor<CachedDataEntry>(
            predicate: #Predicate {
                $0.dataSourceRaw == dataSourceRaw &&
                $0.recordType == recordType
            }
        )
        descriptor.fetchLimit = 1

        return try !context.fetch(descriptor).isEmpty
    }

    /// Returns the count of cached records for a given type
    public func count<T: CacheableRecord>(for type: T.Type) async throws -> Int {
        let context = ModelContext(modelContainer)
        let dataSourceRaw = T.dataSource.rawValue
        let recordType = T.recordType

        let descriptor = FetchDescriptor<CachedDataEntry>(
            predicate: #Predicate {
                $0.dataSourceRaw == dataSourceRaw &&
                $0.recordType == recordType
            }
        )

        return try context.fetchCount(descriptor)
    }

    // MARK: - Delete Operations

    /// Deletes all cached records for a given type
    public func deleteAll<T: CacheableRecord>(for type: T.Type) async throws {
        let context = ModelContext(modelContainer)
        let dataSourceRaw = T.dataSource.rawValue
        let recordType = T.recordType

        let descriptor = FetchDescriptor<CachedDataEntry>(
            predicate: #Predicate {
                $0.dataSourceRaw == dataSourceRaw &&
                $0.recordType == recordType
            }
        )

        let entries = try context.fetch(descriptor)
        for entry in entries {
            context.delete(entry)
        }

        try context.save()
    }

    /// Deletes cached records older than a specified date
    public func deleteOlderThan<T: CacheableRecord>(
        _ date: Date,
        for type: T.Type
    ) async throws {
        let context = ModelContext(modelContainer)
        let dataSourceRaw = T.dataSource.rawValue
        let recordType = T.recordType

        let descriptor = FetchDescriptor<CachedDataEntry>(
            predicate: #Predicate {
                $0.dataSourceRaw == dataSourceRaw &&
                $0.recordType == recordType &&
                $0.recordDate < date
            }
        )

        let entries = try context.fetch(descriptor)
        for entry in entries {
            context.delete(entry)
        }

        try context.save()
    }
}
