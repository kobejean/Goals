import Foundation
import SwiftData
import SwiftUI
import GoalsData
import GoalsDomain

/// Provides TypeQuicker insight data from cache
public final class TypeQuickerInsightProvider: BaseInsightProvider<TypeQuickerStats> {
    public override class var insightType: InsightType { .typeQuicker }

    public override func load() {
        let (start, end) = Self.dateRange
        let stats = (try? TypeQuickerStatsModel.fetch(from: start, to: end, in: container)) ?? []
        let (summary, activityData) = Self.build(from: stats)
        setInsight(summary: summary, activityData: activityData)
    }

    // MARK: - Build Logic (Public for ViewModel use)

    /// Build TypeQuicker insight from stats and optional goals
    public static func build(
        from stats: [TypeQuickerStats],
        goals: [Goal] = []
    ) -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard !stats.isEmpty else { return (nil, nil) }

        let type = InsightType.typeQuicker

        // Build WPM vs Accuracy data points from mode stats
        var wpmAccuracyPoints: [InsightWPMAccuracyPoint] = []

        for stat in stats {
            if let byMode = stat.byMode {
                for modeStat in byMode {
                    wpmAccuracyPoints.append(InsightWPMAccuracyPoint(
                        date: stat.date,
                        mode: modeStat.mode,
                        wpm: modeStat.wordsPerMinute,
                        accuracy: modeStat.accuracy
                    ))
                }
            } else {
                wpmAccuracyPoints.append(InsightWPMAccuracyPoint(
                    date: stat.date,
                    mode: "overall",
                    wpm: stat.wordsPerMinute,
                    accuracy: stat.accuracy
                ))
            }
        }

        let modeColors: [String: Color] = [
            "text": .gray,
            "code": InsightType.brandGreen,
            "overall": type.color
        ]

        let wpmAccuracyData = InsightWPMAccuracyData(
            dataPoints: wpmAccuracyPoints,
            wpmGoal: goals.targetValue(for: "wpm"),
            accuracyGoal: goals.targetValue(for: "accuracy"),
            modeColors: modeColors
        )

        let latestWPM = Int(stats.last?.wordsPerMinute ?? 0)
        let latestAccuracy = Int(stats.last?.accuracy ?? 0)
        let trend = InsightCalculations.calculateTrend(for: stats.map { $0.wordsPerMinute })

        let summary = InsightSummary(
            title: type.displayTitle,
            systemImage: type.systemImage,
            color: type.color,
            wpmAccuracyData: wpmAccuracyData,
            currentValueFormatted: "\(latestWPM) WPM · \(latestAccuracy)%",
            trend: trend
        )

        let activityDays = InsightCalculations.buildActivityDays(
            from: stats,
            color: type.color,
            dateExtractor: { $0.date },
            valueExtractor: { Double($0.practiceTimeMinutes) }
        )
        let activityData = InsightActivityData(days: activityDays, emptyColor: .gray.opacity(0.2))

        return (summary, activityData)
    }
}
