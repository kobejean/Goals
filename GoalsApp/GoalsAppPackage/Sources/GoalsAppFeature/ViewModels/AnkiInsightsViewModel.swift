import SwiftUI
import GoalsDomain
import GoalsData
import GoalsCore
import GoalsWidgetShared

/// ViewModel for Anki insights section
@MainActor @Observable
public final class AnkiInsightsViewModel: InsightsSectionViewModel {
    // MARK: - Static Properties

    public let title = "Anki"
    public let systemImage = "rectangle.stack"
    public let color: Color = .red

    // MARK: - Published State

    public private(set) var stats: [AnkiDailyStats] = []
    public private(set) var goals: [Goal] = []
    public private(set) var errorMessage: String?
    public private(set) var fetchStatus: InsightFetchStatus = .idle
    public var selectedMetric: AnkiMetric = .reviews

    // MARK: - Dependencies

    private let dataSource: any AnkiDataSourceProtocol
    private let goalRepository: any GoalRepositoryProtocol

    // MARK: - Initialization

    public init(
        dataSource: any AnkiDataSourceProtocol,
        goalRepository: any GoalRepositoryProtocol
    ) {
        self.dataSource = dataSource
        self.goalRepository = goalRepository
    }

    // MARK: - Computed Properties

    /// Current streak (consecutive days with reviews)
    public var currentStreak: Int {
        stats.currentStreak()
    }

    /// Longest streak ever recorded
    public var longestStreak: Int {
        stats.longestStreak()
    }

    /// Total reviews in the loaded period
    public var totalReviews: Int {
        stats.reduce(0) { $0 + $1.reviewCount }
    }

    /// Total study time in minutes
    public var totalStudyTimeMinutes: Double {
        stats.reduce(0.0) { $0 + $1.studyTimeMinutes }
    }

    /// Average retention rate
    public var averageRetention: Double {
        let statsWithReviews = stats.filter { $0.reviewCount > 0 }
        guard !statsWithReviews.isEmpty else { return 0 }
        return statsWithReviews.reduce(0.0) { $0 + $1.retentionRate } / Double(statsWithReviews.count)
    }

    /// Trend percentage for the selected metric
    public var metricTrend: Double? {
        switch selectedMetric {
        case .reviews:
            return stats.trendPercentage { Double($0.reviewCount) }
        case .studyTime:
            return stats.trendPercentage { $0.studyTimeMinutes }
        case .retention:
            return stats.trendPercentage { $0.retentionRate }
        case .newCards:
            return stats.trendPercentage { Double($0.newCardsCount) }
        }
    }

    /// Summary data for the overview card (uses shared InsightBuilders for consistency with widgets)
    public var summary: InsightSummary? {
        InsightBuilders.buildAnkiInsight(from: stats, goals: goals).summary
    }

    /// Activity data for GitHub-style contribution chart (uses shared InsightBuilders for consistency with widgets)
    public var activityData: InsightActivityData? {
        InsightBuilders.buildAnkiInsight(from: stats, goals: goals).activityData
    }

    /// Get the goal target for a specific metric
    public func goalTarget(for metric: AnkiMetric) -> Double? {
        goals.targetValue(for: metric.metricKey)
    }

    // MARK: - Chart Data Helpers

    /// Chart data points for the selected metric
    public var chartData: [AnkiChartDataPoint] {
        stats.map { stat in
            AnkiChartDataPoint(
                date: stat.date,
                reviews: stat.reviewCount,
                studyTimeMinutes: stat.studyTimeMinutes,
                retention: stat.retentionRate,
                newCards: stat.newCardsCount
            )
        }
    }

    /// Filter chart data by time range
    public func filteredChartData(for timeRange: TimeRange) -> [AnkiChartDataPoint] {
        let cutoffDate = timeRange.startDate(from: Date())
        return chartData.filter { $0.date >= cutoffDate }
    }

    /// Calculate 30-day moving average for filtered chart data
    public func movingAverageData(for filteredData: [AnkiChartDataPoint], metric: AnkiMetric) -> [(date: Date, value: Double)] {
        let data = filteredData.map { (date: $0.date, value: $0.value(for: metric)) }
        return InsightBuilders.calculateMovingAverage(for: data, window: 30)
    }

    /// Calculate Y-axis range for chart, including goal line if present
    public func chartYAxisRange(for filteredData: [AnkiChartDataPoint], metric: AnkiMetric) -> ClosedRange<Double> {
        var values = filteredData.map { $0.value(for: metric) }

        if let goalTarget = goalTarget(for: metric) {
            values.append(goalTarget)
        }

        guard let minVal = values.min(), let maxVal = values.max() else {
            return 0...100
        }

        let range = maxVal - minVal
        let padding = Swift.max(range * 0.15, 1)

        let lower = Swift.max(0, minVal - padding)
        let upper = maxVal + padding

        return lower...upper
    }

    // MARK: - Data Loading

    public func loadData() async {
        errorMessage = nil
        fetchStatus = .loading

        // Configure from saved settings if available
        if let host = UserDefaults.standard.ankiHost, !host.isEmpty {
            let port = UserDefaults.standard.ankiPort ?? "8765"
            let decks = UserDefaults.standard.ankiDecks ?? ""
            let settings = DataSourceSettings(
                dataSourceType: .anki,
                options: ["host": host, "port": port, "decks": decks]
            )
            try? await dataSource.configure(settings: settings)
        }

        guard await dataSource.isConfigured() else {
            errorMessage = "Configure Anki connection in Settings"
            fetchStatus = .error
            return
        }

        let endDate = Date()
        let startDate = TimeRange.all.startDate(from: endDate)

        // Load goals first (needed for goal lines on charts)
        goals = (try? await goalRepository.fetch(dataSource: .anki)) ?? []

        // Display cached data immediately
        if let cachedStats = try? await dataSource.fetchCachedDailyStats(from: startDate, to: endDate), !cachedStats.isEmpty {
            stats = cachedStats
        }

        // Fetch fresh stats (updates cache internally), then update UI
        do {
            stats = try await dataSource.fetchDailyStats(from: startDate, to: endDate)
            fetchStatus = .success
        } catch {
            // Keep cached data on error (Anki might not be running)
            if stats.isEmpty {
                errorMessage = "Unable to connect to Anki. Make sure Anki is running with AnkiConnect installed."
                fetchStatus = .error
            } else {
                // Have cached data, show success despite fetch error
                fetchStatus = .success
            }
        }
    }
}
