import SwiftUI
import Charts
import GoalsDomain
import GoalsData

/// Insights view showing time-based trends and analytics
public struct InsightsView: View {
    @Environment(AppContainer.self) private var container
    @State private var typeQuickerStats: [TypeQuickerStats] = []
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedMetric: ChartMetric = .wpm
    @State private var isLoading = true

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        // TypeQuicker trend chart with mode breakdown
                        typeQuickerTrendSection

                        // AtCoder insights
                        AtCoderInsightsView(timeRange: selectedTimeRange)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Insights")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }
            .task {
                await loadData()
            }
            .onChange(of: selectedTimeRange) {
                Task {
                    await loadData()
                }
            }
        }
    }

    // MARK: - Chart Data

    /// Flattened data points for charting by mode
    private var modeChartData: [ModeDataPoint] {
        var points: [ModeDataPoint] = []
        for stat in typeQuickerStats {
            if let byMode = stat.byMode, !byMode.isEmpty {
                for modeStat in byMode {
                    points.append(ModeDataPoint(
                        date: stat.date,
                        mode: modeStat.mode,
                        wpm: modeStat.wordsPerMinute,
                        accuracy: modeStat.accuracy,
                        timeMinutes: modeStat.practiceTimeMinutes
                    ))
                }
            } else {
                points.append(ModeDataPoint(
                    date: stat.date,
                    mode: "overall",
                    wpm: stat.wordsPerMinute,
                    accuracy: stat.accuracy,
                    timeMinutes: stat.practiceTimeMinutes
                ))
            }
        }
        return points
    }

    /// Unique modes present in the data
    private var uniqueModes: [String] {
        Array(Set(modeChartData.map(\.mode))).sorted()
    }

    /// Y-axis range for current metric with padding
    private var chartYAxisRange: ClosedRange<Double> {
        let values = modeChartData.map { $0.value(for: selectedMetric) }

        guard let minVal = values.min(), let maxVal = values.max() else {
            return 0...100
        }

        let range = maxVal - minVal
        let padding = max(range * 0.15, 1)

        let lower = max(0, minVal - padding)
        let upper = maxVal + padding

        return lower...upper
    }

    /// Trend percentage for the selected metric
    private var metricTrend: Double? {
        guard typeQuickerStats.count >= 2 else { return nil }
        let first: Double
        let last: Double

        switch selectedMetric {
        case .wpm:
            first = typeQuickerStats.first!.wordsPerMinute
            last = typeQuickerStats.last!.wordsPerMinute
        case .accuracy:
            first = typeQuickerStats.first!.accuracy
            last = typeQuickerStats.last!.accuracy
        case .time:
            first = Double(typeQuickerStats.first!.practiceTimeMinutes)
            last = Double(typeQuickerStats.last!.practiceTimeMinutes)
        }

        guard first > 0 else { return nil }
        return ((last - first) / first) * 100
    }

    // MARK: - TypeQuicker Trend Section

    @ViewBuilder
    private var typeQuickerTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "keyboard")
                    .foregroundStyle(.blue)
                Text("Typing Progress")
                    .font(.headline)
                Spacer()
                if let trend = metricTrend {
                    TrendBadge(trend: trend)
                }
            }

            if typeQuickerStats.isEmpty {
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
            } else {
                // Metric picker
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(ChartMetric.allCases, id: \.self) { metric in
                        Text(metric.displayName).tag(metric)
                    }
                }
                .pickerStyle(.segmented)

                // Trend chart with separate lines per mode
                Chart {
                    ForEach(modeChartData) { point in
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value(selectedMetric.displayName, point.value(for: selectedMetric))
                        )
                        .foregroundStyle(by: .value("Mode", point.mode.capitalized))
                        .symbol(by: .value("Mode", point.mode.capitalized))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: chartYAxisRange)
                .chartYAxisLabel(selectedMetric.yAxisLabel)
                .chartLegend(.hidden)
                .chartForegroundStyleScale(mapping: { (mode: String) in
                    colorForMode(mode.lowercased())
                })

                // Mode legend with stats
                if uniqueModes.count > 1 {
                    VStack(spacing: 6) {
                        ForEach(uniqueModes, id: \.self) { mode in
                            let modePoints = modeChartData.filter { $0.mode == mode }
                            let avgValue = modePoints.isEmpty ? 0 : modePoints.reduce(0) { $0 + $1.value(for: selectedMetric) } / Double(modePoints.count)

                            HStack {
                                Circle()
                                    .fill(colorForMode(mode))
                                    .frame(width: 8, height: 8)
                                Text(mode.capitalized)
                                    .font(.caption)
                                Spacer()
                                Text(formatMetricValue(avgValue, for: selectedMetric, suffix: " avg"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
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

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        await loadTypeQuickerStats()
        isLoading = false
    }

    private func loadTypeQuickerStats() async {
        // Configure from saved settings if available
        if let username = UserDefaults.standard.string(forKey: "typeQuickerUsername"), !username.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .typeQuicker,
                credentials: ["username": username]
            )
            try? await container.typeQuickerDataSource.configure(settings: settings)
        }

        guard await container.typeQuickerDataSource.isConfigured() else {
            return
        }

        do {
            let endDate = Date()
            let startDate = selectedTimeRange.startDate(from: endDate)
            typeQuickerStats = try await container.typeQuickerDataSource.fetchStats(from: startDate, to: endDate)
        } catch {
            print("Failed to load TypeQuicker stats: \(error)")
        }
    }

    public init() {}
}

// MARK: - Helper Types

/// Metric options for the TypeQuicker chart
enum ChartMetric: String, CaseIterable {
    case wpm
    case accuracy
    case time

    var displayName: String {
        switch self {
        case .wpm: return "WPM"
        case .accuracy: return "Accuracy"
        case .time: return "Time"
        }
    }

    var yAxisLabel: String {
        switch self {
        case .wpm: return "WPM"
        case .accuracy: return "%"
        case .time: return "min"
        }
    }
}

/// Data point for charting mode-specific stats over time
private struct ModeDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let mode: String
    let wpm: Double
    let accuracy: Double
    let timeMinutes: Int

    func value(for metric: ChartMetric) -> Double {
        switch metric {
        case .wpm: return wpm
        case .accuracy: return accuracy
        case .time: return Double(timeMinutes)
        }
    }
}

// MARK: - Time Range

public enum TimeRange: String, CaseIterable {
    case week
    case month
    case quarter
    case year
    case all

    public var displayName: String {
        switch self {
        case .week: return "1W"
        case .month: return "1M"
        case .quarter: return "3M"
        case .year: return "1Y"
        case .all: return "All"
        }
    }

    public func startDate(from endDate: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .quarter:
            return calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        case .all:
            return calendar.date(byAdding: .year, value: -100, to: endDate) ?? Date.distantPast
        }
    }

    public var xAxisStride: Calendar.Component {
        switch self {
        case .week: return .day
        case .month: return .weekOfYear
        case .quarter: return .month
        case .year: return .month
        case .all: return .year
        }
    }

    public var xAxisCount: Int {
        switch self {
        case .week: return 1
        case .month: return 1
        case .quarter: return 1
        case .year: return 2
        case .all: return 1
        }
    }

    public var xAxisFormat: Date.FormatStyle {
        switch self {
        case .week: return .dateTime.weekday(.abbreviated)
        case .month: return .dateTime.month(.abbreviated).day()
        case .quarter: return .dateTime.month(.abbreviated)
        case .year: return .dateTime.month(.abbreviated)
        case .all: return .dateTime.year()
        }
    }
}

// MARK: - Supporting Views

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

#Preview {
    InsightsView()
        .environment(try! AppContainer.preview())
}
