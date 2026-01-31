import SwiftUI
import Charts
import GoalsDomain

/// TensorTonic insights detail view with problem-solving stats
struct TensorTonicInsightsDetailView: View {
    @Bindable var viewModel: TensorTonicInsightsViewModel
    @AppStorage(UserDefaultsKeys.tensorTonicInsightsTimeRange) private var timeRange: TimeRange = .month

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Unable to Load", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                } else {
                    headerSection

                    if viewModel.stats == nil && filteredHeatmap.isEmpty {
                        emptyStateView
                    } else {
                        if viewModel.stats != nil {
                            statsOverview
                            difficultyBreakdown
                        }
                        if !filteredHeatmap.isEmpty {
                            activityChart
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("TensorTonic Progress")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Time Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
        }
    }

    // MARK: - Filtered Data

    private var filteredHeatmap: [TensorTonicHeatmapEntry] {
        viewModel.filteredHeatmap(for: timeRange)
    }

    // MARK: - Subviews

    private var headerSection: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(.pink)
            Text("AI/ML Problem Solving")
                .font(.headline)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No TensorTonic data for this period")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var statsOverview: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                statCard(
                    title: "Total Solved",
                    value: "\(viewModel.totalSolved)",
                    unit: "of \(viewModel.totalProblems)",
                    icon: "checkmark.circle.fill",
                    color: .pink
                )
                statCard(
                    title: "Streak",
                    value: "\(viewModel.currentStreak)",
                    unit: viewModel.currentStreak == 1 ? "day" : "days",
                    icon: "flame.fill",
                    color: .orange
                )
            }

            HStack(spacing: 16) {
                statCard(
                    title: "Research",
                    value: "\(viewModel.researchTotalSolved)",
                    unit: "of \(viewModel.totalResearchProblems)",
                    icon: "doc.text.magnifyingglass",
                    color: .purple
                )
                statCard(
                    title: "Progress",
                    value: String(format: "%.0f", viewModel.progressPercent),
                    unit: "%",
                    icon: "chart.pie.fill",
                    color: .green
                )
            }
        }
    }

    private func statCard(title: String, value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var difficultyBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By Difficulty")
                .font(.subheadline)
                .fontWeight(.medium)

            if let stats = viewModel.stats {
                HStack(spacing: 12) {
                    difficultyPill(
                        label: "Easy",
                        solved: stats.easySolved,
                        total: stats.totalEasyProblems,
                        color: .green
                    )
                    difficultyPill(
                        label: "Medium",
                        solved: stats.mediumSolved,
                        total: stats.totalMediumProblems,
                        color: .yellow
                    )
                    difficultyPill(
                        label: "Hard",
                        solved: stats.hardSolved,
                        total: stats.totalHardProblems,
                        color: .red
                    )
                }
            }
        }
    }

    private func difficultyPill(label: String, solved: Int, total: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(solved)/\(total)")
                .font(.subheadline)
                .fontWeight(.medium)
            ProgressView(value: Double(solved), total: Double(max(total, 1)))
                .tint(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var activityChart: some View {
        Chart {
            // Scatter plot of raw data points
            ForEach(filteredHeatmap, id: \.date) { entry in
                PointMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("Problems", entry.count)
                )
                .foregroundStyle(.pink.opacity(0.4))
                .symbolSize(30)
            }

            // 7-day moving average line
            ForEach(Array(viewModel.movingAverageData(for: filteredHeatmap).enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Moving Avg", point.value)
                )
                .foregroundStyle(.pink)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }
        }
        .frame(height: 200)
        .chartYScale(domain: viewModel.chartYAxisRange(for: filteredHeatmap))
        .chartYAxisLabel("Problems Solved")
        .chartLegend(.hidden)
    }
}
