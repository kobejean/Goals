import SwiftUI
import Charts
import GoalsDomain

/// Sleep insights detail view with full charts and stage breakdown
struct SleepInsightsDetailView: View {
    @Bindable var viewModel: SleepInsightsViewModel
    @State private var timeRange: TimeRange = .month

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !viewModel.authorizationChecked {
                    loadingView
                } else if !viewModel.isAuthorized {
                    authorizationRequestView
                } else if viewModel.sleepData.isEmpty {
                    emptyStateView
                } else if filteredData.isEmpty {
                    noDataInRangeView
                } else {
                    summaryCards
                    sleepRangeSection
                    stageBreakdownSection
                }
            }
            .padding()
        }
        .navigationTitle("Sleep")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.isAuthorized && !viewModel.sleepData.isEmpty {
                ToolbarItem(placement: .principal) {
                    Picker("Time Range", selection: $timeRange) {
                        ForEach([TimeRange.month, .quarter, .year, .all], id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
            }
        }
    }

    // MARK: - Filtered Data

    private var filteredData: [SleepDailySummary] {
        let cutoffDate = timeRange.startDate(from: Date())
        let filtered = viewModel.sleepData.filter { $0.date >= cutoffDate }

        // For "all" time range, limit to most recent 90 entries for chart performance
        if timeRange == .all && filtered.count > 90 {
            return Array(filtered.suffix(90))
        }
        return filtered
    }

    private var filteredRangeData: [SleepRangeDataPoint] {
        // For range chart, limit to most recent 30 entries for readability
        let dataToShow = filteredData.count > 30 ? Array(filteredData.suffix(30)) : filteredData
        return dataToShow.map { SleepRangeDataPoint(from: $0) }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Checking authorization...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var authorizationRequestView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 48))
                .foregroundStyle(.indigo)

            Text("Sleep Data Access")
                .font(.headline)

            Text("Grant access to view your sleep data from the Health app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.requestAuthorization()
                }
            } label: {
                Label("Enable Sleep Tracking", systemImage: "checkmark.shield")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No sleep data")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Sleep data will appear here once recorded in the Health app.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var noDataInRangeView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No sleep data in this range")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let lastDate = viewModel.sleepData.last?.date {
                Text("Last recorded: \(lastDate, format: .dateTime.month().day().year())")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Button {
                timeRange = .all
            } label: {
                Text("Show All Data")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.indigo)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var summaryCards: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "bed.double.fill")
                    .foregroundStyle(.indigo)
                Text("Sleep Summary")
                    .font(.headline)
                Spacer()
                if let trend = viewModel.sleepTrend {
                    TrendBadge(trend: trend)
                }
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                summaryCard(
                    title: "Last Night",
                    value: viewModel.lastNightSleep.map { viewModel.formatSleepHours($0.totalSleepHours) } ?? "-",
                    icon: "moon.fill"
                )
                summaryCard(
                    title: "Weekly Avg",
                    value: viewModel.weeklyAverageHours.map { viewModel.formatSleepHours($0) } ?? "-",
                    icon: "chart.bar"
                )
                summaryCard(
                    title: "Efficiency",
                    value: viewModel.lastNightSleep.map { String(format: "%.0f%%", $0.averageEfficiency) } ?? "-",
                    icon: "percent"
                )
            }
        }
    }

    private func summaryCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.indigo)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var sleepRangeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep Schedule")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SleepRangeChart(
                data: filteredRangeData,
                showStages: false,
                goalBedtime: viewModel.goalTarget(for: .bedtime),
                goalWakeTime: viewModel.goalTarget(for: .wakeTime)
            )
        }
    }

    private var stageBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last Night's Stages")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SleepStagesChart(summary: viewModel.lastNightSleep)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        // Create a mock view model for preview
        let viewModel = SleepInsightsViewModel(
            dataSource: MockHealthKitSleepDataSource(),
            goalRepository: MockGoalRepository()
        )

        SleepInsightsDetailView(viewModel: viewModel)
    }
}

// MARK: - Mock Data Sources for Preview

private actor MockHealthKitSleepDataSource: HealthKitSleepDataSourceProtocol {
    nonisolated var dataSourceType: DataSourceType { .healthKitSleep }
    nonisolated var availableMetrics: [MetricInfo] { [] }

    nonisolated func metricValue(for key: String, from stats: Any) -> Double? { nil }

    func isConfigured() async -> Bool { true }
    func configure(settings: DataSourceSettings) async throws {}
    func clearConfiguration() async throws {}
    func fetchLatestMetricValue(for metricKey: String) async throws -> Double? { nil }
    func fetchSleepData(from: Date, to: Date) async throws -> [SleepDailySummary] { [] }
    func fetchLatestSleep() async throws -> SleepDailySummary? { nil }
    func requestAuthorization() async throws -> Bool { true }
    func isAuthorized() async -> Bool { true }
}

private actor MockGoalRepository: GoalRepositoryProtocol {
    func fetchAll() async throws -> [Goal] { [] }
    func fetchActive() async throws -> [Goal] { [] }
    func fetchArchived() async throws -> [Goal] { [] }
    func fetch(id: UUID) async throws -> Goal? { nil }
    func fetch(dataSource: DataSourceType) async throws -> [Goal] { [] }
    @discardableResult func create(_ goal: Goal) async throws -> Goal { goal }
    @discardableResult func update(_ goal: Goal) async throws -> Goal { goal }
    func delete(id: UUID) async throws {}
    func archive(id: UUID) async throws {}
    func unarchive(id: UUID) async throws {}
    func updateProgress(goalId: UUID, currentValue: Double) async throws {}
}
