import SwiftUI
import Charts
import GoalsDomain

/// TypeQuicker insights section view
struct TypeQuickerInsightsSection: View {
    @Bindable var viewModel: TypeQuickerInsightsViewModel
    let timeRange: TimeRange

    var body: some View {
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

            if viewModel.stats.isEmpty {
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
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
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
            ForEach(ChartMetric.allCases, id: \.self) { metric in
                Text(metric.displayName).tag(metric)
            }
        }
        .pickerStyle(.segmented)
    }

    private var trendChart: some View {
        Chart {
            ForEach(viewModel.modeChartData) { point in
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
        .chartYScale(domain: viewModel.chartYAxisRange(for: viewModel.selectedMetric))
        .chartYAxisLabel(viewModel.selectedMetric.yAxisLabel)
        .chartLegend(.hidden)
        .chartForegroundStyleScale(mapping: { (mode: String) in
            colorForMode(mode.lowercased())
        })
    }

    private var modeLegend: some View {
        VStack(spacing: 6) {
            ForEach(viewModel.uniqueModes, id: \.self) { mode in
                let modePoints = viewModel.modeChartData.filter { $0.mode == mode }
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

    private func formatMetricValue(_ value: Double, for metric: ChartMetric, suffix: String = "") -> String {
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

// MARK: - TrendBadge

struct TrendBadge: View {
    let trend: Double

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
            Text(String(format: "%.1f%%", abs(trend)))
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(trend >= 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
        .foregroundStyle(trend >= 0 ? .green : .red)
        .clipShape(Capsule())
    }
}
