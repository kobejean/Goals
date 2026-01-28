import Foundation
import SwiftData
import SwiftUI
import GoalsData
import GoalsDomain

/// Provides Tasks insight data from cache
public final class TasksInsightProvider: InsightProvider, @unchecked Sendable {
    public static let insightType: InsightType = .tasks

    private let container: ModelContainer
    private var _summary: InsightSummary?
    private var _activityData: InsightActivityData?

    public init(container: ModelContainer) {
        self.container = container
    }

    public func load() {
        let (start, end) = Self.dateRange
        let summaries = (try? TaskDailySummaryModel.fetch(from: start, to: end, in: container)) ?? []
        (_summary, _activityData) = Self.build(from: summaries)
    }

    public var summary: InsightSummary? { _summary }
    public var activityData: InsightActivityData? { _activityData }

    // MARK: - Build Logic (Public for ViewModel use)

    /// Build Tasks insight from daily summaries
    public static func build(
        from dailySummaries: [TaskDailySummary],
        goals: [Goal] = []
    ) -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard !dailySummaries.isEmpty else { return (nil, nil) }

        let type = InsightType.tasks
        let calendar = Calendar.current

        // Fixed 10-day date range for consistent X-axis
        let dateRange = DateRange.lastDays(10)
        let rangeStart = calendar.startOfDay(for: dateRange.start)
        let rangeEnd = calendar.startOfDay(for: dateRange.end)

        let recentData = dailySummaries.filter { summary in
            let day = calendar.startOfDay(for: summary.date)
            return day >= rangeStart && day <= rangeEnd
        }

        let rangeDataPoints = recentData.map { summary in
            summary.toDurationRangeDataPoint()
        }

        let durationRangeData = InsightDurationRangeData(
            dataPoints: rangeDataPoints,
            defaultColor: type.color,
            dateRange: dateRange,
            useSimpleHours: true
        )

        // Calculate today's hours
        let today = calendar.startOfDay(for: Date())
        let todayTotalHours = dailySummaries
            .filter { calendar.startOfDay(for: $0.date) == today }
            .reduce(0.0) { $0 + $1.totalDuration / 3600.0 }

        let trend = InsightCalculations.calculateTrend(for: dailySummaries.map { $0.totalDuration / 3600.0 })

        let summary = InsightSummary(
            title: type.displayTitle,
            systemImage: type.systemImage,
            color: type.color,
            durationRangeData: durationRangeData,
            currentValueFormatted: formatHours(todayTotalHours),
            trend: trend
        )

        // Build activity data
        let targetHours = goals.targetValue(for: "dailyDuration").map { $0 / 60.0 } ?? 4.0
        let activityDays = dailySummaries.map { summary in
            let hours = summary.totalDuration / 3600.0
            let intensity = min(hours / targetHours, 1.0)
            return InsightActivityDay(date: summary.date, color: type.color, intensity: intensity)
        }

        let activityData = InsightActivityData(days: activityDays, emptyColor: .gray.opacity(0.2))

        return (summary, activityData)
    }

    private static func formatHours(_ hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h == 0 && m == 0 {
            return "0m"
        }
        if h == 0 {
            return "\(m)m"
        }
        if m == 0 {
            return "\(h)h"
        }
        return "\(h)h \(m)m"
    }
}
