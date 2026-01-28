import Foundation
import SwiftData
import GoalsDomain

/// Protocol for SwiftData models that cache domain records.
/// Each model handles its own persistence logic, eliminating the need for
/// type-switching in a centralized cache class.
public protocol CacheableModel: PersistentModel {
    associatedtype DomainType: CacheableRecord

    var cacheKey: String { get set }
    var recordDate: Date { get set }
    var fetchedAt: Date { get set }

    /// Converts the SwiftData model to its domain representation
    func toDomain() -> DomainType

    /// Creates a SwiftData model from a domain record
    static func from(_ record: DomainType, fetchedAt: Date) -> Self

    /// Updates the model from a domain record
    func update(from record: DomainType, fetchedAt: Date)
}

// MARK: - Default Implementations

public extension CacheableModel {
    /// Store multiple records in the cache using upsert logic.
    /// - Parameters:
    ///   - records: Array of domain records to store
    ///   - container: The ModelContainer to use for persistence
    /// - Note: Uses conflict resolution based on fetchedAt timestamp (newer wins)
    static func store(_ records: [DomainType], in container: ModelContainer) throws {
        guard !records.isEmpty else { return }

        let context = ModelContext(container)
        let fetchedAt = Date()

        for record in records {
            let cacheKey = record.cacheKey
            let descriptor = FetchDescriptor<Self>(
                predicate: #Predicate { $0.cacheKey == cacheKey }
            )
            if let existing = try context.fetch(descriptor).first {
                if fetchedAt > existing.fetchedAt {
                    existing.update(from: record, fetchedAt: fetchedAt)
                }
            } else {
                context.insert(Self.from(record, fetchedAt: fetchedAt))
            }
        }

        try context.save()
    }

    /// Fetch cached records within an optional date range.
    /// - Parameters:
    ///   - startDate: Optional start date (inclusive)
    ///   - endDate: Optional end date (inclusive)
    ///   - container: The ModelContainer to use for persistence
    /// - Returns: Array of domain records sorted by recordDate
    static func fetch(from startDate: Date? = nil, to endDate: Date? = nil, in container: ModelContainer) throws -> [DomainType] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Self>()

        if let start = startDate, let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start && $0.recordDate <= end }
        } else if let start = startDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start }
        } else if let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate <= end }
        }

        descriptor.sortBy = [SortDescriptor(\.recordDate)]
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    /// Fetch a single record by its cache key.
    /// - Parameters:
    ///   - cacheKey: The unique cache key
    ///   - container: The ModelContainer to use for persistence
    /// - Returns: The domain record if found
    static func fetchByCacheKey(_ cacheKey: String, in container: ModelContainer) throws -> DomainType? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Self>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        return try context.fetch(descriptor).first?.toDomain()
    }

    /// Returns the most recent record date.
    /// - Parameter container: The ModelContainer to use for persistence
    /// - Returns: The latest recordDate or nil if no records exist
    static func latestRecordDate(in container: ModelContainer) throws -> Date? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Self>()
        descriptor.sortBy = [SortDescriptor(\.recordDate, order: .reverse)]
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.recordDate
    }

    /// Returns the earliest record date.
    /// - Parameter container: The ModelContainer to use for persistence
    /// - Returns: The earliest recordDate or nil if no records exist
    static func earliestRecordDate(in container: ModelContainer) throws -> Date? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Self>()
        descriptor.sortBy = [SortDescriptor(\.recordDate, order: .forward)]
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.recordDate
    }

    /// Checks if any cached data exists.
    /// - Parameter container: The ModelContainer to use for persistence
    /// - Returns: True if at least one record exists
    static func hasData(in container: ModelContainer) throws -> Bool {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Self>()
        descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }

    /// Returns the count of cached records.
    /// - Parameter container: The ModelContainer to use for persistence
    /// - Returns: Number of records
    static func count(in container: ModelContainer) throws -> Int {
        let context = ModelContext(container)
        return try context.fetchCount(FetchDescriptor<Self>())
    }

    /// Deletes all cached records.
    /// - Parameter container: The ModelContainer to use for persistence
    static func deleteAll(in container: ModelContainer) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Self>()
        let entries = try context.fetch(descriptor)
        for entry in entries {
            context.delete(entry)
        }
        try context.save()
    }

    /// Deletes cached records older than a specified date.
    /// - Parameters:
    ///   - date: Cutoff date - records older than this will be deleted
    ///   - container: The ModelContainer to use for persistence
    static func deleteOlderThan(_ date: Date, in container: ModelContainer) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Self>(
            predicate: #Predicate { $0.recordDate < date }
        )
        let entries = try context.fetch(descriptor)
        for entry in entries {
            context.delete(entry)
        }
        try context.save()
    }
}
