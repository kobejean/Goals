import Foundation

/// Zotero reading status - counts of items in each reading state collection
public struct ZoteroReadingStatus: Sendable, Equatable, Codable {
    public let date: Date
    public let toReadCount: Int
    public let inProgressCount: Int
    public let readCount: Int

    public init(
        date: Date,
        toReadCount: Int,
        inProgressCount: Int,
        readCount: Int
    ) {
        self.date = date
        self.toReadCount = toReadCount
        self.inProgressCount = inProgressCount
        self.readCount = readCount
    }

    /// Total items across all reading states
    public var totalItems: Int {
        toReadCount + inProgressCount + readCount
    }

    /// Completion percentage (read / total)
    public var completionPercentage: Double {
        guard totalItems > 0 else { return 0 }
        return (Double(readCount) / Double(totalItems)) * 100.0
    }

    /// Progress percentage (in progress + read / total)
    public var progressPercentage: Double {
        guard totalItems > 0 else { return 0 }
        return (Double(inProgressCount + readCount) / Double(totalItems)) * 100.0
    }
}

// MARK: - CacheableRecord

extension ZoteroReadingStatus: CacheableRecord {
    public static var dataSource: DataSourceType { .zotero }
    public static var recordType: String { "readingStatus" }

    public var cacheKey: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "zotero:readingStatus:\(dateFormatter.string(from: date))"
    }

    public var recordDate: Date { Calendar.current.startOfDay(for: date) }
}
