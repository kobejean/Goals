import SwiftUI
import GoalsDomain
import GoalsCore

/// ViewModel for Tasks insights section
@MainActor @Observable
public final class TasksInsightsViewModel: InsightsSectionViewModel {
    // MARK: - Static Properties

    public let title = "Tasks"
    public let systemImage = "timer"
    public let color: Color = .orange

    // MARK: - Published State

    public private(set) var tasks: [TaskDefinition] = []
    public private(set) var sessions: [TaskSession] = []
    public private(set) var goals: [Goal] = []
    public private(set) var errorMessage: String?

    // MARK: - Dependencies

    private let taskRepository: TaskRepositoryProtocol
    private let goalRepository: GoalRepositoryProtocol

    // MARK: - Initialization

    public init(
        taskRepository: TaskRepositoryProtocol,
        goalRepository: GoalRepositoryProtocol
    ) {
        self.taskRepository = taskRepository
        self.goalRepository = goalRepository
    }

    // MARK: - Computed Properties

    /// Daily summaries grouped by date
    public var dailySummaries: [TaskDailySummary] {
        let calendar = Calendar.current
        var summariesByDate: [Date: [TaskSession]] = [:]

        for session in sessions {
            let day = calendar.startOfDay(for: session.startDate)
            summariesByDate[day, default: []].append(session)
        }

        return summariesByDate.map { date, daySessions in
            TaskDailySummary(date: date, sessions: daySessions, tasks: tasks)
        }.sorted { $0.date < $1.date }
    }

    /// Today's total tracked time in hours
    public var todayTotalHours: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todaySessions = sessions.filter { calendar.startOfDay(for: $0.startDate) == today }
        return todaySessions.totalDuration / 3600.0
    }

    /// Weekly average tracked hours
    public var weeklyAverageHours: Double? {
        let recentData = dailySummaries.suffix(7)
        guard !recentData.isEmpty else { return nil }
        let total = recentData.reduce(0.0) { $0 + $1.totalDuration }
        return (total / Double(recentData.count)) / 3600.0
    }

    /// Tracking trend (percentage change from first half to second half of data)
    public var trackingTrend: Double? {
        dailySummaries.halfTrendPercentage { $0.totalDuration / 3600.0 }
    }

    /// Summary data for the overview card
    public var summary: InsightSummary? {
        guard !sessions.isEmpty else { return nil }

        // Limit to last 14 entries for duration range chart readability
        let recentData = dailySummaries.suffix(14)
        let rangeDataPoints = recentData.map { summary in
            summary.toDurationRangeDataPoint(tasks: tasks)
        }

        let durationRangeData = InsightDurationRangeData(
            dataPoints: rangeDataPoints,
            defaultColor: .orange
        )

        return InsightSummary(
            title: "Tasks",
            systemImage: "timer",
            color: .orange,
            durationRangeData: durationRangeData,
            currentValueFormatted: formatHours(todayTotalHours),
            trend: trackingTrend
        )
    }

    /// Activity data for GitHub-style contribution chart
    public var activityData: InsightActivityData? {
        guard !sessions.isEmpty else { return nil }

        // Use goal target or 4 hours as default "full" intensity reference
        let targetHours = goals.targetValue(for: "dailyDuration").map { $0 / 60.0 } ?? 4.0

        // Limit to last 90 entries for activity chart performance
        let recentData = dailySummaries.suffix(90)
        let days = recentData.map { summary in
            let hours = summary.totalDuration / 3600.0
            let intensity = min(hours / targetHours, 1.0)

            return InsightActivityDay(
                date: summary.date,
                color: .orange,
                intensity: intensity
            )
        }

        return InsightActivityData(days: days, emptyColor: .gray.opacity(0.2))
    }

    /// Get the goal target for a specific metric
    public func goalTarget(for metricKey: String) -> Double? {
        goals.targetValue(for: metricKey)
    }

    // MARK: - Filtered Data

    /// Filter sessions by time range
    public func filteredSessions(for timeRange: TimeRange) -> [TaskSession] {
        let cutoffDate = timeRange.startDate(from: Date())
        let filtered = sessions.filter { $0.startDate >= cutoffDate }

        // For "all" time range, limit to most recent 500 entries
        if timeRange == .all && filtered.count > 500 {
            return Array(filtered.suffix(500))
        }
        return filtered
    }

    /// Filter daily summaries by time range
    public func filteredDailySummaries(for timeRange: TimeRange) -> [TaskDailySummary] {
        let cutoffDate = timeRange.startDate(from: Date())
        let filtered = dailySummaries.filter { $0.date >= cutoffDate }

        // For "all" time range, limit to 90 days for chart performance
        if timeRange == .all && filtered.count > 90 {
            return Array(filtered.suffix(90))
        }
        return filtered
    }

    /// Get duration range data points for a time range (limited to 30 for readability)
    public func filteredRangeData(for timeRange: TimeRange) -> [DurationRangeDataPoint] {
        let filtered = filteredDailySummaries(for: timeRange)
        let dataToShow = filtered.count > 30 ? Array(filtered.suffix(30)) : filtered
        return dataToShow.map { $0.toDurationRangeDataPoint(tasks: tasks) }
    }

    // MARK: - Data Loading

    public func loadData() async {
        errorMessage = nil

        let endDate = Date()
        let startDate = TimeRange.all.startDate(from: endDate)

        do {
            // Load tasks and sessions in parallel
            async let tasksResult = taskRepository.fetchActiveTasks()
            async let sessionsResult = taskRepository.fetchSessions(from: startDate, to: endDate)
            async let goalsResult = goalRepository.fetch(dataSource: .tasks)

            tasks = try await tasksResult
            sessions = try await sessionsResult
            goals = try await goalsResult
        } catch {
            errorMessage = "Failed to load task data: \(error.localizedDescription)"
        }
    }

    // MARK: - Formatting Helpers

    public func formatHours(_ hours: Double) -> String {
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

    public func formatDuration(_ seconds: TimeInterval) -> String {
        formatHours(seconds / 3600.0)
    }
}

// MARK: - Supporting Types

/// Daily summary of task sessions
public struct TaskDailySummary: Identifiable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let sessions: [TaskSession]
    public let tasks: [TaskDefinition]

    public init(date: Date, sessions: [TaskSession], tasks: [TaskDefinition]) {
        self.date = date
        self.sessions = sessions
        self.tasks = tasks
    }

    /// Total tracked duration for the day in seconds
    public var totalDuration: TimeInterval {
        sessions.totalDuration
    }

    /// Sessions grouped by task ID
    public var sessionsByTask: [UUID: [TaskSession]] {
        Dictionary(grouping: sessions) { $0.taskId }
    }

    /// Convert to duration range data point for charting
    public func toDurationRangeDataPoint(tasks: [TaskDefinition]) -> DurationRangeDataPoint {
        let segments = sessions.compactMap { session -> DurationSegment? in
            guard let endDate = session.endDate else { return nil }
            let task = tasks.first { $0.id == session.taskId }
            let color = task?.color.swiftUIColor ?? .orange

            return DurationSegment(
                startTime: session.startDate,
                endTime: endDate,
                color: color,
                label: task?.name
            )
        }

        return DurationRangeDataPoint(date: date, segments: segments)
    }
}

// MARK: - Array Extension for Trend Calculation

extension Array where Element == TaskDailySummary {
    /// Calculate half trend percentage (change from first half to second half)
    func halfTrendPercentage(_ value: (Element) -> Double) -> Double? {
        guard count >= 4 else { return nil }

        let midpoint = count / 2
        let firstHalf = self[0..<midpoint]
        let secondHalf = self[midpoint...]

        let firstAverage = firstHalf.reduce(0.0) { $0 + value($1) } / Double(firstHalf.count)
        let secondAverage = secondHalf.reduce(0.0) { $0 + value($1) } / Double(secondHalf.count)

        guard firstAverage > 0 else { return nil }
        return ((secondAverage - firstAverage) / firstAverage) * 100
    }
}
