import Foundation
import SwiftData
import SwiftUI
import GoalsData
import GoalsDomain

/// Provides Anki insight data from cache
public final class AnkiInsightProvider: InsightProvider, @unchecked Sendable {
    public static let insightType: InsightType = .anki

    private let container: ModelContainer
    private var _summary: InsightSummary?
    private var _activityData: InsightActivityData?

    public init(container: ModelContainer) {
        self.container = container
    }

    public func load() {
        let (start, end) = Self.dateRange
        let stats = (try? AnkiDailyStatsModel.fetch(from: start, to: end, in: container)) ?? []
        (_summary, _activityData) = Self.build(from: stats)
    }

    public var summary: InsightSummary? { _summary }
    public var activityData: InsightActivityData? { _activityData }

    // MARK: - Build Logic (Public for ViewModel use)

    /// Build Anki insight from stats and optional goals
    public static func build(
        from stats: [AnkiDailyStats],
        goals: [Goal] = []
    ) -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard !stats.isEmpty else { return (nil, nil) }

        let type = InsightType.anki

        // Filter to last 30 days for the card
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let last30DaysStats = stats.filter { $0.date >= cutoffDate }

        let scatterPoints = last30DaysStats.map { stat in
            InsightDataPoint(date: stat.date, value: Double(stat.reviewCount))
        }

        let movingAverageData = InsightCalculations.calculateMovingAverage(
            for: last30DaysStats.map { (date: $0.date, value: Double($0.reviewCount)) },
            window: 30
        )
        let movingAveragePoints = movingAverageData.map {
            InsightDataPoint(date: $0.date, value: $0.value)
        }

        let currentStreak = stats.currentStreak()
        let trend = InsightCalculations.calculateTrend(for: stats.map { Double($0.reviewCount) })
        let goalValue = goals.targetValue(for: "dailyReviews")

        let summary = InsightSummary(
            title: type.displayTitle,
            systemImage: type.systemImage,
            color: type.color,
            scatterPoints: scatterPoints,
            movingAveragePoints: movingAveragePoints,
            currentValueFormatted: "\(currentStreak) Day Streak",
            trend: trend,
            goalValue: goalValue
        )

        let activityDays = InsightCalculations.buildActivityDays(
            from: stats,
            color: type.color,
            dateExtractor: { $0.date },
            valueExtractor: { Double($0.reviewCount) }
        )
        let activityData = InsightActivityData(days: activityDays, emptyColor: .gray.opacity(0.2))

        return (summary, activityData)
    }
}
