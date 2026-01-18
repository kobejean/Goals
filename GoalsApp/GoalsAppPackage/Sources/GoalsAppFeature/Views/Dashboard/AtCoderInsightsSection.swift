import SwiftUI
import Charts
import GoalsDomain
import GoalsData

/// AtCoder-specific insights section with Rating and Daily Effort charts
public struct AtCoderInsightsSection: View {
    @Bindable var viewModel: AtCoderInsightsViewModel
    let timeRange: TimeRange

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Label("AtCoder", systemImage: "chevron.left.forwardslash.chevron.right")
                .font(.headline)

            if viewModel.isLoading {
                ProgressView("Loading AtCoder data...")
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView {
                    Label("Unable to Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                // Stats summary
                if let stats = viewModel.stats {
                    StatsRow(stats: stats)
                }

                // Rating History Chart
                RatingChart(
                    contestHistory: viewModel.filteredContestHistory(for: timeRange),
                    timeRange: timeRange,
                    ratingGoal: viewModel.ratingGoalTarget
                )

                // Daily Effort Chart
                DailyEffortChart(
                    dailyEffort: viewModel.filteredDailyEffort(for: timeRange),
                    timeRange: timeRange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    public init(viewModel: AtCoderInsightsViewModel, timeRange: TimeRange) {
        self.viewModel = viewModel
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
    let ratingGoal: Int?

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

                    // Goal target line
                    if let goal = ratingGoal {
                        RuleMark(y: .value("Goal", goal))
                            .foregroundStyle(.red.opacity(0.8))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Goal: \(goal)")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 4)
                                    .background(.regularMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
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
                    AxisMarks(values: .stride(by: 400)) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartYScale(domain: yAxisDomainWithGoal)
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

    private var yAxisDomainWithGoal: ClosedRange<Int> {
        var ratings = contestHistory.map { $0.rating }
        if let goal = ratingGoal {
            ratings.append(goal)
        }
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
