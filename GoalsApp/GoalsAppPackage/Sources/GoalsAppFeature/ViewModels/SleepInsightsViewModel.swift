import SwiftUI
import GoalsDomain
import GoalsData

/// ViewModel for Sleep insights section
@MainActor @Observable
public final class SleepInsightsViewModel: InsightsSectionViewModel {
    // MARK: - Static Properties

    public let title = "Sleep"
    public let systemImage = "bed.double.fill"
    public let color: Color = .indigo

    // MARK: - Published State

    public private(set) var sleepData: [SleepDailySummary] = []
    public private(set) var goals: [Goal] = []
    public private(set) var isAuthorized: Bool = false
    public private(set) var authorizationChecked: Bool = false
    public var selectedMetric: SleepMetric = .duration

    // MARK: - Dependencies

    private let dataSource: any HealthKitSleepDataSourceProtocol
    private let goalRepository: any GoalRepositoryProtocol

    // MARK: - Initialization

    public init(
        dataSource: any HealthKitSleepDataSourceProtocol,
        goalRepository: any GoalRepositoryProtocol
    ) {
        self.dataSource = dataSource
        self.goalRepository = goalRepository
    }

    // MARK: - Computed Properties

    /// Chart data points for time-series visualization
    public var chartData: [SleepChartDataPoint] {
        sleepData.map { SleepChartDataPoint(from: $0) }
    }

    /// Range data points for sleep range chart
    public var rangeData: [SleepRangeDataPoint] {
        sleepData.map { SleepRangeDataPoint(from: $0) }
    }

    /// Last night's sleep summary
    public var lastNightSleep: SleepDailySummary? {
        sleepData.last
    }

    /// Weekly average sleep hours
    public var weeklyAverageHours: Double? {
        let recentData = sleepData.suffix(7)
        guard !recentData.isEmpty else { return nil }
        let total = recentData.reduce(0.0) { $0 + $1.totalSleepHours }
        return total / Double(recentData.count)
    }

    /// Sleep trend (percentage change from first half to second half of data)
    public var sleepTrend: Double? {
        guard sleepData.count >= 4 else { return nil }
        let midpoint = sleepData.count / 2
        let firstHalf = sleepData.prefix(midpoint)
        let secondHalf = sleepData.suffix(midpoint)

        let firstAvg = firstHalf.reduce(0.0) { $0 + $1.totalSleepHours } / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0.0) { $0 + $1.totalSleepHours } / Double(secondHalf.count)

        guard firstAvg > 0 else { return nil }
        return ((secondAvg - firstAvg) / firstAvg) * 100
    }

    /// Summary data for the overview card
    public var summary: InsightSummary? {
        guard !sleepData.isEmpty else { return nil }

        // Limit to last 30 entries for sparkline chart performance
        let recentData = sleepData.suffix(30)
        let dataPoints = recentData.map {
            InsightDataPoint(date: $0.date, value: $0.totalSleepHours)
        }
        let current = sleepData.last?.totalSleepHours ?? 0

        return InsightSummary(
            title: "Sleep",
            systemImage: "bed.double.fill",
            color: .indigo,
            dataPoints: dataPoints,
            currentValueFormatted: formatSleepHours(current),
            trend: sleepTrend,
            goalValue: goalTarget(for: .duration)
        )
    }

    /// Activity data for GitHub-style contribution chart
    public var activityData: InsightActivityData? {
        guard !sleepData.isEmpty else { return nil }

        // Use 8 hours as the "full" intensity reference
        let targetHours = goalTarget(for: .duration) ?? 8.0

        // Limit to last 90 entries for activity chart performance
        let recentData = sleepData.suffix(90)
        let days = recentData.map { summary in
            let intensity = min(summary.totalSleepHours / targetHours, 1.0)

            return InsightActivityDay(
                date: summary.date,
                color: .indigo,
                intensity: intensity
            )
        }

        return InsightActivityData(days: days, emptyColor: .gray.opacity(0.2))
    }

    /// Get the goal target for a specific metric
    public func goalTarget(for metric: SleepMetric) -> Double? {
        goals.targetValue(for: metric.metricKey)
    }

    // MARK: - Authorization

    public func requestAuthorization() async {
        do {
            isAuthorized = try await dataSource.requestAuthorization()
            authorizationChecked = true
            if isAuthorized {
                await loadData()
            }
        } catch {
            isAuthorized = false
            authorizationChecked = true
        }
    }

    // MARK: - Data Loading

    public func loadData() async {
        let endDate = Date()
        let startDate = TimeRange.all.startDate(from: endDate)

        // Load cached data FIRST (doesn't require HealthKit authorization)
        // This allows immediate display while authorization/fetch happens
        if let cachedData = try? await dataSource.fetchCachedSleepData(from: startDate, to: endDate), !cachedData.isEmpty {
            sleepData = cachedData
        }

        // Load goals (needed for goal lines on charts)
        goals = (try? await goalRepository.fetch(dataSource: .healthKitSleep)) ?? []

        // Now request authorization (may show system prompt)
        do {
            isAuthorized = try await dataSource.requestAuthorization()
        } catch {
            isAuthorized = false
        }
        authorizationChecked = true

        guard isAuthorized else { return }

        // Fetch fresh data from HealthKit (updates cache internally)
        do {
            sleepData = try await dataSource.fetchSleepData(from: startDate, to: endDate)
        } catch {
            // Keep cached data on error (already displayed above)
        }
    }

    // MARK: - Formatting Helpers

    public func formatSleepHours(_ hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if m == 0 {
            return "\(h)h"
        }
        return "\(h)h \(m)m"
    }

    public func formatTime(hour: Double) -> String {
        let totalMinutes = Int(hour * 60)
        var h = totalMinutes / 60
        let m = totalMinutes % 60

        // Handle negative hours (evening times like -2 for 10 PM)
        if h < 0 {
            h += 24
        }

        let period = h >= 12 ? "PM" : "AM"
        let displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h)

        if m == 0 {
            return "\(displayHour) \(period)"
        }
        return String(format: "%d:%02d %@", displayHour, m, period)
    }
}
