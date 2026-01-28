import Foundation
import SwiftData
import SwiftUI
import GoalsData
import GoalsDomain

/// Provides AtCoder insight data from cache
public final class AtCoderInsightProvider: InsightProvider, @unchecked Sendable {
    public static let insightType: InsightType = .atCoder

    private let container: ModelContainer
    private var _summary: InsightSummary?
    private var _activityData: InsightActivityData?

    public init(container: ModelContainer) {
        self.container = container
    }

    public func load() {
        let (start, end) = Self.dateRange
        // Fetch all contest history (no date range - we want all contests for rating trend)
        let contestHistory = (try? AtCoderContestResultModel.fetch(in: container)) ?? []
        let dailyEffort = (try? AtCoderDailyEffortModel.fetch(from: start, to: end, in: container)) ?? []
        (_summary, _activityData) = Self.build(from: contestHistory, dailyEffort: dailyEffort)
    }

    public var summary: InsightSummary? { _summary }
    public var activityData: InsightActivityData? { _activityData }

    // MARK: - Build Logic (Public for ViewModel use)

    /// Build AtCoder insight from contest history and daily effort
    public static func build(
        from contestHistory: [AtCoderContestResult],
        dailyEffort: [AtCoderDailyEffort] = [],
        goals: [Goal] = []
    ) -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard !contestHistory.isEmpty else { return (nil, nil) }

        let type = InsightType.atCoder

        let dataPoints = contestHistory.map { contest in
            InsightDataPoint(
                date: contest.date,
                value: Double(contest.rating),
                color: contest.rankColor.swiftUIColor
            )
        }

        let currentRating = contestHistory.last?.rating ?? 0
        let currentColor = contestHistory.last?.rankColor.swiftUIColor ?? .gray
        let trend = InsightCalculations.calculateTrend(for: contestHistory.map { Double($0.rating) })
        let goalValue = goals.targetValue(for: "rating")

        let summary = InsightSummary(
            title: type.displayTitle,
            systemImage: type.systemImage,
            color: currentColor,
            dataPoints: dataPoints,
            currentValueFormatted: "\(currentRating) ELO",
            trend: trend,
            goalValue: goalValue
        )

        // Build activity data from daily effort (colored by hardest difficulty)
        let activityDays: [InsightActivityDay]
        if !dailyEffort.isEmpty {
            activityDays = dailyEffort.map { effort in
                let hardest = effort.submissionsByDifficulty.keys
                    .sorted { $0.sortOrder > $1.sortOrder }
                    .first ?? .gray

                return InsightActivityDay(
                    date: effort.date,
                    color: hardest.swiftUIColor,
                    intensity: min(1.0, Double(effort.totalSubmissions) / 10.0)
                )
            }
        } else {
            activityDays = contestHistory.map { contest in
                InsightActivityDay(
                    date: contest.date,
                    color: contest.rankColor.swiftUIColor,
                    intensity: 1.0
                )
            }
        }

        let activityData = InsightActivityData(days: activityDays, emptyColor: .gray.opacity(0.2))

        return (summary, activityData)
    }
}
