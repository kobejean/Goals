import SwiftUI
import Charts
import GoalsDomain
import GoalsData

/// AtCoder-specific insights view with Daily Effort chart
public struct AtCoderInsightsView: View {
    @Environment(AppContainer.self) private var container
    @State private var dailyEffort: [AtCoderDailyEffort] = []
    @State private var contestHistory: [AtCoderStats] = []
    @State private var stats: AtCoderStats?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedTimeRange: AtCoderTimeRange = .month

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("AtCoder", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.headline)
                Spacer()
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(AtCoderTimeRange.allCases, id: \.self) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            if isLoading {
                ProgressView("Loading AtCoder data...")
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Unable to Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                // Stats summary
                if let stats {
                    StatsRow(stats: stats)
                }

                // Rating History Chart
                RatingChart(
                    contestHistory: filteredContestHistory,
                    timeRange: selectedTimeRange
                )

                // Daily Effort Chart
                DailyEffortChart(
                    dailyEffort: filteredDailyEffort,
                    timeRange: selectedTimeRange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .task {
            await loadData()
        }
        .onChange(of: selectedTimeRange) { _, _ in
            // Data is already loaded, just filter
        }
    }

    private var filteredDailyEffort: [AtCoderDailyEffort] {
        let cutoffDate = selectedTimeRange.startDate
        return dailyEffort.filter { $0.date >= cutoffDate }
    }

    private var filteredContestHistory: [AtCoderStats] {
        let cutoffDate = selectedTimeRange.startDate
        return contestHistory.filter { $0.date >= cutoffDate }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        // Check if configured
        guard await container.atCoderDataSource.isConfigured() else {
            errorMessage = "Configure your AtCoder username in Settings"
            isLoading = false
            return
        }

        do {
            // Fetch data concurrently
            async let statsTask = container.atCoderDataSource.fetchStats()
            async let effortTask = container.atCoderDataSource.fetchDailyEffort(from: AtCoderTimeRange.year.startDate)
            async let historyTask = container.atCoderDataSource.fetchContestHistory()

            stats = try await statsTask
            dailyEffort = try await effortTask
            contestHistory = try await historyTask
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    public init() {}
}

// MARK: - Stats Row

private struct StatsRow: View {
    let stats: AtCoderStats

    var body: some View {
        HStack(spacing: 0) {
            StatItem(
                label: "Rating",
                value: "\(stats.rating)",
                color: stats.rankColor.swiftUIColor
            )
            Spacer()
            StatItem(
                label: "Best",
                value: "\(stats.highestRating)",
                color: .orange
            )
            Spacer()
            StatItem(
                label: "Contests",
                value: "\(stats.contestsParticipated)",
                color: .blue
            )
            Spacer()
            StatItem(
                label: "Solved",
                value: "\(stats.problemsSolved)",
                color: .green
            )
            if let streak = stats.longestStreak {
                Spacer()
                StatItem(
                    label: "Streak",
                    value: "\(streak)d",
                    color: .red
                )
            }
        }
        .padding(.vertical, 4)
    }
}

private struct StatItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Rating Chart

private struct RatingChart: View {
    let contestHistory: [AtCoderStats]
    let timeRange: AtCoderTimeRange

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rating")
                .font(.subheadline.bold())

            if contestHistory.isEmpty {
                Text("No contest history")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart {
                    ForEach(contestHistory, id: \.date) { stat in
                        LineMark(
                            x: .value("Date", stat.date),
                            y: .value("Rating", stat.rating)
                        )
                        .foregroundStyle(ratingGradient)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", stat.date),
                            y: .value("Rating", stat.rating)
                        )
                        .foregroundStyle(areaGradient)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", stat.date),
                            y: .value("Rating", stat.rating)
                        )
                        .foregroundStyle(AtCoderRankColor.from(difficulty: stat.rating).swiftUIColor)
                        .symbolSize(30)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: xAxisStride, count: xAxisCount)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: xAxisFormat)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartYScale(domain: yAxisDomain)
                .frame(height: 150)
            }
        }
    }

    private var ratingGradient: LinearGradient {
        LinearGradient(
            colors: [.cyan, .blue],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [.cyan.opacity(0.3), .blue.opacity(0.1)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var yAxisDomain: ClosedRange<Int> {
        let ratings = contestHistory.map { $0.rating }
        let minRating = (ratings.min() ?? 0) - 100
        let maxRating = (ratings.max() ?? 100) + 100
        return max(0, minRating)...maxRating
    }

    private var xAxisStride: Calendar.Component {
        switch timeRange {
        case .week: return .day
        case .month: return .weekOfYear
        case .quarter: return .month
        case .year: return .month
        }
    }

    private var xAxisCount: Int {
        switch timeRange {
        case .week: return 1
        case .month: return 1
        case .quarter: return 1
        case .year: return 2
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch timeRange {
        case .week: return .dateTime.weekday(.abbreviated)
        case .month: return .dateTime.month(.abbreviated).day()
        case .quarter: return .dateTime.month(.abbreviated)
        case .year: return .dateTime.month(.abbreviated)
        }
    }
}

// MARK: - Daily Effort Chart

private struct DailyEffortChart: View {
    let dailyEffort: [AtCoderDailyEffort]
    let timeRange: AtCoderTimeRange

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Effort")
                .font(.subheadline.bold())

            if dailyEffort.isEmpty {
                Text("No submissions found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                Chart {
                    ForEach(dailyEffort) { day in
                        ForEach(sortedDifficulties, id: \.self) { difficulty in
                            if let count = day.submissionsByDifficulty[difficulty], count > 0 {
                                BarMark(
                                    x: .value("Date", day.date, unit: .day),
                                    y: .value("Submissions", count)
                                )
                                .foregroundStyle(difficulty.swiftUIColor)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: xAxisStride, count: xAxisCount)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: xAxisFormat)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 150)
            }
        }
    }

    private var sortedDifficulties: [AtCoderRankColor] {
        AtCoderRankColor.allCases.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var xAxisStride: Calendar.Component {
        switch timeRange {
        case .week: return .day
        case .month: return .weekOfYear
        case .quarter: return .month
        case .year: return .month
        }
    }

    private var xAxisCount: Int {
        switch timeRange {
        case .week: return 1
        case .month: return 1
        case .quarter: return 1
        case .year: return 2
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch timeRange {
        case .week: return .dateTime.weekday(.abbreviated)
        case .month: return .dateTime.month(.abbreviated).day()
        case .quarter: return .dateTime.month(.abbreviated)
        case .year: return .dateTime.month(.abbreviated)
        }
    }
}

// MARK: - AtCoder Time Range

/// Time range for AtCoder insights
enum AtCoderTimeRange: String, CaseIterable {
    case week
    case month
    case quarter
    case year

    var displayName: String {
        switch self {
        case .week: return "1W"
        case .month: return "1M"
        case .quarter: return "3M"
        case .year: return "1Y"
        }
    }

    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now)!
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now)!
        case .quarter:
            return calendar.date(byAdding: .month, value: -3, to: now)!
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: now)!
        }
    }
}

// MARK: - Color Extensions

extension AtCoderRankColor {
    var swiftUIColor: Color {
        switch self {
        case .gray: return .gray
        case .brown: return .brown
        case .green: return .green
        case .cyan: return .cyan
        case .blue: return .blue
        case .yellow: return .yellow
        case .orange: return .orange
        case .red: return .red
        }
    }
}

#Preview {
    ScrollView {
        AtCoderInsightsView()
            .padding()
    }
    .environment(try! AppContainer.preview())
}
