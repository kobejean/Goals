import SwiftUI
import GoalsDomain
import GoalsData

/// ViewModel for TypeQuicker insights section
@MainActor @Observable
public final class TypeQuickerInsightsViewModel: InsightsSectionViewModel {
    // MARK: - Static Properties

    public let title = "Typing"
    public let systemImage = "keyboard"
    public let color: Color = Color.accentColor

    // MARK: - Published State

    public private(set) var stats: [TypeQuickerStats] = []
    public private(set) var goals: [Goal] = []
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

    /// Summary data for the overview card
    public var summary: InsightSummary? {
        guard !stats.isEmpty else { return nil }

        let dataPoints = stats.map {
            InsightDataPoint(date: $0.date, value: $0.wordsPerMinute)
        }
        let current = stats.last?.wordsPerMinute ?? 0

        return InsightSummary(
            title: "Typing",
            systemImage: "keyboard",
            color: Color.accentColor,
            dataPoints: dataPoints,
            currentValueFormatted: String(format: "%.0f WPM", current),
            trend: metricTrend,
            goalValue: goalTarget(for: .wpm)
        )
    }

    /// Activity data for GitHub-style contribution chart
    public var activityData: InsightActivityData? {
        guard !stats.isEmpty else { return nil }

        // Find max practice time for normalization
        let maxTime = stats.map(\.practiceTimeMinutes).max() ?? 1

        let days = stats.map { stat in
            let intensity = Double(stat.practiceTimeMinutes) / Double(max(maxTime, 1))

            return InsightActivityDay(
                date: stat.date,
                color: Color.accentColor,
                intensity: intensity
            )
        }

        return InsightActivityData(days: days, emptyColor: .gray.opacity(0.2))
    }

    /// Get the goal target for a specific metric
    public func goalTarget(for metric: TypeQuickerMetric) -> Double? {
        let metricKey: String
        switch metric {
        case .wpm: metricKey = "wpm"
        case .accuracy: metricKey = "accuracy"
        case .time: metricKey = "practiceTime"
        }
        return goals.first { $0.metricKey == metricKey && !$0.isArchived }?.targetValue
    }

    // MARK: - Data Loading

    public func loadData() async {
        // Configure from saved settings if available
        if let username = UserDefaults.standard.string(forKey: "typeQuickerUsername"), !username.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .typeQuicker,
                credentials: ["username": username]
            )
            try? await dataSource.configure(settings: settings)
        }

        guard await dataSource.isConfigured() else {
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
        } catch {
            // Keep cached data on error (already displayed above)
        }
    }

    // MARK: - InsightsSectionViewModel

    public func makeDetailView() -> AnyView {
        AnyView(TypeQuickerInsightsDetailView(viewModel: self))
    }
}
