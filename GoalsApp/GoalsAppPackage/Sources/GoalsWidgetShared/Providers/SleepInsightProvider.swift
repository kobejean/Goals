import Foundation
import SwiftData
import SwiftUI
import GoalsData
import GoalsDomain

/// Provides Sleep insight data from cache
public final class SleepInsightProvider: InsightProvider, @unchecked Sendable {
    public static let insightType: InsightType = .sleep

    private let container: ModelContainer
    private var _summary: InsightSummary?
    private var _activityData: InsightActivityData?

    public init(container: ModelContainer) {
        self.container = container
    }

    public func load() {
        let (start, end) = Self.dateRange
        let sleepData = (try? SleepDailySummaryModel.fetch(from: start, to: end, in: container)) ?? []
        (_summary, _activityData) = Self.build(from: sleepData)
    }

    public var summary: InsightSummary? { _summary }
    public var activityData: InsightActivityData? { _activityData }

    // MARK: - Build Logic (Public for ViewModel use)

    /// Build Sleep insight from daily summaries
    public static func build(
        from sleepData: [SleepDailySummary],
        goals: [Goal] = []
    ) -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard !sleepData.isEmpty else { return (nil, nil) }

        let type = InsightType.sleep

        // Limit to last 14 entries for duration range chart readability
        let recentData = Array(sleepData.suffix(14))

        let rangeDataPoints = recentData.compactMap { summary -> DurationRangeDataPoint? in
            guard let bedtime = summary.bedtime, let wakeTime = summary.wakeTime else { return nil }
            let segment = DurationSegment(startTime: bedtime, endTime: wakeTime, color: type.color)
            return DurationRangeDataPoint(date: summary.date, segments: [segment])
        }

        guard !rangeDataPoints.isEmpty else { return (nil, nil) }

        let currentHours = sleepData.last?.totalSleepHours ?? 0
        let trend = InsightCalculations.calculateTrend(for: sleepData.map { $0.totalSleepHours })

        let durationRangeData = InsightDurationRangeData(
            dataPoints: rangeDataPoints,
            defaultColor: type.color,
            useSimpleHours: false
        )

        let summary = InsightSummary(
            title: type.displayTitle,
            systemImage: type.systemImage,
            color: type.color,
            durationRangeData: durationRangeData,
            currentValueFormatted: formatHours(currentHours),
            trend: trend
        )

        // Build activity data
        let targetHours = goals.targetValue(for: "sleepDuration") ?? 8.0
        let activityDays = sleepData.map { summary in
            let intensity = min(summary.totalSleepHours / targetHours, 1.0)
            return InsightActivityDay(date: summary.date, color: type.color, intensity: intensity)
        }

        let activityData = InsightActivityData(days: activityDays, emptyColor: .gray.opacity(0.2))

        return (summary, activityData)
    }

    private static func formatHours(_ hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if m == 0 {
            return "\(h)h"
        }
        return "\(h)h \(m)m"
    }
}
