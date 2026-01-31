import Foundation
import SwiftData
import SwiftUI
import GoalsCore
import GoalsData
import GoalsDomain

/// Provides Tasks insight data from cache
public final class TasksInsightProvider: BaseInsightProvider<TaskDailySummary> {
    public override class var insightType: InsightType { .tasks }

    public override func load() {
        let (start, end) = Self.dateRange
        let summaries = (try? TaskDailySummaryModel.fetch(from: start, to: end, in: container)) ?? []
        let (summary, activityData) = Self.build(from: summaries)
        setInsight(summary: summary, activityData: activityData)
    }

    // MARK: - Build Logic (Public for ViewModel use)

    /// Build Tasks insight from daily summaries
    /// - Parameters:
    ///   - dailySummaries: The daily summary data to build from
    ///   - goals: Optional goals for target values
    ///   - referenceDate: Reference date for active session duration calculations (defaults to now)
    public static func build(
        from dailySummaries: [TaskDailySummary],
        goals: [Goal] = [],
        referenceDate: Date = Date()
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

        // Use batch conversion with day boundary handling
        let rangeDataPoints = recentData.toDurationRangeDataPoints(referenceDate: referenceDate)

        let durationRangeData = InsightDurationRangeData(
            dataPoints: rangeDataPoints,
            defaultColor: type.color,
            dateRange: dateRange,
            useSimpleHours: true,
            boundaryHour: DayBoundaryConfig.tasks.boundaryHour
        )

        // Calculate today's hours using referenceDate for active sessions
        let today = calendar.startOfDay(for: referenceDate)
        let todayTotalHours = dailySummaries
            .filter { calendar.startOfDay(for: $0.date) == today }
            .reduce(0.0) { $0 + $1.totalDuration(at: referenceDate) / 3600.0 }

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
