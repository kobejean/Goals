import SwiftUI
import Charts
import GoalsDomain
import GoalsWidgetShared

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

            ScheduleChart(
                data: scheduleChartData,
                style: .full,
                configuration: ScheduleChartConfiguration(
                    legendItems: tasksWithData.map { task in
                        ScheduleLegendItem(name: task.name, color: task.color.swiftUIColor)
                    },
                    chartHeight: 220
                )
            )
        }
    }

    // MARK: - Schedule Chart Data Conversion

    /// Convert filtered summaries to InsightDurationRangeData for the schedule chart
    private var scheduleChartData: InsightDurationRangeData {
        let dataPoints = filteredSummaries.compactMap { summary -> DurationRangeDataPoint? in
            let segments = summary.sessions.compactMap { session -> DurationSegment? in
                // Use referenceDate for active sessions
                let endDate = session.endDate ?? viewModel.referenceDate

                // Skip if session started after reference date
                guard session.startDate <= viewModel.referenceDate else { return nil }

                return DurationSegment(
                    startTime: session.startDate,
                    endTime: endDate,
                    color: session.taskColor.swiftUIColor,
                    label: session.taskName
                )
            }
            guard !segments.isEmpty else { return nil }
            return DurationRangeDataPoint(date: summary.date, segments: segments)
        }

        // Calculate date range for last 7 days with padding
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -6, to: today)!
        let paddedStart = calendar.date(byAdding: .hour, value: -12, to: startDate)!
        let paddedEnd = calendar.date(byAdding: .hour, value: 18, to: today)!

        return InsightDurationRangeData(
            dataPoints: dataPoints,
            defaultColor: .orange,
            dateRange: DateRange(start: paddedStart, end: paddedEnd),
            useSimpleHours: true
        )
    }

    /// Tasks that have data in the current filtered summaries
    private var tasksWithData: [TaskDefinition] {
        let taskIds = Set(filteredSummaries.flatMap { $0.sessions.map(\.taskId) })
        return viewModel.tasks.filter { taskIds.contains($0.id) }
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
