import SwiftUI
import GoalsDomain
import GoalsData
import GoalsCore
import GoalsWidgetShared

/// ViewModel for TensorTonic insights section
@MainActor @Observable
public final class TensorTonicInsightsViewModel: InsightsSectionViewModel {
    // MARK: - Static Properties

    public let title = "TensorTonic"
    public let systemImage = "brain.head.profile"
    public let color: Color = .pink
    public let requiresThrottle = true

    // MARK: - Published State

    public private(set) var stats: TensorTonicStats?
    public private(set) var heatmap: [TensorTonicHeatmapEntry] = []
    public private(set) var goals: [Goal] = []
    public private(set) var insight: (summary: InsightSummary?, activityData: InsightActivityData?) = (nil, nil)
    public private(set) var errorMessage: String?
    public private(set) var fetchStatus: InsightFetchStatus = .idle

    // MARK: - Dependencies

    private let dataSource: any TensorTonicDataSourceProtocol
    private let goalRepository: any GoalRepositoryProtocol

    // MARK: - Initialization

    public init(
        dataSource: any TensorTonicDataSourceProtocol,
        goalRepository: any GoalRepositoryProtocol
    ) {
        self.dataSource = dataSource
        self.goalRepository = goalRepository
    }

    // MARK: - Computed Properties

    /// Total problems solved (regular track)
    public var totalSolved: Int {
        stats?.totalSolved ?? 0
    }

    /// Total available problems (regular track)
    public var totalProblems: Int {
        guard let stats = stats else { return 0 }
        return stats.totalEasyProblems + stats.totalMediumProblems + stats.totalHardProblems
    }

    /// Progress percentage (regular track)
    public var progressPercent: Double {
        guard totalProblems > 0 else { return 0 }
        return Double(totalSolved) / Double(totalProblems) * 100
    }

    /// Research track progress
    public var researchTotalSolved: Int {
        stats?.researchTotalSolved ?? 0
    }

    /// Total research problems available
    public var totalResearchProblems: Int {
        guard let stats = stats else { return 0 }
        return stats.totalResearchEasyProblems + stats.totalResearchMediumProblems + stats.totalResearchHardProblems
    }

    /// Combined total solved (regular + research)
    public var combinedTotalSolved: Int {
        stats?.combinedTotalSolved ?? 0
    }

    /// Filter heatmap by time range
    public func filteredHeatmap(for timeRange: TimeRange) -> [TensorTonicHeatmapEntry] {
        let cutoffDate = timeRange.startDate(from: Date())
        return heatmap.filter { $0.date >= cutoffDate }
    }

    /// Calculate 7-day moving average for heatmap data
    public func movingAverageData(for filteredData: [TensorTonicHeatmapEntry]) -> [(date: Date, value: Double)] {
        let data = filteredData.map { (date: $0.date, value: Double($0.count)) }
        return InsightCalculations.calculateMovingAverage(for: data, window: 7)
    }

    /// Calculate Y-axis range for chart
    public func chartYAxisRange(for filteredData: [TensorTonicHeatmapEntry]) -> ClosedRange<Double> {
        let values = filteredData.map { Double($0.count) }
        guard let maxVal = values.max() else { return 0...5 }
        let upper = max(maxVal * 1.2, 5)
        return 0...upper
    }

    /// Calculate activity streak (consecutive days with submissions)
    public var currentStreak: Int {
        guard !heatmap.isEmpty else { return 0 }

        let calendar = Calendar.current
        let sortedHeatmap = heatmap.sorted { $0.date > $1.date }
        var streak = 0
        var expectedDate = calendar.startOfDay(for: Date())

        for entry in sortedHeatmap {
            let entryDate = calendar.startOfDay(for: entry.date)

            if entryDate == expectedDate {
                if entry.count > 0 {
                    streak += 1
                    expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
                } else {
                    // Entry exists but no activity - streak broken
                    break
                }
            } else if entryDate < expectedDate {
                // Missing days break the streak
                break
            }
        }

        return streak
    }

    /// Rebuild insight from current data
    private func rebuildInsight() {
        insight = TensorTonicInsightProvider.build(from: stats, heatmap: heatmap, goals: goals)
    }

    // MARK: - Data Loading

    public func loadCachedData() async {
        // Configure from saved settings if available
        if let settings = TensorTonicDataSource.loadSettingsFromUserDefaults() {
            try? await dataSource.configure(settings: settings)
        }

        guard await dataSource.isConfigured() else { return }

        // Load goals
        goals = (try? await goalRepository.fetch(dataSource: .tensorTonic)) ?? []

        // Load cached stats
        if let cachedStats = try? await dataSource.fetchCachedStats() {
            stats = cachedStats
            fetchStatus = .success
        }

        // Load cached heatmap
        let endDate = Date()
        let startDate = TimeRange.all.startDate(from: endDate)
        if let cachedHeatmap = try? await dataSource.fetchCachedHeatmap(from: startDate, to: endDate), !cachedHeatmap.isEmpty {
            heatmap = cachedHeatmap
        }

        rebuildInsight()
    }

    public func loadData() async {
        errorMessage = nil
        fetchStatus = .loading

        // Configure from saved settings if available
        if let settings = TensorTonicDataSource.loadSettingsFromUserDefaults() {
            try? await dataSource.configure(settings: settings)
        }

        guard await dataSource.isConfigured() else {
            errorMessage = "Sign in to TensorTonic in Settings"
            fetchStatus = .error
            return
        }

        // Load goals
        goals = (try? await goalRepository.fetch(dataSource: .tensorTonic)) ?? []

        let endDate = Date()
        let startDate = TimeRange.all.startDate(from: endDate)

        // Display cached data immediately
        if let cachedStats = try? await dataSource.fetchCachedStats() {
            stats = cachedStats
        }
        if let cachedHeatmap = try? await dataSource.fetchCachedHeatmap(from: startDate, to: endDate), !cachedHeatmap.isEmpty {
            heatmap = cachedHeatmap
        }
        rebuildInsight()

        // Fetch fresh data
        do {
            async let statsTask = dataSource.fetchStats()
            async let heatmapTask = dataSource.fetchHeatmap(from: startDate, to: endDate)

            stats = try await statsTask
            heatmap = try await heatmapTask
            rebuildInsight()
            fetchStatus = .success
        } catch is CancellationError {
            // Task was cancelled
        } catch {
            if stats == nil {
                errorMessage = "Failed to load data: \(error.localizedDescription)"
                fetchStatus = .error
            } else {
                // Have cached data, show success
                fetchStatus = .success
            }
        }
    }
}
