import SwiftUI
import Charts
import GoalsDomain

/// Tasks insights detail view with charts and breakdown
struct TasksInsightsDetailView: View {
    @Bindable var viewModel: TasksInsightsViewModel
    @AppStorage(UserDefaultsKeys.tasksInsightsTimeRange) private var timeRange: TimeRange = .month

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Unable to Load", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                } else if viewModel.sessions.isEmpty {
                    emptyStateView
                } else if filteredSummaries.isEmpty {
                    noDataInRangeView
                } else {
                    scheduleChartSection
                    taskDistributionSection
                }
            }
            .padding()
        }
        .navigationTitle("Tasks")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.sessions.isEmpty {
                ToolbarItem(placement: .principal) {
                    Picker("Time Range", selection: $timeRange) {
                        ForEach([TimeRange.week, .month, .quarter, .year, .all], id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
            }
        }
        .task {
            await viewModel.loadData()
            viewModel.startLiveUpdates()
        }
        .onDisappear {
            viewModel.stopLiveUpdates()
        }
    }

    // MARK: - Filtered Data

    private var filteredSummaries: [TaskDailySummary] {
        viewModel.filteredDailySummaries(for: timeRange)
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Task Data")
                .font(.headline)

            Text("Start tracking tasks to see your insights here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
            Text("No task data in this range")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let lastDate = viewModel.dailySummaries.last?.date {
                Text("Last tracked: \(lastDate, format: .dateTime.month().day().year())")
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
            .tint(.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var scheduleChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Schedule")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TaskScheduleChart(
                summaries: filteredSummaries,
                tasks: viewModel.tasks,
                referenceDate: viewModel.referenceDate
            )
        }
    }

    private var taskDistributionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time Distribution (\(timeRange.displayName))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TaskDistributionChart(
                summaries: filteredSummaries,
                tasks: viewModel.tasks,
                formatDuration: viewModel.formatDuration
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TasksInsightsDetailView(
            viewModel: TasksInsightsViewModel(
                taskRepository: PreviewTaskRepository(),
                goalRepository: PreviewGoalRepository()
            )
        )
    }
}
