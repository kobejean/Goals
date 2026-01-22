import SwiftUI
import GoalsDomain
import GoalsData
import GoalsCore
import GoalsWidgetShared

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
    public private(set) var errorMessage: String?
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
        sleepData.halfTrendPercentage { $0.totalSleepHours }
    }

    /// Summary data for the overview card (uses shared InsightBuilders for consistency with widgets)
    public var summary: InsightSummary? {
        InsightBuilders.buildSleepInsight(from: sleepData, goals: goals).summary
    }

    /// Activity data for GitHub-style contribution chart (uses shared InsightBuilders for consistency with widgets)
    public var activityData: InsightActivityData? {
        InsightBuilders.buildSleepInsight(from: sleepData, goals: goals).activityData
    }

    /// Get the goal target for a specific metric
    public func goalTarget(for metric: SleepMetric) -> Double? {
        goals.targetValue(for: metric.metricKey)
    }

    // MARK: - Chart Data Helpers

    /// Filter sleep data by time range with performance limit
    public func filteredSleepData(for timeRange: TimeRange) -> [SleepDailySummary] {
        let cutoffDate = timeRange.startDate(from: Date())
        let filtered = sleepData.filter { $0.date >= cutoffDate }

        // For "all" time range, limit to most recent 90 entries for chart performance
        if timeRange == .all && filtered.count > 90 {
            return Array(filtered.suffix(90))
        }
        return filtered
    }

    /// Filter range data for sleep schedule chart (limited to 30 for readability)
    public func filteredRangeData(for timeRange: TimeRange) -> [SleepRangeDataPoint] {
        let filtered = filteredSleepData(for: timeRange)
        let dataToShow = filtered.count > 30 ? Array(filtered.suffix(30)) : filtered
        return dataToShow.map { SleepRangeDataPoint(from: $0) }
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
        errorMessage = nil
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
            // Keep cached data on error
            if sleepData.isEmpty {
                errorMessage = "Failed to load sleep data: \(error.localizedDescription)"
            }
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
