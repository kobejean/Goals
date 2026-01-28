import Foundation
import SwiftData
import SwiftUI
import GoalsData
import GoalsDomain

/// Provides Nutrition insight data from cache
public final class NutritionInsightProvider: InsightProvider, @unchecked Sendable {
    public static let insightType: InsightType = .nutrition

    private let container: ModelContainer
    private var _summary: InsightSummary?
    private var _activityData: InsightActivityData?

    // Daily macro targets in grams
    private static let dailyMacroTargets = (protein: 150.0, carbs: 250.0, fat: 65.0)

    public init(container: ModelContainer) {
        self.container = container
    }

    public func load() {
        let (start, end) = Self.dateRange
        let summaries = (try? NutritionDailySummaryModel.fetch(from: start, to: end, in: container)) ?? []
        (_summary, _activityData) = Self.build(from: summaries)
    }

    public var summary: InsightSummary? { _summary }
    public var activityData: InsightActivityData? { _activityData }

    // MARK: - Build Logic (Public for ViewModel use)

    /// Build Nutrition insight from daily summaries
    public static func build(
        from summaries: [NutritionDailySummary],
        goals: [Goal] = []
    ) -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard !summaries.isEmpty else { return (nil, nil) }

        let type = InsightType.nutrition
        let calendar = Calendar.current

        // Filter to last 30 days for the card
        let cutoffDate = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let last30DaysSummaries = summaries.filter { $0.date >= cutoffDate }

        let scatterPoints = last30DaysSummaries.map { summary in
            InsightDataPoint(date: summary.date, value: summary.totalCalories)
        }

        let movingAverageData = InsightCalculations.calculateMovingAverage(
            for: last30DaysSummaries.map { (date: $0.date, value: $0.totalCalories) },
            window: 7
        )
        let movingAveragePoints = movingAverageData.map {
            InsightDataPoint(date: $0.date, value: $0.value)
        }

        // Calculate today's totals
        let today = calendar.startOfDay(for: Date())
        let todaySummary = summaries.first { calendar.startOfDay(for: $0.date) == today }
        let todayCalories = Int(todaySummary?.totalCalories ?? 0)
        let todayNutrients = todaySummary?.totalNutrients ?? .zero

        let macroRadarData = MacroRadarData(
            current: (todayNutrients.protein, todayNutrients.carbohydrates, todayNutrients.fat),
            ideal: dailyMacroTargets
        )

        let trend = InsightCalculations.calculateTrend(for: summaries.map { $0.totalCalories })
        let goalValue = goals.targetValue(for: "calories")

        let summary = InsightSummary(
            title: type.displayTitle,
            systemImage: type.systemImage,
            color: type.color,
            scatterPoints: scatterPoints,
            movingAveragePoints: movingAveragePoints,
            macroRadarData: macroRadarData,
            currentValueFormatted: "\(todayCalories) kcal",
            trend: trend,
            goalValue: goalValue
        )

        let activityDays = InsightCalculations.buildActivityDays(
            from: summaries,
            color: type.color,
            dateExtractor: { $0.date },
            valueExtractor: { $0.totalCalories }
        )
        let activityData = InsightActivityData(days: activityDays, emptyColor: .gray.opacity(0.2))

        return (summary, activityData)
    }
}
