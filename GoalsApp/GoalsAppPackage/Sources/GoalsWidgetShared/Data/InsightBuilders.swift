import Foundation
import SwiftUI
import GoalsDomain

/// Shared insight summary builders - single source of truth
/// Used by both app ViewModels and WidgetDataProvider
public enum InsightBuilders {

    // MARK: - TypeQuicker

    /// Build TypeQuicker insight from stats
    /// Uses WPM vs Accuracy chart showing both primary modes
    /// - Parameters:
    ///   - stats: Array of TypeQuicker stats
    ///   - goals: Optional array of goals for goal line display
    /// - Returns: Tuple of optional summary and activity data
    public static func buildTypeQuickerInsight(
        from stats: [TypeQuickerStats],
        goals: [Goal] = []
    ) -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard !stats.isEmpty else { return (nil, nil) }

        let type = InsightType.typeQuicker

        // Build WPM vs Accuracy data points from mode stats
        var wpmAccuracyPoints: [InsightWPMAccuracyPoint] = []

        for stat in stats {
            if let byMode = stat.byMode {
                // Use per-mode stats when available
                for modeStat in byMode {
                    wpmAccuracyPoints.append(InsightWPMAccuracyPoint(
                        date: stat.date,
                        mode: modeStat.mode,
                        wpm: modeStat.wordsPerMinute,
                        accuracy: modeStat.accuracy
                    ))
                }
            } else {
                // Fallback to overall stats
                wpmAccuracyPoints.append(InsightWPMAccuracyPoint(
                    date: stat.date,
                    mode: "overall",
                    wpm: stat.wordsPerMinute,
                    accuracy: stat.accuracy
                ))
            }
        }

        // Define mode colors
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
        let trend = calculateTrend(for: stats.map { $0.wordsPerMinute })

        let summary = InsightSummary(
            title: type.displayTitle,
            systemImage: type.systemImage,
            color: type.color,
            wpmAccuracyData: wpmAccuracyData,
            currentValueFormatted: "\(latestWPM) WPM · \(latestAccuracy)%",
            trend: trend
        )

        // Build activity data (practice time intensity)
        let activityDays = buildActivityDays(from: stats, color: type.color) { Double($0.practiceTimeMinutes) }
        let activityData = InsightActivityData(days: activityDays, emptyColor: .gray.opacity(0.2))

        return (summary, activityData)
    }

    // MARK: - AtCoder

    /// Build AtCoder insight from contest history and daily effort
    /// - Parameters:
    ///   - contestHistory: Array of contest results (rating over time)
    ///   - dailyEffort: Array of daily effort data for activity chart
    ///   - goals: Optional array of goals for goal line display
    /// - Returns: Tuple of optional summary and activity data
    public static func buildAtCoderInsight(
        from contestHistory: [AtCoderContestResult],
        dailyEffort: [AtCoderDailyEffort] = [],
        goals: [Goal] = []
    ) -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard !contestHistory.isEmpty else { return (nil, nil) }

        let type = InsightType.atCoder

        // Build data points showing rating over time with rank colors
        let dataPoints = contestHistory.map { contest in
            InsightDataPoint(
                date: contest.date,
                value: Double(contest.rating),
                color: contest.rankColor.swiftUIColor
            )
        }

        let currentRating = contestHistory.last?.rating ?? 0
        let currentColor = contestHistory.last?.rankColor.swiftUIColor ?? .gray
        let trend = calculateTrend(for: contestHistory.map { Double($0.rating) })
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
                // Find hardest difficulty solved that day
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
            // Fallback: use contest history for activity
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

    // MARK: - Sleep

    /// Build Sleep insight from daily summaries
    /// - Parameters:
    ///   - sleepData: Array of sleep daily summaries
    ///   - goals: Optional array of goals for goal line display
    /// - Returns: Tuple of optional summary and activity data
    public static func buildSleepInsight(
        from sleepData: [SleepDailySummary],
        goals: [Goal] = []
    ) -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard !sleepData.isEmpty else { return (nil, nil) }

        let type = InsightType.sleep

        // Limit to last 14 entries for duration range chart readability
        let recentData = Array(sleepData.suffix(14))

        // Build duration range data for sleep
        let rangeDataPoints = recentData.compactMap { summary -> DurationRangeDataPoint? in
            guard let bedtime = summary.bedtime, let wakeTime = summary.wakeTime else { return nil }
            let segment = DurationSegment(startTime: bedtime, endTime: wakeTime, color: type.color)
            return DurationRangeDataPoint(date: summary.date, segments: [segment])
        }

        guard !rangeDataPoints.isEmpty else { return (nil, nil) }

        // Use last night's sleep for current value display
        let currentHours = sleepData.last?.totalSleepHours ?? 0

        let trend = calculateTrend(for: sleepData.map { $0.totalSleepHours })

        let durationRangeData = InsightDurationRangeData(
            dataPoints: rangeDataPoints,
            defaultColor: type.color,
            useSimpleHours: false
        )

        let summary = InsightSummary(
            title: type.displayTitle,
            systemImage: type.systemImage,
            color: type.color,
            durationRangeData: durationRangeData,
            currentValueFormatted: formatSleepHours(currentHours),
            trend: trend
        )

        // Build activity data
        let targetHours = goals.targetValue(for: "sleepDuration") ?? 8.0
        let activityDays = sleepData.map { summary in
            let intensity = min(summary.totalSleepHours / targetHours, 1.0)
            return InsightActivityDay(date: summary.date, color: type.color, intensity: intensity)
        }

        let activityData = InsightActivityData(days: activityDays, emptyColor: .gray.opacity(0.2))

        return (summary, activityData)
    }

    // MARK: - Tasks

    /// Build Tasks insight from cached daily summaries
    /// - Parameters:
    ///   - dailySummaries: Array of task daily summaries
    ///   - goals: Optional array of goals for target display
    /// - Returns: Tuple of optional summary and activity data
    public static func buildTasksInsight(
        from dailySummaries: [TaskDailySummary],
        goals: [Goal] = []
    ) -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard !dailySummaries.isEmpty else { return (nil, nil) }

        let type = InsightType.tasks

        // Fixed 10-day date range for consistent X-axis
        let dateRange = DateRange.lastDays(10)
        let calendar = Calendar.current

        // Filter data to the date range (comparing start of day)
        let rangeStart = calendar.startOfDay(for: dateRange.start)
        let rangeEnd = calendar.startOfDay(for: dateRange.end)

        let recentData = dailySummaries.filter { summary in
            let day = calendar.startOfDay(for: summary.date)
            return day >= rangeStart && day <= rangeEnd
        }

        let rangeDataPoints = recentData.map { summary in
            summary.toDurationRangeDataPoint()
        }

        let durationRangeData = InsightDurationRangeData(
            dataPoints: rangeDataPoints,
            defaultColor: type.color,
            dateRange: dateRange,
            useSimpleHours: true
        )

        // Calculate today's hours
        let today = calendar.startOfDay(for: Date())
        let todayTotalHours = dailySummaries
            .filter { calendar.startOfDay(for: $0.date) == today }
            .reduce(0.0) { $0 + $1.totalDuration / 3600.0 }

        // Calculate trend
        let trend = calculateTrend(for: dailySummaries.map { $0.totalDuration / 3600.0 })

        let summary = InsightSummary(
            title: type.displayTitle,
            systemImage: type.systemImage,
            color: type.color,
            durationRangeData: durationRangeData,
            currentValueFormatted: formatTaskHours(todayTotalHours),
            trend: trend
        )

        // Build activity data (daily hours as intensity)
        // Use goal target or 4 hours as default "full" intensity reference
        let targetHours = goals.targetValue(for: "dailyDuration").map { $0 / 60.0 } ?? 4.0

        let activityDays = dailySummaries.map { summary in
            let hours = summary.totalDuration / 3600.0
            let intensity = min(hours / targetHours, 1.0)

            return InsightActivityDay(
                date: summary.date,
                color: type.color,
                intensity: intensity
            )
        }

        let activityData = InsightActivityData(days: activityDays, emptyColor: .gray.opacity(0.2))

        return (summary, activityData)
    }

    /// Format task hours for display
    /// - Parameter hours: Duration in hours
    /// - Returns: Formatted string like "2h" or "1h 30m"
    public static func formatTaskHours(_ hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h == 0 && m == 0 {
            return "0m"
        }
        if h == 0 {
            return "\(m)m"
        }
        if m == 0 {
            return "\(h)h"
        }
        return "\(h)h \(m)m"
    }

    // MARK: - Anki

    /// Build Anki insight from daily stats
    /// Uses scatter + moving average chart with streak display (matching app)
    /// - Parameters:
    ///   - stats: Array of Anki daily stats
    ///   - goals: Optional array of goals for goal line display
    /// - Returns: Tuple of optional summary and activity data
    public static func buildAnkiInsight(
        from stats: [AnkiDailyStats],
        goals: [Goal] = []
    ) -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard !stats.isEmpty else { return (nil, nil) }

        let type = InsightType.anki

        // Filter to last 30 days for the card
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let last30DaysStats = stats.filter { $0.date >= cutoffDate }

        // Raw scatter points (last 30 days)
        let scatterPoints = last30DaysStats.map { stat in
            InsightDataPoint(date: stat.date, value: Double(stat.reviewCount))
        }

        // Calculate moving average from filtered data only (matches in-app chart behavior)
        let movingAverageData = calculateMovingAverage(
            for: last30DaysStats.map { (date: $0.date, value: Double($0.reviewCount)) },
            window: 30
        )
        let movingAveragePoints = movingAverageData.map {
            InsightDataPoint(date: $0.date, value: $0.value)
        }

        let currentStreak = stats.currentStreak()
        let trend = calculateTrend(for: stats.map { Double($0.reviewCount) })
        let goalValue = goals.targetValue(for: "dailyReviews")

        let summary = InsightSummary(
            title: type.displayTitle,
            systemImage: type.systemImage,
            color: type.color,
            scatterPoints: scatterPoints,
            movingAveragePoints: movingAveragePoints,
            currentValueFormatted: "\(currentStreak) Day Streak",
            trend: trend,
            goalValue: goalValue
        )

        // Build activity data
        let activityDays = buildActivityDays(from: stats, color: type.color) { Double($0.reviewCount) }
        let activityData = InsightActivityData(days: activityDays, emptyColor: .gray.opacity(0.2))

        return (summary, activityData)
    }

    // MARK: - Zotero

    /// Build Zotero insight from daily stats and optional reading status
    /// Uses scatter + moving average chart showing reading progress score
    /// Score formula: toRead×0.25 + inProgress×0.5 + read×1.0
    /// - Parameters:
    ///   - stats: Array of Zotero daily stats (annotations/notes/reading progress)
    ///   - readingStatus: Optional reading status for collection counts
    ///   - goals: Optional array of goals for goal line display
    /// - Returns: Tuple of optional summary and activity data
    public static func buildZoteroInsight(
        from stats: [ZoteroDailyStats],
        readingStatus: ZoteroReadingStatus? = nil,
        goals: [Goal] = []
    ) -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard !stats.isEmpty else { return (nil, nil) }

        let type = InsightType.zotero

        // Filter to last 30 days for the card
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let last30DaysStats = stats.filter { $0.date >= cutoffDate }

        // Raw scatter points (last 30 days) showing weighted activity points
        let scatterPoints = last30DaysStats.map { stat in
            InsightDataPoint(date: stat.date, value: stat.weightedPoints)
        }

        // Calculate moving average from filtered data only (matches in-app chart behavior)
        let movingAverageData = calculateMovingAverage(
            for: last30DaysStats.map { (date: $0.date, value: $0.weightedPoints) },
            window: 30
        )
        let movingAveragePoints = movingAverageData.map {
            InsightDataPoint(date: $0.date, value: $0.value)
        }

        // Determine display value: reading progress or streak
        let currentValueFormatted: String
        if let status = readingStatus, status.totalItems > 0 {
            currentValueFormatted = "\(status.readCount)/\(status.totalItems) Read"
        } else {
            let currentStreak = stats.currentStreak()
            currentValueFormatted = "\(currentStreak) Day Streak"
        }

        let trend = calculateTrend(for: stats.map { $0.weightedPoints })
        let goalValue = goals.targetValue(for: "dailyAnnotations")

        let summary = InsightSummary(
            title: type.displayTitle,
            systemImage: type.systemImage,
            color: type.color,
            scatterPoints: scatterPoints,
            movingAveragePoints: movingAveragePoints,
            currentValueFormatted: currentValueFormatted,
            trend: trend,
            goalValue: goalValue
        )

        // Build activity data using weighted activity points as intensity
        let activityDays = buildActivityDays(from: stats, color: type.color) { $0.weightedPoints }
        let activityData = InsightActivityData(days: activityDays, emptyColor: .gray.opacity(0.2))

        return (summary, activityData)
    }

    // MARK: - Nutrition

    // Daily macro targets in grams
    private static let dailyMacroTargets = (protein: 150.0, carbs: 250.0, fat: 65.0)

    /// Build Nutrition insight from daily summaries
    /// Shows radar chart with macro breakdown + calorie sparkline
    /// - Parameters:
    ///   - summaries: Array of nutrition daily summaries
    ///   - goals: Optional array of goals for goal line display
    /// - Returns: Tuple of optional summary and activity data
    public static func buildNutritionInsight(
        from summaries: [NutritionDailySummary],
        goals: [Goal] = []
    ) -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard !summaries.isEmpty else { return (nil, nil) }

        let type = InsightType.nutrition
        let calendar = Calendar.current

        // Filter to last 30 days for the card
        let cutoffDate = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let last30DaysSummaries = summaries.filter { $0.date >= cutoffDate }

        // Raw scatter points (last 30 days)
        let scatterPoints = last30DaysSummaries.map { summary in
            InsightDataPoint(date: summary.date, value: summary.totalCalories)
        }

        // Calculate moving average from filtered data only (matches in-app chart behavior)
        let movingAverageData = calculateMovingAverage(
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

        // Build macro radar data from today's values
        let macroRadarData = MacroRadarData(
            current: (todayNutrients.protein, todayNutrients.carbohydrates, todayNutrients.fat),
            ideal: dailyMacroTargets
        )

        let trend = calculateTrend(for: summaries.map { $0.totalCalories })
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

        // Build activity data (calories as intensity relative to max)
        let activityDays = buildActivityDays(from: summaries, color: type.color) { $0.totalCalories }
        let activityData = InsightActivityData(days: activityDays, emptyColor: .gray.opacity(0.2))

        return (summary, activityData)
    }

    // MARK: - Shared Helpers

    /// Calculate trend percentage comparing recent values to previous values
    /// Uses a sliding window approach: compare average of last N values to average of previous N values
    /// - Parameter values: Array of numeric values to calculate trend for
    /// - Returns: Percentage change, or nil if insufficient data
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

    /// Build activity days from cacheable records
    /// - Parameters:
    ///   - records: Array of records conforming to CacheableRecord
    ///   - color: Color for the activity squares
    ///   - valueExtractor: Closure to extract numeric value from each record
    /// - Returns: Array of InsightActivityDay for contribution chart
    private static func buildActivityDays<T: CacheableRecord>(
        from records: [T],
        color: Color,
        valueExtractor: (T) -> Double
    ) -> [InsightActivityDay] {
        let values = records.map(valueExtractor)
        let maxValue = values.max() ?? 1

        return records.map { record in
            let value = valueExtractor(record)
            let intensity = maxValue > 0 ? value / maxValue : 0
            return InsightActivityDay(date: record.recordDate, color: color, intensity: intensity)
        }
    }

    /// Format sleep hours for display
    /// - Parameter hours: Sleep duration in hours
    /// - Returns: Formatted string like "8h" or "7h 30m"
    public static func formatSleepHours(_ hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if m == 0 {
            return "\(h)h"
        }
        return "\(h)h \(m)m"
    }

    /// Calculate moving average for a series of data points
    /// Days with no data are treated as 0
    /// - Parameters:
    ///   - data: Array of date-value tuples
    ///   - window: Window size for moving average
    /// - Returns: Array of date-value tuples with moving average values
    public static func calculateMovingAverage(
        for data: [(date: Date, value: Double)],
        window: Int
    ) -> [(date: Date, value: Double)] {
        guard !data.isEmpty else { return [] }

        let calendar = Calendar.current
        let sorted = data.sorted { $0.date < $1.date }

        // Create a lookup dictionary for values by date
        var valuesByDate: [Date: Double] = [:]
        for point in sorted {
            let day = calendar.startOfDay(for: point.date)
            valuesByDate[day] = point.value
        }

        // Get the date range
        guard let firstDate = sorted.first?.date,
              let lastDate = sorted.last?.date else { return [] }

        let startDay = calendar.startOfDay(for: firstDate)
        let endDay = calendar.startOfDay(for: lastDate)

        // Build continuous series with zeros for missing days
        var continuousSeries: [(date: Date, value: Double)] = []
        var currentDay = startDay
        while currentDay <= endDay {
            let value = valuesByDate[currentDay] ?? 0.0
            continuousSeries.append((date: currentDay, value: value))
            currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay) ?? currentDay
        }

        // Calculate moving average
        var result: [(date: Date, value: Double)] = []
        for i in 0..<continuousSeries.count {
            let windowStart = Swift.max(0, i - window + 1)
            let windowData = continuousSeries[windowStart...i]
            let average = windowData.reduce(0.0) { $0 + $1.value } / Double(windowData.count)
            result.append((date: continuousSeries[i].date, value: average))
        }

        return result
    }
}

