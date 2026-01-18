import SwiftUI
import GoalsDomain
import GoalsData

/// ViewModel for AtCoder insights section
@MainActor @Observable
public final class AtCoderInsightsViewModel: InsightsSectionViewModel {
    // MARK: - Static Properties

    public let title = "AtCoder"
    public let systemImage = "chevron.left.forwardslash.chevron.right"
    public let color: Color = .orange

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

    /// Summary data for the overview card
    public var summary: InsightSummary? {
        guard !contestHistory.isEmpty else { return nil }

        let dataPoints = contestHistory.map {
            InsightDataPoint(
                date: $0.date,
                value: Double($0.rating),
                color: $0.rankColor.swiftUIColor
            )
        }
        let current = stats?.rating ?? contestHistory.last?.rating ?? 0
        let trend = calculateRatingTrend()

        return InsightSummary(
            title: "AtCoder",
            systemImage: "chevron.left.forwardslash.chevron.right",
            color: stats?.rankColor.swiftUIColor ?? .gray,
            dataPoints: dataPoints,
            currentValueFormatted: "\(current)",
            trend: trend,
            goalValue: ratingGoalTarget.map { Double($0) }
        )
    }

    /// Calculate rating trend percentage
    private func calculateRatingTrend() -> Double? {
        guard contestHistory.count >= 2 else { return nil }
        let first = Double(contestHistory.first!.rating)
        let last = Double(contestHistory.last!.rating)
        guard first > 0 else { return nil }
        return ((last - first) / first) * 100
    }

    /// Activity data for GitHub-style contribution chart
    public var activityData: InsightActivityData? {
        guard !dailyEffort.isEmpty else { return nil }

        let days = dailyEffort.map { effort in
            // Find hardest difficulty solved that day
            let hardest = effort.submissionsByDifficulty.keys
                .sorted { $0.sortOrder > $1.sortOrder }
                .first ?? .gray

            return InsightActivityDay(
                date: effort.date,
                color: hardest.swiftUIColor,
                intensity: min(1.0, Double(effort.totalSubmissions) / 10.0)
            )
        }

        return InsightActivityData(days: days, emptyColor: .gray.opacity(0.2))
    }

    // MARK: - Data Loading

    public func loadData() async {
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

    public func makeDetailView() -> AnyView {
        AnyView(AtCoderInsightsDetailView(viewModel: self))
    }
}
