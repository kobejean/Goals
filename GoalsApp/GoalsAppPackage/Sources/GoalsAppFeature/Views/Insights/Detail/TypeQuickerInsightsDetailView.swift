import SwiftUI
import Charts
import GoalsDomain

/// TypeQuicker insights detail view with full charts
struct TypeQuickerInsightsDetailView: View {
    @Bindable var viewModel: TypeQuickerInsightsViewModel
    @State private var timeRange: TimeRange = .all

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "keyboard")
                        .foregroundStyle(.blue)
                    Text("Typing Progress")
                        .font(.headline)
                    Spacer()
                    if let trend = viewModel.metricTrend {
                        TrendBadge(trend: trend)
                    }
                }

                if filteredStats.isEmpty {
                    emptyStateView
                } else {
                    metricPicker
                    trendChart
                    if viewModel.uniqueModes.count > 1 {
                        modeLegend
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Typing Progress")
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

    private var filteredStats: [TypeQuickerModeDataPoint] {
        let cutoffDate = timeRange.startDate(from: Date())
        return viewModel.modeChartData.filter { $0.date >= cutoffDate }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No typing data for this period")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var metricPicker: some View {
        Picker("Metric", selection: $viewModel.selectedMetric) {
            ForEach(TypeQuickerMetric.allCases, id: \.self) { metric in
                Text(metric.displayName).tag(metric)
            }
        }
        .pickerStyle(.segmented)
    }

    private var trendChart: some View {
        Chart {
            ForEach(filteredStats) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value(viewModel.selectedMetric.displayName, point.value(for: viewModel.selectedMetric))
                )
                .foregroundStyle(by: .value("Mode", point.mode.capitalized))
                .symbol(by: .value("Mode", point.mode.capitalized))
                .lineStyle(StrokeStyle(lineWidth: 2))
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
        .chartYScale(domain: chartYAxisRange)
        .chartYAxisLabel(viewModel.selectedMetric.yAxisLabel)
        .chartLegend(.hidden)
        .chartForegroundStyleScale(mapping: { (mode: String) in
            colorForMode(mode.lowercased())
        })
    }

    private var chartYAxisRange: ClosedRange<Double> {
        var values = filteredStats.map { $0.value(for: viewModel.selectedMetric) }

        if let goalTarget = viewModel.goalTarget(for: viewModel.selectedMetric) {
            values.append(goalTarget)
        }

        guard let minVal = values.min(), let maxVal = values.max() else {
            return 0...100
        }

        let range = maxVal - minVal
        let padding = max(range * 0.15, 1)

        let lower = max(0, minVal - padding)
        let upper = maxVal + padding

        return lower...upper
    }

    private var modeLegend: some View {
        let uniqueModes = Array(Set(filteredStats.map(\.mode))).sorted()
        return VStack(spacing: 6) {
            ForEach(uniqueModes, id: \.self) { mode in
                let modePoints = filteredStats.filter { $0.mode == mode }
                let avgValue = modePoints.isEmpty ? 0 : modePoints.reduce(0) { $0 + $1.value(for: viewModel.selectedMetric) } / Double(modePoints.count)

                HStack {
                    Circle()
                        .fill(colorForMode(mode))
                        .frame(width: 8, height: 8)
                    Text(mode.capitalized)
                        .font(.caption)
                    Spacer()
                    Text(formatMetricValue(avgValue, for: viewModel.selectedMetric, suffix: " avg"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func formatMetricValue(_ value: Double, for metric: TypeQuickerMetric, suffix: String = "") -> String {
        switch metric {
        case .wpm:
            return String(format: "%.0f WPM%@", value, suffix)
        case .accuracy:
            return String(format: "%.1f%%%@", value, suffix)
        case .time:
            return String(format: "%.0f min%@", value, suffix)
        }
    }

    private func colorForMode(_ mode: String) -> Color {
        switch mode.lowercased() {
        case "words": return .blue
        case "quotes": return .purple
        case "numbers": return .orange
        case "custom": return .green
        case "code": return .cyan
        default: return .gray
        }
    }
}
