import SwiftUI
import GoalsDomain
import GoalsData

/// ViewModel for TypeQuicker insights section
@MainActor @Observable
public final class TypeQuickerInsightsViewModel: InsightsSectionViewModel {
    // MARK: - Published State

    public private(set) var stats: [TypeQuickerStats] = []
    public private(set) var goals: [Goal] = []
    public private(set) var isLoading = true
    public var selectedMetric: ChartMetric = .wpm

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
    public var modeChartData: [ModeDataPoint] {
        var points: [ModeDataPoint] = []
        for stat in stats {
            if let byMode = stat.byMode, !byMode.isEmpty {
                for modeStat in byMode {
                    points.append(ModeDataPoint(
                        date: stat.date,
                        mode: modeStat.mode,
                        wpm: modeStat.wordsPerMinute,
                        accuracy: modeStat.accuracy,
                        timeMinutes: modeStat.practiceTimeMinutes
                    ))
                }
            } else {
                points.append(ModeDataPoint(
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

    /// Y-axis range that includes the goal target if present
    public func chartYAxisRange(for metric: ChartMetric) -> ClosedRange<Double> {
        var values = modeChartData.map { $0.value(for: metric) }

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

    /// Trend percentage for the selected metric
    public var metricTrend: Double? {
        guard stats.count >= 2 else { return nil }
        let first: Double
        let last: Double

        switch selectedMetric {
        case .wpm:
            first = stats.first!.wordsPerMinute
            last = stats.last!.wordsPerMinute
        case .accuracy:
            first = stats.first!.accuracy
            last = stats.last!.accuracy
        case .time:
            first = Double(stats.first!.practiceTimeMinutes)
            last = Double(stats.last!.practiceTimeMinutes)
        }

        guard first > 0 else { return nil }
        return ((last - first) / first) * 100
    }

    /// Get the goal target for a specific metric
    public func goalTarget(for metric: ChartMetric) -> Double? {
        let metricKey: String
        switch metric {
        case .wpm: metricKey = "wpm"
        case .accuracy: metricKey = "accuracy"
        case .time: metricKey = "practiceTime"
        }
        return goals.first { $0.metricKey == metricKey && !$0.isArchived }?.targetValue
    }

    // MARK: - Data Loading

    public func loadData(timeRange: TimeRange) async {
        isLoading = true

        // Configure from saved settings if available
        if let username = UserDefaults.standard.string(forKey: "typeQuickerUsername"), !username.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .typeQuicker,
                credentials: ["username": username]
            )
            try? await dataSource.configure(settings: settings)
        }

        guard await dataSource.isConfigured() else {
            isLoading = false
            return
        }

        do {
            let endDate = Date()
            let startDate = timeRange.startDate(from: endDate)
            async let statsTask = dataSource.fetchStats(from: startDate, to: endDate)
            async let goalsTask = goalRepository.fetch(dataSource: .typeQuicker)

            stats = try await statsTask
            goals = try await goalsTask
        } catch {
            print("Failed to load TypeQuicker data: \(error)")
        }

        isLoading = false
    }

    // MARK: - InsightsSectionViewModel

    public func makeSection(timeRange: TimeRange) -> AnyView {
        AnyView(TypeQuickerInsightsSection(viewModel: self, timeRange: timeRange))
    }
}

// MARK: - Supporting Types

/// Metric options for the TypeQuicker chart
public enum ChartMetric: String, CaseIterable, Sendable {
    case wpm
    case accuracy
    case time

    public var displayName: String {
        switch self {
        case .wpm: return "WPM"
        case .accuracy: return "Accuracy"
        case .time: return "Time"
        }
    }

    public var yAxisLabel: String {
        switch self {
        case .wpm: return "WPM"
        case .accuracy: return "%"
        case .time: return "min"
        }
    }
}

/// Data point for charting mode-specific stats over time
public struct ModeDataPoint: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let mode: String
    public let wpm: Double
    public let accuracy: Double
    public let timeMinutes: Int

    public init(date: Date, mode: String, wpm: Double, accuracy: Double, timeMinutes: Int) {
        self.date = date
        self.mode = mode
        self.wpm = wpm
        self.accuracy = accuracy
        self.timeMinutes = timeMinutes
    }

    public func value(for metric: ChartMetric) -> Double {
        switch metric {
        case .wpm: return wpm
        case .accuracy: return accuracy
        case .time: return Double(timeMinutes)
        }
    }
}
