import SwiftUI
import Charts
import GoalsDomain

/// Zotero insights detail view with full charts
struct ZoteroInsightsDetailView: View {
    @Bindable var viewModel: ZoteroInsightsViewModel
    @AppStorage(UserDefaultsKeys.zoteroInsightsTimeRange) private var timeRange: TimeRange = .month

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

                    if filteredData.isEmpty {
                        emptyStateView
                    } else {
                        statsOverview
                        if let readingStatus = viewModel.readingStatus, readingStatus.totalItems > 0 {
                            readingProgressSection(readingStatus)
                        }
                        metricPicker
                        trendChart
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Zotero Progress")
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

    private var filteredData: [ZoteroChartDataPoint] {
        viewModel.filteredChartData(for: timeRange)
    }

    // MARK: - Subviews

    private var headerSection: some View {
        HStack {
            Image(systemName: "books.vertical")
                .foregroundStyle(.purple)
            Text("Zotero Reading")
                .font(.headline)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No Zotero data for this period")
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
                    title: "Current Streak",
                    value: "\(viewModel.currentStreak)",
                    unit: "days",
                    icon: "flame.fill",
                    color: .orange
                )
                statCard(
                    title: "Longest Streak",
                    value: "\(viewModel.longestStreak)",
                    unit: "days",
                    icon: "trophy.fill",
                    color: .yellow
                )
            }

            HStack(spacing: 16) {
                statCard(
                    title: "Annotations",
                    value: formatNumber(viewModel.totalAnnotations),
                    unit: "items",
                    icon: "pencil.line",
                    color: .purple
                )
                statCard(
                    title: "Notes",
                    value: formatNumber(viewModel.totalNotes),
                    unit: "items",
                    icon: "note.text",
                    color: .blue
                )
            }
        }
    }

    private func readingProgressSection(_ status: ZoteroReadingStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reading Progress")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                readingStatCard(
                    title: "To Read",
                    value: status.toReadCount,
                    icon: "book.closed",
                    color: .gray
                )
                readingStatCard(
                    title: "In Progress",
                    value: status.inProgressCount,
                    icon: "book",
                    color: .orange
                )
                readingStatCard(
                    title: "Read",
                    value: status.readCount,
                    icon: "checkmark.circle",
                    color: .green
                )
            }

            // Progress bar
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    let total = Double(status.totalItems)
                    let readWidth = total > 0 ? (Double(status.readCount) / total) * geometry.size.width : 0
                    let inProgressWidth = total > 0 ? (Double(status.inProgressCount) / total) * geometry.size.width : 0
                    let toReadWidth = geometry.size.width - readWidth - inProgressWidth

                    if readWidth > 0 {
                        Rectangle()
                            .fill(.green)
                            .frame(width: readWidth)
                    }
                    if inProgressWidth > 0 {
                        Rectangle()
                            .fill(.orange)
                            .frame(width: inProgressWidth)
                    }
                    if toReadWidth > 0 {
                        Rectangle()
                            .fill(.gray.opacity(0.3))
                            .frame(width: toReadWidth)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 8)

            Text("\(Int(status.completionPercentage))% completed")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func readingStatCard(title: String, value: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            Text("\(value)")
                .font(.title3)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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

    private var metricPicker: some View {
        Picker("Metric", selection: $viewModel.selectedMetric) {
            ForEach(ZoteroMetric.allCases, id: \.self) { metric in
                Text(metric.displayName).tag(metric)
            }
        }
        .pickerStyle(.segmented)
    }

    private var movingAverageData: [(date: Date, value: Double)] {
        viewModel.movingAverageData(for: filteredData, metric: viewModel.selectedMetric)
    }

    private var trendChart: some View {
        Chart {
            // Scatter plot of raw data points
            ForEach(filteredData) { point in
                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value(viewModel.selectedMetric.displayName, point.value(for: viewModel.selectedMetric))
                )
                .foregroundStyle(.purple.opacity(0.4))
                .symbolSize(30)
            }

            // 30-day moving average line
            ForEach(Array(movingAverageData.enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Moving Avg", point.value)
                )
                .foregroundStyle(.purple)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }

            // Goal target line
            if let goalTarget = viewModel.goalTarget(for: viewModel.selectedMetric) {
                RuleMark(y: .value("Goal", goalTarget))
                    .foregroundStyle(.purple.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Goal: \(formatMetricValue(goalTarget, for: viewModel.selectedMetric))")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 4)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
            }
        }
        .frame(height: 200)
        .chartYScale(domain: viewModel.chartYAxisRange(for: filteredData, metric: viewModel.selectedMetric))
        .chartYAxisLabel(viewModel.selectedMetric.yAxisLabel)
        .chartLegend(.hidden)
    }

    // MARK: - Helpers

    private func formatMetricValue(_ value: Double, for metric: ZoteroMetric) -> String {
        String(format: "%.0f items", value)
    }

    private func formatNumber(_ value: Int) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", Double(value) / 1000)
        }
        return "\(value)"
    }
}
