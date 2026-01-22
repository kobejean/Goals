import Foundation
import SwiftUI
import GoalsDomain

/// Provides insight data for widgets by reading from the shared cache
public actor WidgetDataProvider {
    private let cache: WidgetDataCache

    public init() {
        self.cache = WidgetDataCache()
    }

    /// Fetches insight data for a given type
    public func fetchInsightData(for type: InsightType) async -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        let endDate = Date()
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) else {
            return (nil, nil)
        }

        switch type {
        case .typeQuicker:
            return await fetchTypeQuickerInsight(from: startDate, to: endDate)
        case .atCoder:
            return await fetchAtCoderInsight(from: startDate, to: endDate)
        case .sleep:
            return await fetchSleepInsight(from: startDate, to: endDate)
        case .tasks:
            return await fetchTasksInsight(from: startDate, to: endDate)
        case .anki:
            return await fetchAnkiInsight(from: startDate, to: endDate)
        }
    }

    // MARK: - TypeQuicker

    private func fetchTypeQuickerInsight(from startDate: Date, to endDate: Date) async -> (InsightSummary?, InsightActivityData?) {
        let type = InsightType.typeQuicker
        do {
            let stats: [TypeQuickerStats] = try await cache.fetch(TypeQuickerStats.self, from: startDate, to: endDate)
            guard !stats.isEmpty else { return (nil, nil) }

            // Build summary (WPM by default)
            let dataPoints = stats.map { stat in
                InsightDataPoint(date: stat.date, value: stat.wordsPerMinute)
            }

            let latestWPM = Int(stats.last?.wordsPerMinute ?? 0)
            let trend = calculateTrend(for: stats.map { $0.wordsPerMinute })

            let summary = InsightSummary(
                title: type.displayTitle,
                systemImage: type.systemImage,
                color: type.color,
                dataPoints: dataPoints,
                currentValueFormatted: "\(latestWPM) WPM",
                trend: trend
            )

            // Build activity data (practice time intensity)
            let activityDays = buildActivityDays(from: stats, color: type.color) { Double($0.practiceTimeMinutes) }

            let activityData = InsightActivityData(days: activityDays, emptyColor: .gray.opacity(0.2))

            return (summary, activityData)
        } catch {
            return (nil, nil)
        }
    }

    // MARK: - AtCoder

    private func fetchAtCoderInsight(from startDate: Date, to endDate: Date) async -> (InsightSummary?, InsightActivityData?) {
        let type = InsightType.atCoder
        do {
            let submissions: [AtCoderSubmission] = try await cache.fetch(AtCoderSubmission.self, from: startDate, to: endDate)
            guard !submissions.isEmpty else { return (nil, nil) }

            // Group by date and count accepted submissions
            let calendar = Calendar.current
            var dailyCounts: [Date: Int] = [:]
            for submission in submissions where submission.result == "AC" {
                let day = calendar.startOfDay(for: submission.date)
                dailyCounts[day, default: 0] += 1
            }

            let sortedDates = dailyCounts.keys.sorted()
            let dataPoints = sortedDates.map { date in
                InsightDataPoint(date: date, value: Double(dailyCounts[date] ?? 0))
            }

            let totalAC = submissions.filter { $0.result == "AC" }.count
            let trend = calculateTrend(for: dataPoints.map(\.value))

            let summary = InsightSummary(
                title: type.displayTitle,
                systemImage: type.systemImage,
                color: type.color,
                dataPoints: dataPoints,
                currentValueFormatted: "\(totalAC) AC",
                trend: trend
            )

            // Build activity data
            let maxCount = dailyCounts.values.max() ?? 1
            let activityDays = sortedDates.map { date in
                let count = dailyCounts[date] ?? 0
                let intensity = maxCount > 0 ? Double(count) / Double(maxCount) : 0
                return InsightActivityDay(date: date, color: type.color, intensity: intensity)
            }

            let activityData = InsightActivityData(days: activityDays, emptyColor: .gray.opacity(0.2))

            return (summary, activityData)
        } catch {
            return (nil, nil)
        }
    }

    // MARK: - Sleep

    private func fetchSleepInsight(from startDate: Date, to endDate: Date) async -> (InsightSummary?, InsightActivityData?) {
        let type = InsightType.sleep
        do {
            let sleepData: [SleepDailySummary] = try await cache.fetch(SleepDailySummary.self, from: startDate, to: endDate)
            guard !sleepData.isEmpty else { return (nil, nil) }

            // Build duration range data for sleep
            let rangeDataPoints = sleepData.compactMap { summary -> DurationRangeDataPoint? in
                guard let bedtime = summary.bedtime, let wakeTime = summary.wakeTime else { return nil }
                let segment = DurationSegment(startTime: bedtime, endTime: wakeTime, color: type.color)
                return DurationRangeDataPoint(date: summary.date, segments: [segment])
            }

            guard !rangeDataPoints.isEmpty else { return (nil, nil) }

            // Calculate average sleep duration
            let totalHours = sleepData.reduce(0.0) { $0 + $1.totalSleepHours }
            let avgHours = sleepData.isEmpty ? 0.0 : totalHours / Double(sleepData.count)
            let hours = Int(avgHours)
            let mins = Int((avgHours - Double(hours)) * 60)

            let trend = calculateTrend(for: sleepData.map { $0.totalSleepHours })

            let durationRangeData = InsightDurationRangeData(
                dataPoints: rangeDataPoints,
                defaultColor: type.color,
                dateRange: DateRange.lastDays(14, from: endDate),
                useSimpleHours: false
            )

            let summary = InsightSummary(
                title: type.displayTitle,
                systemImage: type.systemImage,
                color: type.color,
                durationRangeData: durationRangeData,
                currentValueFormatted: "\(hours)h \(mins)m",
                trend: trend
            )

            // Build activity data
            let activityDays = buildActivityDays(from: sleepData, color: type.color) { $0.totalSleepHours }

            let activityData = InsightActivityData(days: activityDays, emptyColor: .gray.opacity(0.2))

            return (summary, activityData)
        } catch {
            return (nil, nil)
        }
    }

    // MARK: - Tasks

    private func fetchTasksInsight(from startDate: Date, to endDate: Date) async -> (InsightSummary?, InsightActivityData?) {
        // Tasks don't use CacheableRecord, so we need to access UserDefaults or return placeholder
        // For now, return nil as tasks data comes from TaskRepository, not the shared cache
        return (nil, nil)
    }

    // MARK: - Anki

    private func fetchAnkiInsight(from startDate: Date, to endDate: Date) async -> (InsightSummary?, InsightActivityData?) {
        let type = InsightType.anki
        do {
            let reviews: [AnkiDailyStats] = try await cache.fetch(AnkiDailyStats.self, from: startDate, to: endDate)
            guard !reviews.isEmpty else { return (nil, nil) }

            // Build data points for reviews
            let dataPoints = reviews.map { review in
                InsightDataPoint(date: review.date, value: Double(review.reviewCount))
            }

            let totalReviews = reviews.reduce(0) { $0 + $1.reviewCount }
            let trend = calculateTrend(for: dataPoints.map(\.value))

            let summary = InsightSummary(
                title: type.displayTitle,
                systemImage: type.systemImage,
                color: type.color,
                dataPoints: dataPoints,
                currentValueFormatted: "\(totalReviews) reviews",
                trend: trend
            )

            // Build activity data
            let activityDays = buildActivityDays(from: reviews, color: type.color) { Double($0.reviewCount) }

            let activityData = InsightActivityData(days: activityDays, emptyColor: .gray.opacity(0.2))

            return (summary, activityData)
        } catch {
            return (nil, nil)
        }
    }

    // MARK: - Helpers

    private func calculateTrend(for values: [Double]) -> Double? {
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

    private func buildActivityDays<T>(
        from records: [T],
        color: Color,
        valueExtractor: (T) -> Double
    ) -> [InsightActivityDay] where T: CacheableRecord {
        let values = records.map(valueExtractor)
        let maxValue = values.max() ?? 1

        return records.map { record in
            let value = valueExtractor(record)
            let intensity = maxValue > 0 ? value / maxValue : 0
            return InsightActivityDay(date: record.recordDate, color: color, intensity: intensity)
        }
    }
}
