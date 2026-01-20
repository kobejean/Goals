import Foundation

/// Anki daily learning statistics
public struct AnkiDailyStats: Sendable, Equatable, Codable {
    public let date: Date
    public let reviewCount: Int
    public let studyTimeSeconds: Int
    public let correctCount: Int
    public let newCardsCount: Int

    public init(
        date: Date,
        reviewCount: Int,
        studyTimeSeconds: Int,
        correctCount: Int,
        newCardsCount: Int
    ) {
        self.date = date
        self.reviewCount = reviewCount
        self.studyTimeSeconds = studyTimeSeconds
        self.correctCount = correctCount
        self.newCardsCount = newCardsCount
    }

    /// Study time in minutes
    public var studyTimeMinutes: Double {
        Double(studyTimeSeconds) / 60.0
    }

    /// Retention rate as a percentage (0-100)
    public var retentionRate: Double {
        guard reviewCount > 0 else { return 0 }
        return (Double(correctCount) / Double(reviewCount)) * 100.0
    }
}

// MARK: - CacheableRecord

extension AnkiDailyStats: CacheableRecord {
    public static var dataSource: DataSourceType { .anki }
    public static var recordType: String { "dailyStats" }

    public var cacheKey: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "anki:dailyStats:\(dateFormatter.string(from: date))"
    }

    public var recordDate: Date { date }
}

// MARK: - Streak Calculation

public extension Array where Element == AnkiDailyStats {
    /// Calculate current streak (consecutive days with at least one review)
    func currentStreak(from referenceDate: Date = Date()) -> Int {
        guard !isEmpty else { return 0 }

        let calendar = Calendar.current
        let sortedStats = self.sorted { $0.date > $1.date }
        var streak = 0
        var expectedDate = calendar.startOfDay(for: referenceDate)

        for stat in sortedStats {
            let statDate = calendar.startOfDay(for: stat.date)

            if statDate == expectedDate {
                if stat.reviewCount > 0 {
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
            .filter { $0.reviewCount > 0 }

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
