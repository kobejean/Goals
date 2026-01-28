import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for caching Zotero reading status counts
@Model
public final class ZoteroReadingStatusModel {
    /// Unique cache key for this record (e.g., "zotero:readingStatus:2025-01-15")
    @Attribute(.unique)
    public var cacheKey: String = ""

    /// Date for this status record
    public var recordDate: Date = Date()

    /// When this record was fetched from the remote API
    public var fetchedAt: Date = Date()

    // MARK: - Status Fields

    /// Number of items in "To Read" collection
    public var toReadCount: Int = 0

    /// Number of items in "In Progress" collection
    public var inProgressCount: Int = 0

    /// Number of items in "Read" collection
    public var readCount: Int = 0

    public init(
        cacheKey: String,
        recordDate: Date,
        fetchedAt: Date = Date(),
        toReadCount: Int,
        inProgressCount: Int,
        readCount: Int
    ) {
        self.cacheKey = cacheKey
        self.recordDate = recordDate
        self.fetchedAt = fetchedAt
        self.toReadCount = toReadCount
        self.inProgressCount = inProgressCount
        self.readCount = readCount
    }
}

// MARK: - Domain Conversion

public extension ZoteroReadingStatusModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> ZoteroReadingStatus {
        ZoteroReadingStatus(
            date: recordDate,
            toReadCount: toReadCount,
            inProgressCount: inProgressCount,
            readCount: readCount
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ record: ZoteroReadingStatus, fetchedAt: Date = Date()) -> ZoteroReadingStatusModel {
        ZoteroReadingStatusModel(
            cacheKey: record.cacheKey,
            recordDate: record.recordDate,
            fetchedAt: fetchedAt,
            toReadCount: record.toReadCount,
            inProgressCount: record.inProgressCount,
            readCount: record.readCount
        )
    }

    /// Updates model from domain entity
    func update(from record: ZoteroReadingStatus, fetchedAt: Date = Date()) {
        self.recordDate = record.recordDate
        self.fetchedAt = fetchedAt
        self.toReadCount = record.toReadCount
        self.inProgressCount = record.inProgressCount
        self.readCount = record.readCount
    }
}
