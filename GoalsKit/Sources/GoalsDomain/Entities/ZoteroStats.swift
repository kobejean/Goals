import Foundation

/// Zotero daily annotation and note activity statistics
public struct ZoteroDailyStats: Sendable, Equatable, Codable {
    public let date: Date
    public let annotationCount: Int
    public let noteCount: Int

    public init(
        date: Date,
        annotationCount: Int,
        noteCount: Int
    ) {
        self.date = date
        self.annotationCount = annotationCount
        self.noteCount = noteCount
    }

    /// Total activity (annotations + notes)
    public var totalActivity: Int {
        annotationCount + noteCount
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
