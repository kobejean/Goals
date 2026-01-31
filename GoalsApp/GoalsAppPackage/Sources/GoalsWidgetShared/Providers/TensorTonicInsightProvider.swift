import Foundation
import SwiftData
import SwiftUI
import GoalsData
import GoalsDomain

/// Provides TensorTonic insight data from cache
public final class TensorTonicInsightProvider: BaseInsightProvider<TensorTonicStats> {
    public override class var insightType: InsightType { .tensorTonic }

    public override func load() {
        // Fetch the latest stats from cache
        let stats = (try? TensorTonicStatsModel.fetch(in: container)) ?? []
        let latestStats = stats.max { $0.date < $1.date }

        // Fetch heatmap for activity chart
        let (start, end) = Self.dateRange
        let heatmap = (try? TensorTonicHeatmapModel.fetch(from: start, to: end, in: container)) ?? []

        let (summary, activityData) = Self.build(from: latestStats, heatmap: heatmap)
        setInsight(summary: summary, activityData: activityData)
    }

    // MARK: - Build Logic (Public for ViewModel use)

    /// Build TensorTonic insight from stats and heatmap data
    public static func build(
        from stats: TensorTonicStats?,
        heatmap: [TensorTonicHeatmapEntry] = [],
        goals: [Goal] = []
    ) -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard let stats = stats else { return (nil, nil) }

        let type = InsightType.tensorTonic

        // Build scatter points from heatmap data
        let scatterPoints = heatmap.map { entry in
            InsightDataPoint(date: entry.date, value: Double(entry.count))
        }

        // Calculate moving average
        let movingAverageData = InsightCalculations.calculateMovingAverage(
            for: heatmap.map { (date: $0.date, value: Double($0.count)) },
            window: 7
        )
        let movingAveragePoints = movingAverageData.map {
            InsightDataPoint(date: $0.date, value: $0.value)
        }

        // Format current value - show problems solved
        let totalProblems = stats.totalEasyProblems + stats.totalMediumProblems + stats.totalHardProblems
        let currentValueFormatted = "\(stats.totalSolved)/\(totalProblems) Solved"

        // Calculate trend from heatmap activity
        let trend = InsightCalculations.calculateTrend(for: heatmap.map { Double($0.count) })
        let goalValue = goals.targetValue(for: "problemsSolved")

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

        // Build activity data from heatmap
        let activityDays = InsightCalculations.buildActivityDays(
            from: heatmap,
            color: type.color,
            dateExtractor: { $0.date },
            valueExtractor: { Double($0.count) }
        )
        let activityData = InsightActivityData(days: activityDays, emptyColor: .gray.opacity(0.2))

        return (summary, activityData)
    }
}
