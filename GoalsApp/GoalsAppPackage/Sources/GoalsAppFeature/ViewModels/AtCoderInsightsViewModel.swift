import SwiftUI
import GoalsDomain
import GoalsData

/// ViewModel for AtCoder insights section
@MainActor @Observable
public final class AtCoderInsightsViewModel: InsightsSectionViewModel {
    // MARK: - Published State

    public private(set) var stats: AtCoderStats?
    public private(set) var contestHistory: [AtCoderStats] = []
    public private(set) var dailyEffort: [AtCoderDailyEffort] = []
    public private(set) var goals: [Goal] = []
    public private(set) var isLoading = true
    public private(set) var errorMessage: String?

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
        guard let goal = goals.first(where: { $0.metricKey == "rating" && !$0.isArchived }) else {
            return nil
        }
        return Int(goal.targetValue)
    }

    /// Filter contest history by time range
    public func filteredContestHistory(for timeRange: TimeRange) -> [AtCoderStats] {
        let cutoffDate = timeRange.startDate(from: Date())
        return contestHistory.filter { $0.date >= cutoffDate }
    }

    /// Filter daily effort by time range
    public func filteredDailyEffort(for timeRange: TimeRange) -> [AtCoderDailyEffort] {
        let cutoffDate = timeRange.startDate(from: Date())
        return dailyEffort.filter { $0.date >= cutoffDate }
    }

    // MARK: - Data Loading

    public func loadData(timeRange: TimeRange) async {
        isLoading = true
        errorMessage = nil

        // Configure from saved settings if available
        if let username = UserDefaults.standard.string(forKey: "atCoderUsername"), !username.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .atCoder,
                credentials: ["username": username]
            )
            try? await dataSource.configure(settings: settings)
        }

        // Check if configured
        guard await dataSource.isConfigured() else {
            errorMessage = "Configure your AtCoder username in Settings"
            isLoading = false
            return
        }

        do {
            // Fetch data concurrently - always fetch a year of data for filtering
            let yearStart = TimeRange.year.startDate(from: Date())
            async let statsTask = dataSource.fetchStats()
            async let effortTask = dataSource.fetchDailyEffort(from: yearStart)
            async let historyTask = dataSource.fetchContestHistory()
            async let goalsTask = goalRepository.fetch(dataSource: .atCoder)

            stats = try await statsTask
            dailyEffort = try await effortTask
            contestHistory = try await historyTask
            goals = try await goalsTask
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - InsightsSectionViewModel

    public func makeSection(timeRange: TimeRange) -> AnyView {
        AnyView(AtCoderInsightsSection(viewModel: self, timeRange: timeRange))
    }
}
