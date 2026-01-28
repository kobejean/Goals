import Foundation
import SwiftData
import SwiftUI
import GoalsData
import GoalsDomain

/// Provides Wii Fit insight data from cache
public final class WiiFitInsightProvider: BaseInsightProvider<WiiFitMeasurement> {
    public override class var insightType: InsightType { .wiiFit }

    public override func load() {
        let (start, end) = Self.dateRange
        let measurements = (try? WiiFitMeasurementModel.fetch(from: start, to: end, in: container)) ?? []
        let (summary, activityData) = Self.build(from: measurements)
        setInsight(summary: summary, activityData: activityData)
    }

    // MARK: - Build Logic (Public for ViewModel use)

    /// Build Wii Fit insight from measurements and optional goals
    public static func build(
        from measurements: [WiiFitMeasurement],
        goals: [Goal] = []
    ) -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard !measurements.isEmpty else { return (nil, nil) }

        let type = InsightType.wiiFit

        // Filter to last 30 days for the card
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let last30DaysMeasurements = measurements.filter { $0.date >= cutoffDate }

        // Use weight for scatter plot
        let scatterPoints = last30DaysMeasurements.map { m in
            InsightDataPoint(date: m.date, value: m.weightKg)
        }

        // Calculate moving average
        let movingAverageData = InsightCalculations.calculateMovingAverage(
            for: last30DaysMeasurements.map { (date: $0.date, value: $0.weightKg) },
            window: 7
        )
        let movingAveragePoints = movingAverageData.map {
            InsightDataPoint(date: $0.date, value: $0.value)
        }

        // Get latest weight and trend
        let sortedMeasurements = measurements.sorted { $0.date < $1.date }
        let latestWeight = sortedMeasurements.last?.weightKg ?? 0
        let trend = InsightCalculations.calculateTrend(for: sortedMeasurements.map { $0.weightKg })

        // Format current value
        let weightFormatted = String(format: "%.1f kg", latestWeight)

        let summary = InsightSummary(
            title: type.displayTitle,
            systemImage: type.systemImage,
            color: type.color,
            scatterPoints: scatterPoints,
            movingAveragePoints: movingAveragePoints,
            currentValueFormatted: weightFormatted,
            trend: trend,
            goalValue: goals.targetValue(for: "weight")
        )

        // Build activity calendar (one entry per measurement day)
        let activityDays = InsightCalculations.buildActivityDays(
            from: measurements,
            color: type.color,
            dateExtractor: { $0.date },
            // Use BMI as intensity indicator (normalized around 22)
            valueExtractor: { measurement in
                // BMI 18-30 maps to 0-1 intensity
                let normalizedBMI = max(0, min(1, (measurement.bmi - 18) / 12))
                return normalizedBMI
            }
        )
        let activityData = InsightActivityData(days: activityDays, emptyColor: .gray.opacity(0.2))

        return (summary, activityData)
    }
}
