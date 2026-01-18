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

    let timeRange: TimeRange

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Label("AtCoder", systemImage: "chevron.left.forwardslash.chevron.right")
                .font(.headline)

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
                    timeRange: timeRange
                )

                // Daily Effort Chart
                DailyEffortChart(
                    dailyEffort: filteredDailyEffort,
                    timeRange: timeRange
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
    }

    private var filteredDailyEffort: [AtCoderDailyEffort] {
        let cutoffDate = timeRange.startDate(from: Date())
        return dailyEffort.filter { $0.date >= cutoffDate }
    }

    private var filteredContestHistory: [AtCoderStats] {
        let cutoffDate = timeRange.startDate(from: Date())
        return contestHistory.filter { $0.date >= cutoffDate }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        // Configure from saved settings if available
        if let username = UserDefaults.standard.string(forKey: "atCoderUsername"), !username.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .atCoder,
                credentials: ["username": username]
            )
            try? await container.atCoderDataSource.configure(settings: settings)
        }

        // Check if configured
        guard await container.atCoderDataSource.isConfigured() else {
            errorMessage = "Configure your AtCoder username in Settings"
            isLoading = false
            return
        }

        do {
            // Fetch data concurrently - always fetch a year of data for filtering
            let yearStart = TimeRange.year.startDate(from: Date())
            async let statsTask = container.atCoderDataSource.fetchStats()
            async let effortTask = container.atCoderDataSource.fetchDailyEffort(from: yearStart)
            async let historyTask = container.atCoderDataSource.fetchContestHistory()

            stats = try await statsTask
            dailyEffort = try await effortTask
            contestHistory = try await historyTask
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    public init(timeRange: TimeRange) {
        self.timeRange = timeRange
    }
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
    let timeRange: TimeRange

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rating")
                .font(.subheadline.bold())

            if contestHistory.isEmpty {
                Text("No contest history in this period")
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
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Date", stat.date),
                            y: .value("Rating", stat.rating)
                        )
                        .foregroundStyle(AtCoderRankColor.from(difficulty: stat.rating).swiftUIColor)
                        .symbolSize(40)
                    }
                }
                .chartXScale(domain: xAxisDomain)
                .chartXAxis {
                    AxisMarks(values: .stride(by: timeRange.xAxisStride, count: timeRange.xAxisCount)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: timeRange.xAxisFormat)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .stride(by: 400)) { _ in
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

    private var xAxisDomain: ClosedRange<Date> {
        let now = Date()

        // For "All" time range, use actual data range with padding
        if timeRange == .all, let earliest = contestHistory.map(\.date).min(),
           let latest = contestHistory.map(\.date).max() {
            // Add 5% padding on each side
            let dataSpan = latest.timeIntervalSince(earliest)
            let padding = max(dataSpan * 0.05, 86400) // At least 1 day padding
            let paddedStart = earliest.addingTimeInterval(-padding)
            let paddedEnd = now.addingTimeInterval(padding * 0.5)
            return paddedStart...paddedEnd
        }

        // For fixed time ranges, use the full range
        let rangeStart = timeRange.startDate(from: now)
        return rangeStart...now
    }

    private var yAxisDomain: ClosedRange<Int> {
        let ratings = contestHistory.map { $0.rating }
        let minRating = (ratings.min() ?? 0) - 100
        let maxRating = (ratings.max() ?? 100) + 100
        return max(0, minRating)...maxRating
    }
}

// MARK: - Daily Effort Chart

private struct DailyEffortChart: View {
    let dailyEffort: [AtCoderDailyEffort]
    let timeRange: TimeRange

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Effort")
                .font(.subheadline.bold())

            if dailyEffort.isEmpty {
                Text("No submissions found in this period")
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
                .chartXScale(domain: xAxisDomain)
                .chartXAxis {
                    AxisMarks(values: .stride(by: timeRange.xAxisStride, count: timeRange.xAxisCount)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: timeRange.xAxisFormat)
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

    private var xAxisDomain: ClosedRange<Date> {
        let now = Date()

        // For "All" time range, use actual data range with padding
        if timeRange == .all, let earliest = dailyEffort.map(\.date).min(),
           let latest = dailyEffort.map(\.date).max() {
            // Add 5% padding on each side
            let dataSpan = latest.timeIntervalSince(earliest)
            let padding = max(dataSpan * 0.05, 86400) // At least 1 day padding
            let paddedStart = earliest.addingTimeInterval(-padding)
            let paddedEnd = now.addingTimeInterval(padding * 0.5)
            return paddedStart...paddedEnd
        }

        // For fixed time ranges, use the full range
        let rangeStart = timeRange.startDate(from: now)
        return rangeStart...now
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
        AtCoderInsightsView(timeRange: .month)
            .padding()
    }
    .environment(try! AppContainer.preview())
}
