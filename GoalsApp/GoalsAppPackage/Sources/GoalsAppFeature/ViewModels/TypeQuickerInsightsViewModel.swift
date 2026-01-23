import SwiftUI
import GoalsDomain
import GoalsData
import GoalsCore
import GoalsWidgetShared

/// ViewModel for TypeQuicker insights section
@MainActor @Observable
public final class TypeQuickerInsightsViewModel: InsightsSectionViewModel {
    // MARK: - Static Properties

    public let title = "Typing"
    public let systemImage = "keyboard"
    public let color: Color = Color.accentColor
    public let requiresThrottle = true

    // MARK: - Published State

    public private(set) var stats: [TypeQuickerStats] = []
    public private(set) var goals: [Goal] = []
    public private(set) var errorMessage: String?
    public private(set) var fetchStatus: InsightFetchStatus = .idle
    public var selectedMetric: TypeQuickerMetric = .wpm

    // MARK: - Dependencies

    private let dataSource: any TypeQuickerDataSourceProtocol
    private let goalRepository: any GoalRepositoryProtocol

    // MARK: - Initialization

    public init(
        dataSource: any TypeQuickerDataSourceProtocol,
        goalRepository: any GoalRepositoryProtocol
    ) {
        self.dataSource = dataSource
        self.goalRepository = goalRepository
    }

    // MARK: - Computed Properties

    /// Flattened data points for charting by mode
    public var modeChartData: [TypeQuickerModeDataPoint] {
        var points: [TypeQuickerModeDataPoint] = []
        for stat in stats {
            if let byMode = stat.byMode, !byMode.isEmpty {
                for modeStat in byMode {
                    points.append(TypeQuickerModeDataPoint(
                        date: stat.date,
                        mode: modeStat.mode,
                        wpm: modeStat.wordsPerMinute,
                        accuracy: modeStat.accuracy,
                        timeMinutes: modeStat.practiceTimeMinutes
                    ))
                }
            } else {
                points.append(TypeQuickerModeDataPoint(
                    date: stat.date,
                    mode: "overall",
                    wpm: stat.wordsPerMinute,
                    accuracy: stat.accuracy,
                    timeMinutes: stat.practiceTimeMinutes
                ))
            }
        }
        return points
    }

    /// Unique modes present in the data
    public var uniqueModes: [String] {
        Array(Set(modeChartData.map(\.mode))).sorted()
    }

    /// Trend percentage for the selected metric
    public var metricTrend: Double? {
        switch selectedMetric {
        case .wpm:
            return stats.trendPercentage { $0.wordsPerMinute }
        case .accuracy:
            return stats.trendPercentage { $0.accuracy }
        case .time:
            return stats.trendPercentage { Double($0.practiceTimeMinutes) }
        }
    }

    /// Summary data for the overview card (uses shared InsightBuilders for consistency with widgets)
    public var summary: InsightSummary? {
        InsightBuilders.buildTypeQuickerInsight(from: stats, goals: goals).summary
    }

    /// Activity data for GitHub-style contribution chart (uses shared InsightBuilders for consistency with widgets)
    public var activityData: InsightActivityData? {
        InsightBuilders.buildTypeQuickerInsight(from: stats, goals: goals).activityData
    }

    /// Get the goal target for a specific metric
    public func goalTarget(for metric: TypeQuickerMetric) -> Double? {
        goals.targetValue(for: metric.metricKey)
    }

    // MARK: - Chart Data Helpers

    /// Filter mode chart data by time range
    public func filteredModeChartData(for timeRange: TimeRange) -> [TypeQuickerModeDataPoint] {
        let cutoffDate = timeRange.startDate(from: Date())
        return modeChartData.filter { $0.date >= cutoffDate }
    }

    /// Calculate Y-axis range for chart, including goal line if present
    public func chartYAxisRange(for filteredData: [TypeQuickerModeDataPoint], metric: TypeQuickerMetric) -> ClosedRange<Double> {
        var values = filteredData.map { $0.value(for: metric) }

        if let goalTarget = goalTarget(for: metric) {
            values.append(goalTarget)
        }

        guard let minVal = values.min(), let maxVal = values.max() else {
            return 0...100
        }

        let range = maxVal - minVal
        let padding = max(range * 0.15, 1)

        let lower = max(0, minVal - padding)
        let upper = maxVal + padding

        return lower...upper
    }

    /// Get unique modes from filtered data with their average values
    public func modeLegendData(for filteredData: [TypeQuickerModeDataPoint], metric: TypeQuickerMetric) -> [(mode: String, avgValue: Double)] {
        let uniqueModes = Array(Set(filteredData.map(\.mode))).sorted()
        return uniqueModes.map { mode in
            let modePoints = filteredData.filter { $0.mode == mode }
            let avgValue = modePoints.isEmpty ? 0 : modePoints.reduce(0) { $0 + $1.value(for: metric) } / Double(modePoints.count)
            return (mode, avgValue)
        }
    }

    // MARK: - Data Loading

    public func loadCachedData() async {
        // Configure from saved settings if available
        if let username = UserDefaults.standard.typeQuickerUsername, !username.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .typeQuicker,
                credentials: ["username": username]
            )
            try? await dataSource.configure(settings: settings)
        }

        guard await dataSource.isConfigured() else { return }

        let endDate = Date()
        let startDate = TimeRange.all.startDate(from: endDate)

        // Load goals (needed for goal lines on charts)
        goals = (try? await goalRepository.fetch(dataSource: .typeQuicker)) ?? []

        // Load cached stats
        if let cachedStats = try? await dataSource.fetchCachedStats(from: startDate, to: endDate), !cachedStats.isEmpty {
            stats = cachedStats
            fetchStatus = .success
        }
    }

    public func loadData() async {
        errorMessage = nil
        fetchStatus = .loading

        // Configure from saved settings if available
        if let username = UserDefaults.standard.typeQuickerUsername, !username.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .typeQuicker,
                credentials: ["username": username]
            )
            try? await dataSource.configure(settings: settings)
        }

        guard await dataSource.isConfigured() else {
            errorMessage = "Configure your TypeQuicker username in Settings"
            fetchStatus = .error
            return
        }

        let endDate = Date()
        let startDate = TimeRange.all.startDate(from: endDate)

        // Load goals first (needed for goal lines on charts)
        goals = (try? await goalRepository.fetch(dataSource: .typeQuicker)) ?? []

        // Display cached data immediately
        if let cachedStats = try? await dataSource.fetchCachedStats(from: startDate, to: endDate), !cachedStats.isEmpty {
            stats = cachedStats
        }

        // Fetch fresh stats (updates cache internally), then update UI
        do {
            stats = try await dataSource.fetchStats(from: startDate, to: endDate)
            fetchStatus = .success
        } catch {
            // Keep cached data on error
            if stats.isEmpty {
                errorMessage = "Failed to load data: \(error.localizedDescription)"
                fetchStatus = .error
            } else {
                // Have cached data, show success despite fetch error
                fetchStatus = .success
            }
        }
    }
}
