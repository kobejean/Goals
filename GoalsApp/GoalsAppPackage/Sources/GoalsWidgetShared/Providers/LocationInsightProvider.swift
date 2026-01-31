import Foundation
import SwiftData
import SwiftUI
import GoalsCore
import GoalsData
import GoalsDomain

/// Provides Location insight data from cache
public final class LocationInsightProvider: BaseInsightProvider<LocationDailySummary> {
    public override class var insightType: InsightType { .locations }

    public override func load() {
        let (start, end) = Self.dateRange
        let summaries = (try? LocationDailySummaryModel.fetch(from: start, to: end, in: container)) ?? []
        let (summary, activityData) = Self.build(from: summaries)
        setInsight(summary: summary, activityData: activityData)
    }

    // MARK: - Build Logic (Public for ViewModel use)

    /// Build Location insight from daily summaries
    /// - Parameters:
    ///   - dailySummaries: The daily summary data to build from
    ///   - goals: Optional goals for target values
    ///   - referenceDate: Reference date for active session duration calculations (defaults to now)
    public static func build(
        from dailySummaries: [LocationDailySummary],
        goals: [Goal] = [],
        referenceDate: Date = Date()
    ) -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard !dailySummaries.isEmpty else { return (nil, nil) }

        let type = InsightType.locations
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
            boundaryHour: DayBoundaryConfig.locations.boundaryHour
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

        // Build activity data with dominant location color per day
        let targetHours = goals.targetValue(for: "dailyDuration").map { $0 / 60.0 } ?? 4.0
        let activityDays = dailySummaries.map { summary in
            let hours = summary.totalDuration / 3600.0
            let intensity = min(hours / targetHours, 1.0)
            let dominantColor = dominantLocationColor(for: summary) ?? type.color
            return InsightActivityDay(date: summary.date, color: dominantColor, intensity: intensity)
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

    /// Find the color of the dominant location (most time spent) for a day
    /// Only considers time within the active window (6 AM - midnight)
    private static func dominantLocationColor(for summary: LocationDailySummary) -> Color? {
        guard !summary.sessions.isEmpty else { return nil }

        let calendar = Calendar.current

        // Active window: 6 AM to midnight (next day 0 AM)
        let activeStartHour = 6
        let activeEndHour = 24  // midnight

        // Group sessions by location and sum durations within active window
        var durationByLocation: [UUID: (duration: TimeInterval, color: Color)] = [:]
        for session in summary.sessions {
            let activeDuration = durationWithinActiveWindow(
                session: session,
                activeStartHour: activeStartHour,
                activeEndHour: activeEndHour,
                calendar: calendar
            )
            guard activeDuration > 0 else { continue }

            let existing = durationByLocation[session.locationId]
            let newDuration = (existing?.duration ?? 0) + activeDuration
            durationByLocation[session.locationId] = (newDuration, session.locationColor.swiftUIColor)
        }

        // Find location with maximum duration
        return durationByLocation.values.max(by: { $0.duration < $1.duration })?.color
    }

    /// Calculate how much of a session falls within the active window (e.g., 6 AM - midnight)
    private static func durationWithinActiveWindow(
        session: CachedLocationSession,
        activeStartHour: Int,
        activeEndHour: Int,
        calendar: Calendar
    ) -> TimeInterval {
        let sessionStart = session.startDate
        let sessionEnd = session.endDate ?? Date()

        // Get the day of the session start
        let dayStart = calendar.startOfDay(for: sessionStart)

        // Calculate active window boundaries for this day
        guard let windowStart = calendar.date(bySettingHour: activeStartHour, minute: 0, second: 0, of: dayStart),
              let windowEnd = calendar.date(bySettingHour: activeEndHour % 24, minute: 0, second: 0, of: dayStart) else {
            return session.duration
        }

        // Adjust window end for midnight (add a day if activeEndHour is 24)
        let adjustedWindowEnd = activeEndHour >= 24
            ? calendar.date(byAdding: .day, value: 1, to: windowEnd) ?? windowEnd
            : windowEnd

        // Calculate overlap between session and active window
        let overlapStart = max(sessionStart, windowStart)
        let overlapEnd = min(sessionEnd, adjustedWindowEnd)

        if overlapEnd > overlapStart {
            return overlapEnd.timeIntervalSince(overlapStart)
        }
        return 0
    }
}
