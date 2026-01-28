import SwiftUI
import GoalsDomain
import GoalsData
import GoalsCore
import GoalsWidgetShared

/// ViewModel for Zotero insights section
@MainActor @Observable
public final class ZoteroInsightsViewModel: InsightsSectionViewModel {
    // MARK: - Static Properties

    public let title = "Zotero"
    public let systemImage = "books.vertical"
    public let color: Color = .purple
    public let requiresThrottle = true

    // MARK: - Published State

    public private(set) var stats: [ZoteroDailyStats] = []
    public private(set) var readingStatus: ZoteroReadingStatus?
    public private(set) var goals: [Goal] = []
    public private(set) var insight: (summary: InsightSummary?, activityData: InsightActivityData?) = (nil, nil)
    public private(set) var errorMessage: String?
    public private(set) var fetchStatus: InsightFetchStatus = .idle
    public var selectedMetric: ZoteroMetric = .totalActivity

    // MARK: - Dependencies

    private let dataSource: any ZoteroDataSourceProtocol
    private let goalRepository: any GoalRepositoryProtocol

    // MARK: - Initialization

    public init(
        dataSource: any ZoteroDataSourceProtocol,
        goalRepository: any GoalRepositoryProtocol
    ) {
        self.dataSource = dataSource
        self.goalRepository = goalRepository
    }

    // MARK: - Computed Properties

    /// Current streak (consecutive days with annotations/notes)
    public var currentStreak: Int {
        stats.currentStreak()
    }

    /// Longest streak ever recorded
    public var longestStreak: Int {
        stats.longestStreak()
    }

    /// Total annotations in the loaded period
    public var totalAnnotations: Int {
        stats.reduce(0) { $0 + $1.annotationCount }
    }

    /// Total notes in the loaded period
    public var totalNotes: Int {
        stats.reduce(0) { $0 + $1.noteCount }
    }

    /// Total activity (annotations + notes)
    public var totalActivity: Int {
        stats.reduce(0) { $0 + $1.totalActivity }
    }

    /// Trend percentage for the selected metric
    public var metricTrend: Double? {
        switch selectedMetric {
        case .annotations:
            return stats.trendPercentage { Double($0.annotationCount) }
        case .notes:
            return stats.trendPercentage { Double($0.noteCount) }
        case .totalActivity:
            return stats.trendPercentage { $0.weightedPoints }
        case .readingProgress:
            return stats.trendPercentage { $0.readingProgressScore }
        }
    }

    /// Summary data for the overview card
    public var summary: InsightSummary? { insight.summary }

    /// Activity data for GitHub-style contribution chart
    public var activityData: InsightActivityData? { insight.activityData }

    /// Rebuild insight from current data
    private func rebuildInsight() {
        insight = ZoteroInsightProvider.build(from: stats, readingStatus: readingStatus, goals: goals)
    }

    /// Get the goal target for a specific metric
    public func goalTarget(for metric: ZoteroMetric) -> Double? {
        goals.targetValue(for: metric.metricKey)
    }

    // MARK: - Chart Data Helpers

    /// Chart data points for the selected metric
    public var chartData: [ZoteroChartDataPoint] {
        stats.map { stat in
            ZoteroChartDataPoint(
                date: stat.date,
                annotations: stat.annotationCount,
                notes: stat.noteCount,
                readingProgressScore: stat.readingProgressScore
            )
        }
    }

    /// Filter chart data by time range
    public func filteredChartData(for timeRange: TimeRange) -> [ZoteroChartDataPoint] {
        let cutoffDate = timeRange.startDate(from: Date())
        return chartData.filter { $0.date >= cutoffDate }
    }

    /// Calculate 30-day moving average for filtered chart data
    public func movingAverageData(for filteredData: [ZoteroChartDataPoint], metric: ZoteroMetric) -> [(date: Date, value: Double)] {
        let data = filteredData.map { (date: $0.date, value: $0.value(for: metric)) }
        return InsightCalculations.calculateMovingAverage(for: data, window: 30)
    }

    /// Calculate Y-axis range for chart, including goal line if present
    public func chartYAxisRange(for filteredData: [ZoteroChartDataPoint], metric: ZoteroMetric) -> ClosedRange<Double> {
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

    public func loadCachedData() async {
        // Configure from saved settings if available
        if let apiKey = UserDefaults.standard.zoteroAPIKey, !apiKey.isEmpty,
           let userID = UserDefaults.standard.zoteroUserID, !userID.isEmpty {
            let toReadCollection = UserDefaults.standard.zoteroToReadCollection ?? ""
            let inProgressCollection = UserDefaults.standard.zoteroInProgressCollection ?? ""
            let readCollection = UserDefaults.standard.zoteroReadCollection ?? ""
            let settings = DataSourceSettings(
                dataSourceType: .zotero,
                credentials: ["apiKey": apiKey, "userID": userID],
                options: [
                    "toReadCollection": toReadCollection,
                    "inProgressCollection": inProgressCollection,
                    "readCollection": readCollection
                ]
            )
            try? await dataSource.configure(settings: settings)
        }

        guard await dataSource.isConfigured() else { return }

        let endDate = Date()
        let startDate = TimeRange.all.startDate(from: endDate)

        // Load goals (needed for goal lines on charts)
        goals = (try? await goalRepository.fetch(dataSource: .zotero)) ?? []

        // Load cached data
        if let cachedStats = try? await dataSource.fetchCachedDailyStats(from: startDate, to: endDate), !cachedStats.isEmpty {
            stats = cachedStats
            fetchStatus = .success
        }
        if let cachedStatus = try? await dataSource.fetchCachedReadingStatus() {
            readingStatus = cachedStatus
        }
        rebuildInsight()
    }

    public func loadData() async {
        errorMessage = nil
        fetchStatus = .loading

        // Configure from saved settings if available
        if let apiKey = UserDefaults.standard.zoteroAPIKey, !apiKey.isEmpty,
           let userID = UserDefaults.standard.zoteroUserID, !userID.isEmpty {
            let toReadCollection = UserDefaults.standard.zoteroToReadCollection ?? ""
            let inProgressCollection = UserDefaults.standard.zoteroInProgressCollection ?? ""
            let readCollection = UserDefaults.standard.zoteroReadCollection ?? ""
            let settings = DataSourceSettings(
                dataSourceType: .zotero,
                credentials: ["apiKey": apiKey, "userID": userID],
                options: [
                    "toReadCollection": toReadCollection,
                    "inProgressCollection": inProgressCollection,
                    "readCollection": readCollection
                ]
            )
            try? await dataSource.configure(settings: settings)
        }

        guard await dataSource.isConfigured() else {
            errorMessage = "Configure Zotero in Settings"
            fetchStatus = .error
            return
        }

        let endDate = Date()
        let startDate = TimeRange.all.startDate(from: endDate)

        // Load goals first (needed for goal lines on charts)
        goals = (try? await goalRepository.fetch(dataSource: .zotero)) ?? []

        // Display cached data immediately
        if let cachedStats = try? await dataSource.fetchCachedDailyStats(from: startDate, to: endDate), !cachedStats.isEmpty {
            stats = cachedStats
        }
        if let cachedStatus = try? await dataSource.fetchCachedReadingStatus() {
            readingStatus = cachedStatus
        }
        rebuildInsight()

        // Fetch fresh stats (updates cache internally, including reading status), then update UI
        do {
            stats = try await dataSource.fetchDailyStats(from: startDate, to: endDate)
            readingStatus = try await dataSource.fetchCachedReadingStatus()
            rebuildInsight()
            fetchStatus = .success
        } catch {
            // Keep cached data on error (API might not be available)
            if stats.isEmpty {
                errorMessage = "Unable to connect to Zotero API. Check your API key and User ID."
                fetchStatus = .error
            } else {
                // Have cached data, show success despite fetch error
                fetchStatus = .success
            }
        }
    }
}
