import Foundation

/// TypeQuicker typing statistics
public struct TypeQuickerStats: Sendable, Equatable, Codable {
    public let date: Date
    public let wordsPerMinute: Double
    public let accuracy: Double
    public let practiceTimeMinutes: Int
    public let sessionsCount: Int
    public let byMode: [TypeQuickerModeStats]?

    public init(
        date: Date,
        wordsPerMinute: Double,
        accuracy: Double,
        practiceTimeMinutes: Int,
        sessionsCount: Int,
        byMode: [TypeQuickerModeStats]? = nil
    ) {
        self.date = date
        self.wordsPerMinute = wordsPerMinute
        self.accuracy = accuracy
        self.practiceTimeMinutes = practiceTimeMinutes
        self.sessionsCount = sessionsCount
        self.byMode = byMode
    }
}

// MARK: - CacheableRecord

extension TypeQuickerStats: CacheableRecord {
    public static var dataSource: DataSourceType { .typeQuicker }
    public static var recordType: String { "stats" }

    public var cacheKey: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "tq:stats:\(dateFormatter.string(from: date))"
    }

    public var recordDate: Date { date }
}

// MARK: - Mode Stats

/// TypeQuicker statistics grouped by mode (e.g., "words", "quotes", "numbers")
public struct TypeQuickerModeStats: Sendable, Equatable, Codable, Identifiable {
    public var id: String { mode }
    public let mode: String
    public let wordsPerMinute: Double
    public let accuracy: Double
    public let practiceTimeMinutes: Int
    public let sessionsCount: Int

    public init(
        mode: String,
        wordsPerMinute: Double,
        accuracy: Double,
        practiceTimeMinutes: Int,
        sessionsCount: Int
    ) {
        self.mode = mode
        self.wordsPerMinute = wordsPerMinute
        self.accuracy = accuracy
        self.practiceTimeMinutes = practiceTimeMinutes
        self.sessionsCount = sessionsCount
    }

    /// Display name for the mode
    public var displayName: String {
        mode.capitalized
    }
}
