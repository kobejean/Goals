import SwiftUI
import Charts
import GoalsDomain
import GoalsData

/// Insights view showing time-based trends and analytics
public struct InsightsView: View {
    @Environment(AppContainer.self) private var container
    @State private var goals: [Goal] = []
    @State private var dataPoints: [DataPoint] = []
    @State private var typeQuickerStats: [TypeQuickerStats] = []
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedMetric: ChartMetric = .wpm
    @State private var isLoading = true

    // TypeQuicker goals from settings
    @State private var wpmGoal: Double = 0
    @State private var accuracyGoal: Double = 0
    @State private var timeGoal: Double = 0

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Time range picker
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        // TypeQuicker trend chart with mode breakdown
                        typeQuickerTrendSection

                        // Goal progress over time
                        progressTrendSection

                        // Activity summary
                        activitySummarySection

                        // Goal distribution
                        goalDistributionSection
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Insights")
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

    /// Flattened data points for charting by mode
    private var modeChartData: [ModeDataPoint] {
        var points: [ModeDataPoint] = []
        for stat in typeQuickerStats {
            if let byMode = stat.byMode, !byMode.isEmpty {
                // Add individual mode lines
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
                // Fallback to overall if no mode breakdown
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

    /// Current goal value based on selected metric
    private var currentGoal: Double {
        switch selectedMetric {
        case .wpm: return wpmGoal
        case .accuracy: return accuracyGoal
        case .time: return timeGoal
        }
    }

    /// Y-axis range for current metric with padding
    private var chartYAxisRange: ClosedRange<Double> {
        var values = modeChartData.map { $0.value(for: selectedMetric) }

        // Include goal in range calculation if set
        if currentGoal > 0 {
            values.append(currentGoal)
        }

        guard let minVal = values.min(), let maxVal = values.max() else {
            return 0...100
        }

        // Add 10% padding above and below
        let range = maxVal - minVal
        let padding = max(range * 0.15, 1) // At least 1 unit padding

        let lower = max(0, minVal - padding)
        let upper = maxVal + padding

        return lower...upper
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

                    // Goal line
                    if currentGoal > 0 {
                        RuleMark(y: .value("Goal", currentGoal))
                            .foregroundStyle(.red.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Goal: \(formatMetricValue(currentGoal, for: selectedMetric))")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 4)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
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

    // MARK: - Progress Trend Section

    @ViewBuilder
    private var progressTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.green)
                Text("Goal Progress")
                    .font(.headline)
                Spacer()
            }

            if goals.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No goals yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                // Average progress over time (simulated based on current progress)
                Chart {
                    ForEach(goals.filter { !$0.isArchived }) { goal in
                        BarMark(
                            x: .value("Goal", goal.title),
                            y: .value("Progress", goal.progress * 100)
                        )
                        .foregroundStyle(goal.color.swiftUIColor)
                    }
                }
                .frame(height: 150)
                .chartYAxisLabel("%")
                .chartYScale(domain: 0...100)

                // Progress stats
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("\(completedGoalsCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                        .frame(height: 40)

                    VStack(alignment: .leading) {
                        Text("\(inProgressGoalsCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("In Progress")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                        .frame(height: 40)

                    VStack(alignment: .leading) {
                        Text("\(averageProgress)%")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Avg Progress")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Activity Summary Section

    @ViewBuilder
    private var activitySummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.orange)
                Text("Activity Summary")
                    .font(.headline)
                Spacer()
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ActivityCard(
                    title: "Active Streaks",
                    value: "\(activeStreaksCount)",
                    icon: "flame.fill",
                    color: .orange
                )

                ActivityCard(
                    title: "Habits Tracked",
                    value: "\(habitsCount)",
                    icon: "repeat.circle.fill",
                    color: .green
                )

                ActivityCard(
                    title: "Milestones Hit",
                    value: "\(completedMilestonesCount)/\(totalMilestonesCount)",
                    icon: "flag.fill",
                    color: .purple
                )

                ActivityCard(
                    title: "Typing Sessions",
                    value: "\(totalTypingSessions)",
                    icon: "keyboard.fill",
                    color: .blue
                )
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Goal Distribution Section

    @ViewBuilder
    private var goalDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie")
                    .foregroundStyle(.purple)
                Text("Goals by Type")
                    .font(.headline)
                Spacer()
            }

            if goals.isEmpty {
                Text("No goals to display")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                let typeCounts = Dictionary(grouping: goals, by: { $0.type })
                    .mapValues { $0.count }

                Chart {
                    ForEach(GoalType.allCases, id: \.self) { type in
                        let count = typeCounts[type] ?? 0
                        if count > 0 {
                            SectorMark(
                                angle: .value("Count", count),
                                innerRadius: .ratio(0.5),
                                angularInset: 1.5
                            )
                            .foregroundStyle(by: .value("Type", type.displayName))
                            .annotation(position: .overlay) {
                                Text("\(count)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
                .frame(height: 180)

                // Legend
                HStack(spacing: 16) {
                    ForEach(GoalType.allCases, id: \.self) { type in
                        let count = typeCounts[type] ?? 0
                        if count > 0 {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(colorForType(type))
                                    .frame(width: 8, height: 8)
                                Text(type.displayName)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Computed Properties

    private var averageWpm: Double {
        guard !typeQuickerStats.isEmpty else { return 0 }
        return typeQuickerStats.reduce(0) { $0 + $1.wordsPerMinute } / Double(typeQuickerStats.count)
    }

    private var bestWpm: Double {
        typeQuickerStats.map(\.wordsPerMinute).max() ?? 0
    }

    private var averageAccuracy: Double {
        guard !typeQuickerStats.isEmpty else { return 0 }
        return typeQuickerStats.reduce(0) { $0 + $1.accuracy } / Double(typeQuickerStats.count)
    }

    private var totalPracticeMinutes: Int {
        typeQuickerStats.reduce(0) { $0 + $1.practiceTimeMinutes }
    }

    private var totalTypingSessions: Int {
        typeQuickerStats.reduce(0) { $0 + $1.sessionsCount }
    }

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

    private var completedGoalsCount: Int {
        goals.filter { $0.isAchieved }.count
    }

    private var inProgressGoalsCount: Int {
        goals.filter { !$0.isAchieved && !$0.isArchived }.count
    }

    private var averageProgress: Int {
        guard !goals.isEmpty else { return 0 }
        let total = goals.reduce(0.0) { $0 + $1.progress }
        return Int(total / Double(goals.count) * 100)
    }

    private var activeStreaksCount: Int {
        goals.filter { $0.type == .habit && ($0.currentStreak ?? 0) > 0 }.count
    }

    private var habitsCount: Int {
        goals.filter { $0.type == .habit }.count
    }

    private var completedMilestonesCount: Int {
        goals.filter { $0.type == .milestone && $0.isAchieved }.count
    }

    private var totalMilestonesCount: Int {
        goals.filter { $0.type == .milestone }.count
    }

    private func colorForType(_ type: GoalType) -> Color {
        switch type {
        case .numeric: return .blue
        case .habit: return .green
        case .milestone: return .purple
        case .compound: return .orange
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true

        // Load TypeQuicker goals from UserDefaults
        wpmGoal = UserDefaults.standard.double(forKey: "typeQuickerWpmGoal")
        accuracyGoal = UserDefaults.standard.double(forKey: "typeQuickerAccuracyGoal")
        timeGoal = UserDefaults.standard.double(forKey: "typeQuickerTimeGoal")

        async let goalsTask: () = loadGoals()
        async let statsTask: () = loadTypeQuickerStats()

        await goalsTask
        await statsTask

        isLoading = false
    }

    private func loadGoals() async {
        do {
            goals = try await container.goalRepository.fetchAll()
        } catch {
            print("Failed to load goals: \(error)")
        }
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
            // Fetch daily stats (includes byMode breakdown per day)
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

    var unitSuffix: String {
        switch self {
        case .wpm: return " WPM"
        case .accuracy: return "%"
        case .time: return " min"
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

enum TimeRange: String, CaseIterable {
    case week
    case month
    case year
    case all

    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        case .all: return "All"
        }
    }

    func startDate(from endDate: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        case .all:
            return calendar.date(byAdding: .year, value: -5, to: endDate) ?? endDate
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

struct MiniStatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ActivityCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    InsightsView()
        .environment(try! AppContainer.preview())
}
