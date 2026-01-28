import SwiftUI
import GoalsDomain
import GoalsData
import GoalsCore
import GoalsWidgetShared

/// ViewModel for AtCoder insights section
@MainActor @Observable
public final class AtCoderInsightsViewModel: InsightsSectionViewModel {
    // MARK: - Static Properties

    public let title = "AtCoder"
    public let systemImage = "chevron.left.forwardslash.chevron.right"
    public let color: Color = Color.accentColor
    public let requiresThrottle = true

    // MARK: - Published State

    public private(set) var stats: AtCoderCurrentStats?
    public private(set) var contestHistory: [AtCoderContestResult] = []
    public private(set) var dailyEffort: [AtCoderDailyEffort] = []
    public private(set) var goals: [Goal] = []
    public private(set) var insight: (summary: InsightSummary?, activityData: InsightActivityData?) = (nil, nil)
    public private(set) var errorMessage: String?
    public private(set) var fetchStatus: InsightFetchStatus = .idle

    // MARK: - Dependencies

    private let dataSource: any AtCoderDataSourceProtocol
    private let goalRepository: any GoalRepositoryProtocol

    // MARK: - Initialization

    public init(
        dataSource: any AtCoderDataSourceProtocol,
        goalRepository: any GoalRepositoryProtocol
    ) {
        self.dataSource = dataSource
        self.goalRepository = goalRepository
    }

    // MARK: - Computed Properties

    /// Rating goal target if set
    public var ratingGoalTarget: Int? {
        goals.targetValue(for: "rating").map { Int($0) }
    }

    /// Filter contest history by time range
    public func filteredContestHistory(for timeRange: TimeRange) -> [AtCoderContestResult] {
        let cutoffDate = timeRange.startDate(from: Date())
        return contestHistory.filter { $0.date >= cutoffDate }
    }

    /// Filter daily effort by time range
    public func filteredDailyEffort(for timeRange: TimeRange) -> [AtCoderDailyEffort] {
        let cutoffDate = timeRange.startDate(from: Date())
        return dailyEffort.filter { $0.date >= cutoffDate }
    }

    /// Summary data for the overview card
    public var summary: InsightSummary? { insight.summary }

    /// Activity data for GitHub-style contribution chart
    public var activityData: InsightActivityData? { insight.activityData }

    /// Rebuild insight from current data
    private func rebuildInsight() {
        insight = AtCoderInsightProvider.build(from: contestHistory, dailyEffort: dailyEffort, goals: goals)
    }

    // MARK: - Data Loading

    public func loadCachedData() async {
        // Configure from saved settings if available
        if let username = UserDefaults.standard.atCoderUsername, !username.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .atCoder,
                credentials: ["username": username]
            )
            try? await dataSource.configure(settings: settings)
        }

        guard await dataSource.isConfigured() else { return }

        // Load goals
        goals = (try? await goalRepository.fetch(dataSource: .atCoder)) ?? []

        // Load cached data
        if let cachedHistory = try? await dataSource.fetchCachedContestHistory(), !cachedHistory.isEmpty {
            contestHistory = cachedHistory
            if let lastContest = cachedHistory.last {
                stats = AtCoderCurrentStats(from: lastContest)
            }
            fetchStatus = .success
        }
        if let cachedEffort = try? await dataSource.fetchCachedDailyEffort(from: nil), !cachedEffort.isEmpty {
            dailyEffort = cachedEffort
        }
        rebuildInsight()
    }

    public func loadData() async {
        errorMessage = nil
        fetchStatus = .loading

        // Configure from saved settings if available
        if let username = UserDefaults.standard.atCoderUsername, !username.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .atCoder,
                credentials: ["username": username]
            )
            try? await dataSource.configure(settings: settings)
        }

        // Check if configured
        guard await dataSource.isConfigured() else {
            errorMessage = "Configure your AtCoder username in Settings"
            fetchStatus = .error
            return
        }

        // Load goals
        goals = (try? await goalRepository.fetch(dataSource: .atCoder)) ?? []

        // Display cached data immediately
        if let cachedHistory = try? await dataSource.fetchCachedContestHistory(), !cachedHistory.isEmpty {
            contestHistory = cachedHistory
            if let lastContest = cachedHistory.last {
                stats = AtCoderCurrentStats(from: lastContest)
            }
        }
        if let cachedEffort = try? await dataSource.fetchCachedDailyEffort(from: nil), !cachedEffort.isEmpty {
            dailyEffort = cachedEffort
        }
        rebuildInsight()

        // Fetch fresh data (updates cache internally), then update UI
        do {
            // Use combined method to avoid redundant ranking API calls
            async let statsAndHistoryTask = dataSource.fetchStatsAndContestHistory()
            async let effortTask = dataSource.fetchDailyEffort(from: nil)

            let (fetchedStats, fetchedHistory) = try await statsAndHistoryTask
            stats = fetchedStats
            contestHistory = fetchedHistory
            dailyEffort = try await effortTask
            rebuildInsight()
            fetchStatus = .success
        } catch {
            // Keep cached data on error
            if contestHistory.isEmpty {
                errorMessage = "Failed to load data: \(error.localizedDescription)"
                fetchStatus = .error
            } else {
                // Have cached data, show success despite fetch error
                fetchStatus = .success
            }
        }
    }
}
