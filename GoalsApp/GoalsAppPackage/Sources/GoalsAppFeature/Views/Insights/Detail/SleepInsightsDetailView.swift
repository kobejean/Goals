import SwiftUI
import Charts
import GoalsCore
import GoalsDomain
import GoalsWidgetShared

/// Sleep insights detail view with full charts and stage breakdown
struct SleepInsightsDetailView: View {
    @Bindable var viewModel: SleepInsightsViewModel
    @AppStorage(UserDefaultsKeys.sleepInsightsTimeRange) private var timeRange: TimeRange = .month

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Unable to Load", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                } else if !viewModel.authorizationChecked {
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
        viewModel.filteredSleepData(for: timeRange)
    }

    private var filteredRangeData: [SleepRangeDataPoint] {
        viewModel.filteredRangeData(for: timeRange)
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

            ScheduleChart(
                data: sleepScheduleChartData,
                style: .full,
                configuration: sleepChartConfiguration
            )
        }
    }

    // MARK: - Sleep Schedule Chart Data

    /// Convert filtered range data to InsightDurationRangeData for the schedule chart
    /// Sleep sessions that cross the 4 PM boundary will be properly split across multiple days.
    private var sleepScheduleChartData: InsightDurationRangeData {
        let dataPoints = filteredRangeData.toDurationRangeDataPoints(color: .indigo)

        return InsightDurationRangeData(
            dataPoints: dataPoints,
            defaultColor: .indigo,
            useSimpleHours: false,  // Use overnight scale (-6 to +12)
            boundaryHour: DayBoundaryConfig.sleep.boundaryHour
        )
    }

    /// Configuration with goal lines for sleep chart
    private var sleepChartConfiguration: ScheduleChartConfiguration {
        var goalLines: [ScheduleGoalLine] = []

        // Add bedtime goal line
        if let bedtime = viewModel.goalTarget(for: .bedtime) {
            // Convert hour of day to chart value (PM hours become negative)
            let chartValue = bedtime < 12 ? bedtime : bedtime - 24
            goalLines.append(ScheduleGoalLine(value: chartValue, label: "Bedtime", color: .red))
        }

        // Add wake time goal line
        if let wakeTime = viewModel.goalTarget(for: .wakeTime) {
            goalLines.append(ScheduleGoalLine(value: wakeTime, label: "Wake", color: .orange))
        }

        return ScheduleChartConfiguration(
            goalLines: goalLines,
            chartHeight: 200
        )
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
        let viewModel = SleepInsightsViewModel(
            dataSource: PreviewHealthKitSleepDataSource(),
            goalRepository: PreviewGoalRepository()
        )
        SleepInsightsDetailView(viewModel: viewModel)
    }
}
