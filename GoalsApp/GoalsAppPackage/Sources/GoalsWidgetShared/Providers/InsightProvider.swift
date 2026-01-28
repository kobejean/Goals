import Foundation
import SwiftData
import SwiftUI

/// Protocol for insight providers that handle both data fetching and building.
/// Used by widgets for cache-only access to insight data.
public protocol InsightProvider: Sendable {
    /// The insight type this provider handles
    static var insightType: InsightType { get }

    /// Creates a provider with the given model container
    init(container: ModelContainer)

    /// Loads data from the cache and builds the insight
    func load()

    /// The insight summary (available after load())
    var summary: InsightSummary? { get }

    /// The activity data (available after load())
    var activityData: InsightActivityData? { get }
}

// MARK: - Shared Helpers

extension InsightProvider {
    /// Standard 30-day date range for insight data
    public static var dateRange: (start: Date, end: Date) {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: end)!
        return (start, end)
    }
}

/// Shared calculation helpers for insight providers
public enum InsightCalculations {
    /// Calculate trend percentage comparing recent values to previous values
    public static func calculateTrend(for values: [Double]) -> Double? {
        guard values.count >= 7 else { return nil }

        let recentCount = min(7, values.count / 2)
        let recentValues = Array(values.suffix(recentCount))
        let previousValues = Array(values.dropLast(recentCount).suffix(recentCount))

        guard !previousValues.isEmpty else { return nil }

        let recentAvg = recentValues.reduce(0, +) / Double(recentValues.count)
        let previousAvg = previousValues.reduce(0, +) / Double(previousValues.count)

        guard previousAvg != 0 else { return nil }

        return ((recentAvg - previousAvg) / previousAvg) * 100
    }

    /// Calculate moving average for a series of data points
    public static func calculateMovingAverage(
        for data: [(date: Date, value: Double)],
        window: Int
    ) -> [(date: Date, value: Double)] {
        guard !data.isEmpty else { return [] }

        let calendar = Calendar.current
        let sorted = data.sorted { $0.date < $1.date }

        var valuesByDate: [Date: Double] = [:]
        for point in sorted {
            let day = calendar.startOfDay(for: point.date)
            valuesByDate[day] = point.value
        }

        guard let firstDate = sorted.first?.date,
              let lastDate = sorted.last?.date else { return [] }

        let startDay = calendar.startOfDay(for: firstDate)
        let endDay = calendar.startOfDay(for: lastDate)

        var continuousSeries: [(date: Date, value: Double)] = []
        var currentDay = startDay
        while currentDay <= endDay {
            let value = valuesByDate[currentDay] ?? 0.0
            continuousSeries.append((date: currentDay, value: value))
            currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay) ?? currentDay
        }

        var result: [(date: Date, value: Double)] = []
        for i in 0..<continuousSeries.count {
            let windowStart = Swift.max(0, i - window + 1)
            let windowData = continuousSeries[windowStart...i]
            let average = windowData.reduce(0.0) { $0 + $1.value } / Double(windowData.count)
            result.append((date: continuousSeries[i].date, value: average))
        }

        return result
    }

    /// Build activity days from records with dates
    public static func buildActivityDays<T>(
        from records: [T],
        color: Color,
        dateExtractor: (T) -> Date,
        valueExtractor: (T) -> Double
    ) -> [InsightActivityDay] {
        let values = records.map(valueExtractor)
        let maxValue = values.max() ?? 1

        return records.map { record in
            let value = valueExtractor(record)
            let intensity = maxValue > 0 ? value / maxValue : 0
            return InsightActivityDay(date: dateExtractor(record), color: color, intensity: intensity)
        }
    }
}
