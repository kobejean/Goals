import SwiftUI
import Charts
import GoalsDomain

/// Wii Fit insights detail view with full charts
struct WiiFitInsightsDetailView: View {
    @Bindable var viewModel: WiiFitInsightsViewModel
    @AppStorage(UserDefaultsKeys.wiiFitInsightsTimeRange) private var timeRange: TimeRange = .month

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
        .navigationTitle("Wii Fit Progress")
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

    private var filteredData: [WiiFitChartDataPoint] {
        viewModel.filteredChartData(for: timeRange)
    }

    // MARK: - Subviews

    private var headerSection: some View {
        HStack {
            Image(systemName: "scalemass.fill")
                .foregroundStyle(.cyan)
            Text("Wii Fit Body Tracking")
                .font(.headline)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No Wii Fit data for this period")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var statsOverview: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                if let weight = viewModel.latestWeight {
                    statCard(
                        title: "Current Weight",
                        value: String(format: "%.1f", weight),
                        unit: "kg",
                        icon: "scalemass.fill",
                        color: .cyan
                    )
                }
                if let bmi = viewModel.latestBMI {
                    statCard(
                        title: "BMI",
                        value: String(format: "%.1f", bmi),
                        unit: "",
                        icon: "figure.stand",
                        color: bmiColor(for: bmi)
                    )
                }
            }

            HStack(spacing: 16) {
                if let weeklyChange = viewModel.weeklyWeightChange {
                    statCard(
                        title: "7-Day Change",
                        value: String(format: "%+.1f", weeklyChange),
                        unit: "kg",
                        icon: weeklyChange < 0 ? "arrow.down.right" : "arrow.up.right",
                        color: .orange
                    )
                }
                if let balance = viewModel.latestBalance {
                    statCard(
                        title: "Balance",
                        value: String(format: "%.1f", balance),
                        unit: "%",
                        icon: "figure.stand.line.dotted.figure.stand",
                        color: balanceColor(for: balance)
                    )
                }
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
            ForEach(WiiFitMetric.allCases, id: \.self) { metric in
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
                .foregroundStyle(.cyan.opacity(0.4))
                .symbolSize(30)
            }

            // 7-day moving average line
            ForEach(Array(movingAverageData.enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Moving Avg", point.value)
                )
                .foregroundStyle(.cyan)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }

            // Goal target line
            if let goalTarget = viewModel.goalTarget(for: viewModel.selectedMetric) {
                RuleMark(y: .value("Goal", goalTarget))
                    .foregroundStyle(.cyan.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Goal: \(formatMetricValue(goalTarget, for: viewModel.selectedMetric))")
                            .font(.caption2)
                            .foregroundStyle(.cyan)
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

    private func formatMetricValue(_ value: Double, for metric: WiiFitMetric) -> String {
        switch metric {
        case .weight:
            return String(format: "%.1f kg", value)
        case .bmi:
            return String(format: "%.1f", value)
        case .balance:
            return String(format: "%.1f%%", value)
        }
    }

    private func bmiColor(for bmi: Double) -> Color {
        switch bmi {
        case ..<18.5: return .blue
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .red
        }
    }

    private func balanceColor(for balance: Double) -> Color {
        // 50% is perfect balance
        let offset = abs(balance - 50)
        switch offset {
        case 0..<5: return .green
        case 5..<10: return .yellow
        default: return .orange
        }
    }
}
