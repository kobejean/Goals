import SwiftUI
import Charts
import GoalsDomain

/// Anki insights detail view with full charts
struct AnkiInsightsDetailView: View {
    @Bindable var viewModel: AnkiInsightsViewModel
    @AppStorage(UserDefaultsKeys.ankiInsightsTimeRange) private var timeRange: TimeRange = .month

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
                        metricPicker
                        trendChart
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Anki Progress")
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

    private var filteredData: [AnkiChartDataPoint] {
        viewModel.filteredChartData(for: timeRange)
    }

    // MARK: - Subviews

    private var headerSection: some View {
        HStack {
            Image(systemName: "rectangle.stack")
                .foregroundStyle(.purple)
            Text("Anki Learning")
                .font(.headline)
            Spacer()
            if let trend = viewModel.metricTrend {
                TrendBadge(trend: trend)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No Anki data for this period")
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
                    title: "Total Reviews",
                    value: formatNumber(viewModel.totalReviews),
                    unit: "cards",
                    icon: "rectangle.stack.fill",
                    color: .purple
                )
                statCard(
                    title: "Avg Retention",
                    value: String(format: "%.1f", viewModel.averageRetention),
                    unit: "%",
                    icon: "checkmark.circle.fill",
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

    private var metricPicker: some View {
        Picker("Metric", selection: $viewModel.selectedMetric) {
            ForEach(AnkiMetric.allCases, id: \.self) { metric in
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
                    .foregroundStyle(.red.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Goal: \(formatMetricValue(goalTarget, for: viewModel.selectedMetric))")
                            .font(.caption2)
                            .foregroundStyle(.red)
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

    private func formatMetricValue(_ value: Double, for metric: AnkiMetric) -> String {
        switch metric {
        case .reviews:
            return String(format: "%.0f cards", value)
        case .studyTime:
            return String(format: "%.0f min", value)
        case .retention:
            return String(format: "%.1f%%", value)
        case .newCards:
            return String(format: "%.0f cards", value)
        }
    }

    private func formatNumber(_ value: Int) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", Double(value) / 1000)
        }
        return "\(value)"
    }
}
