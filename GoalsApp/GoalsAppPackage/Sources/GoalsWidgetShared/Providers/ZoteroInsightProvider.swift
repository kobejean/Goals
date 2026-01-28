import Foundation
import SwiftData
import SwiftUI
import GoalsData
import GoalsDomain

/// Provides Zotero insight data from cache
public final class ZoteroInsightProvider: InsightProvider, @unchecked Sendable {
    public static let insightType: InsightType = .zotero

    private let container: ModelContainer
    private var _summary: InsightSummary?
    private var _activityData: InsightActivityData?

    public init(container: ModelContainer) {
        self.container = container
    }

    public func load() {
        let (start, end) = Self.dateRange
        let stats = (try? ZoteroDailyStatsModel.fetch(from: start, to: end, in: container)) ?? []
        let readingStatuses = (try? ZoteroReadingStatusModel.fetch(in: container)) ?? []
        let readingStatus = readingStatuses.max { $0.date < $1.date }
        (_summary, _activityData) = Self.build(from: stats, readingStatus: readingStatus)
    }

    public var summary: InsightSummary? { _summary }
    public var activityData: InsightActivityData? { _activityData }

    // MARK: - Build Logic (Public for ViewModel use)

    /// Build Zotero insight from daily stats and optional reading status
    public static func build(
        from stats: [ZoteroDailyStats],
        readingStatus: ZoteroReadingStatus? = nil,
        goals: [Goal] = []
    ) -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard !stats.isEmpty else { return (nil, nil) }

        let type = InsightType.zotero

        // Filter to last 30 days for the card
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let last30DaysStats = stats.filter { $0.date >= cutoffDate }

        let scatterPoints = last30DaysStats.map { stat in
            InsightDataPoint(date: stat.date, value: stat.weightedPoints)
        }

        let movingAverageData = InsightCalculations.calculateMovingAverage(
            for: last30DaysStats.map { (date: $0.date, value: $0.weightedPoints) },
            window: 30
        )
        let movingAveragePoints = movingAverageData.map {
            InsightDataPoint(date: $0.date, value: $0.value)
        }

        // Determine display value: reading progress or streak
        let currentValueFormatted: String
        if let status = readingStatus, status.totalItems > 0 {
            currentValueFormatted = "\(status.readCount)/\(status.totalItems) Read"
        } else {
            let currentStreak = stats.currentStreak()
            currentValueFormatted = "\(currentStreak) Day Streak"
        }

        let trend = InsightCalculations.calculateTrend(for: stats.map { $0.weightedPoints })
        let goalValue = goals.targetValue(for: "dailyAnnotations")

        let summary = InsightSummary(
            title: type.displayTitle,
            systemImage: type.systemImage,
            color: type.color,
            scatterPoints: scatterPoints,
            movingAveragePoints: movingAveragePoints,
            currentValueFormatted: currentValueFormatted,
            trend: trend,
            goalValue: goalValue
        )

        let activityDays = InsightCalculations.buildActivityDays(
            from: stats,
            color: type.color,
            dateExtractor: { $0.date },
            valueExtractor: { $0.weightedPoints }
        )
        let activityData = InsightActivityData(days: activityDays, emptyColor: .gray.opacity(0.2))

        return (summary, activityData)
    }
}
