import SwiftUI
import GoalsDomain
import GoalsData
import GoalsCore

/// ViewModel for Anki insights section
@MainActor @Observable
public final class AnkiInsightsViewModel: InsightsSectionViewModel {
    // MARK: - Static Properties

    public let title = "Anki"
    public let systemImage = "rectangle.stack"
    public let color: Color = .purple

    // MARK: - Published State

    public private(set) var stats: [AnkiDailyStats] = []
    public private(set) var goals: [Goal] = []
    public private(set) var errorMessage: String?
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

    /// Summary data for the overview card
    public var summary: InsightSummary? {
        guard !stats.isEmpty else { return nil }

        // Filter to last 30 days for the card
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let last30DaysStats = stats.filter { $0.date >= cutoffDate }

        // Raw scatter points (last 30 days)
        let scatterPoints = last30DaysStats.map {
            InsightDataPoint(date: $0.date, value: Double($0.reviewCount))
        }

        // Calculate 30-day moving average for all stats, then filter to last 30 days
        let allMovingAverage = calculateMovingAverage(for: stats.map { (date: $0.date, value: Double($0.reviewCount)) }, window: 30)
        let movingAveragePoints = allMovingAverage.filter { $0.date >= cutoffDate }.map {
            InsightDataPoint(date: $0.date, value: $0.value)
        }

        return InsightSummary(
            title: "Anki",
            systemImage: "rectangle.stack",
            color: .purple,
            scatterPoints: scatterPoints,
            movingAveragePoints: movingAveragePoints,
            currentValueFormatted: "\(currentStreak) day streak",
            trend: metricTrend,
            goalValue: goalTarget(for: .reviews)
        )
    }

    /// Calculate moving average for a series of data points
    /// Days with no data are treated as 0
    private func calculateMovingAverage(for data: [(date: Date, value: Double)], window: Int) -> [(date: Date, value: Double)] {
        guard !data.isEmpty else { return [] }

        let calendar = Calendar.current
        let sorted = data.sorted { $0.date < $1.date }

        // Create a lookup dictionary for values by date
        var valuesByDate: [Date: Double] = [:]
        for point in sorted {
            let day = calendar.startOfDay(for: point.date)
            valuesByDate[day] = point.value
        }

        // Get the date range
        guard let firstDate = sorted.first?.date,
              let lastDate = sorted.last?.date else { return [] }

        let startDay = calendar.startOfDay(for: firstDate)
        let endDay = calendar.startOfDay(for: lastDate)

        // Build continuous series with zeros for missing days
        var continuousSeries: [(date: Date, value: Double)] = []
        var currentDay = startDay
        while currentDay <= endDay {
            let value = valuesByDate[currentDay] ?? 0.0
            continuousSeries.append((date: currentDay, value: value))
            currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay) ?? currentDay
        }

        // Calculate moving average
        var result: [(date: Date, value: Double)] = []
        for i in 0..<continuousSeries.count {
            let windowStart = Swift.max(0, i - window + 1)
            let windowData = continuousSeries[windowStart...i]
            let average = windowData.reduce(0.0) { $0 + $1.value } / Double(windowData.count)
            result.append((date: continuousSeries[i].date, value: average))
        }

        return result
    }

    /// Activity data for GitHub-style contribution chart
    public var activityData: InsightActivityData? {
        guard !stats.isEmpty else { return nil }

        // Find max reviews for normalization
        let maxReviews = stats.map(\.reviewCount).max() ?? 1

        let days = stats.map { stat in
            let intensity = Double(stat.reviewCount) / Double(Swift.max(maxReviews, 1))

            return InsightActivityDay(
                date: stat.date,
                color: .purple,
                intensity: intensity
            )
        }

        return InsightActivityData(days: days, emptyColor: .gray.opacity(0.2))
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
        return calculateMovingAverage(for: data, window: 30)
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
        } catch {
            // Keep cached data on error (Anki might not be running)
            if stats.isEmpty {
                errorMessage = "Unable to connect to Anki. Make sure Anki is running with AnkiConnect installed."
            }
        }
    }
}
