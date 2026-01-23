import Foundation

/// Zotero daily annotation and note activity statistics
public struct ZoteroDailyStats: Sendable, Equatable, Codable {
    public let date: Date
    public let annotationCount: Int
    public let noteCount: Int
    /// Reading progress score: toRead×0.25 + inProgress×0.5 + read×1.0
    public let readingProgressScore: Double

    public init(
        date: Date,
        annotationCount: Int,
        noteCount: Int,
        readingProgressScore: Double = 0
    ) {
        self.date = date
        self.annotationCount = annotationCount
        self.noteCount = noteCount
        self.readingProgressScore = readingProgressScore
    }

    // Custom decoder for backwards compatibility with cached data missing readingProgressScore
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(Date.self, forKey: .date)
        annotationCount = try container.decode(Int.self, forKey: .annotationCount)
        noteCount = try container.decode(Int.self, forKey: .noteCount)
        // Try new field first, fall back to old statusChanges field, then default to 0
        if let score = try container.decodeIfPresent(Double.self, forKey: .readingProgressScore) {
            readingProgressScore = score
        } else if let oldStatusChanges = try container.decodeIfPresent(Int.self, forKey: .statusChanges) {
            readingProgressScore = Double(oldStatusChanges) * 0.5
        } else {
            readingProgressScore = 0
        }
    }

    private enum CodingKeys: String, CodingKey {
        case date, annotationCount, noteCount, readingProgressScore, statusChanges
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(annotationCount, forKey: .annotationCount)
        try container.encode(noteCount, forKey: .noteCount)
        try container.encode(readingProgressScore, forKey: .readingProgressScore)
    }

    /// Total activity for streak calculation (has activity if any annotations, notes, or reading progress)
    public var totalActivity: Int {
        annotationCount + noteCount + (readingProgressScore > 0 ? 1 : 0)
    }

    /// Weighted points for chart
    /// Formula: 0.1 * min(10, annotations) + 0.2 * min(5, notes) + readingProgress
    /// Caps: annotations max 1.0pt, notes max 1.0pt, readingProgress uncapped
    public var weightedPoints: Double {
        0.1 * Double(min(10, annotationCount)) +
        0.2 * Double(min(5, noteCount)) +
        readingProgressScore
    }
}

// MARK: - CacheableRecord

extension ZoteroDailyStats: CacheableRecord {
    public static var dataSource: DataSourceType { .zotero }
    public static var recordType: String { "dailyStats" }

    public var cacheKey: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "zotero:dailyStats:\(dateFormatter.string(from: date))"
    }

    public var recordDate: Date { date }
}

// MARK: - Streak Calculation

public extension Array where Element == ZoteroDailyStats {
    /// Calculate current streak (consecutive days with at least one annotation or note)
    func currentStreak(from referenceDate: Date = Date()) -> Int {
        guard !isEmpty else { return 0 }

        let calendar = Calendar.current
        let sortedStats = self.sorted { $0.date > $1.date }
        var streak = 0
        var expectedDate = calendar.startOfDay(for: referenceDate)

        for stat in sortedStats {
            let statDate = calendar.startOfDay(for: stat.date)

            if statDate == expectedDate {
                if stat.totalActivity > 0 {
                    streak += 1
                    expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
                } else {
                    break
                }
            } else if statDate < expectedDate {
                // Missing days break the streak
                break
            }
        }

        return streak
    }

    /// Calculate longest streak ever recorded
    func longestStreak() -> Int {
        guard !isEmpty else { return 0 }

        let calendar = Calendar.current
        let sortedStats = self.sorted { $0.date < $1.date }
            .filter { $0.totalActivity > 0 }

        guard !sortedStats.isEmpty else { return 0 }

        var longestStreak = 1
        var currentStreak = 1
        var previousDate = calendar.startOfDay(for: sortedStats[0].date)

        for stat in sortedStats.dropFirst() {
            let currentDate = calendar.startOfDay(for: stat.date)
            let daysDifference = calendar.dateComponents([.day], from: previousDate, to: currentDate).day ?? 0

            if daysDifference == 1 {
                currentStreak += 1
                longestStreak = Swift.max(longestStreak, currentStreak)
            } else if daysDifference > 1 {
                currentStreak = 1
            }
            // daysDifference == 0 means same day, skip

            previousDate = currentDate
        }

        return longestStreak
    }
}
