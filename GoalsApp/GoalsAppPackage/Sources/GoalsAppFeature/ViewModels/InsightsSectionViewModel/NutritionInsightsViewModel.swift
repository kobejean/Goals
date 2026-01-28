import SwiftUI
import SwiftData
import GoalsDomain
import GoalsCore
import GoalsData
import GoalsWidgetShared

/// ViewModel for Nutrition insights section
@MainActor @Observable
public final class NutritionInsightsViewModel: InsightsSectionViewModel {
    // MARK: - Static Properties

    public let title = "Nutrition"
    public let systemImage = "fork.knife"
    public let color: Color = .green
    public let requiresThrottle = false  // Local SwiftData, no network calls

    // MARK: - Published State

    public private(set) var entries: [NutritionEntry] = []
    public private(set) var insight: (summary: InsightSummary?, activityData: InsightActivityData?) = (nil, nil)
    public private(set) var errorMessage: String?
    public private(set) var fetchStatus: InsightFetchStatus = .idle

    // MARK: - Dependencies

    private let nutritionRepository: NutritionRepositoryProtocol
    private let modelContainer: ModelContainer?

    // MARK: - Initialization

    public init(nutritionRepository: NutritionRepositoryProtocol, modelContainer: ModelContainer? = nil) {
        self.nutritionRepository = nutritionRepository
        self.modelContainer = modelContainer
    }

    // MARK: - Computed Properties

    /// Daily summaries grouped by date
    public var dailySummaries: [NutritionDailySummary] {
        let calendar = Calendar.current
        var entriesByDate: [Date: [NutritionEntry]] = [:]

        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            entriesByDate[day, default: []].append(entry)
        }

        return entriesByDate.map { date, dayEntries in
            NutritionDailySummary(date: date, entries: dayEntries)
        }.sorted { $0.date < $1.date }
    }

    /// Today's total calories
    public var todayTotalCalories: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayEntries = entries.filter { calendar.startOfDay(for: $0.date) == today }
        return todayEntries.reduce(0) { $0 + $1.effectiveNutrients.calories }
    }

    /// Today's total nutrients
    public var todayTotalNutrients: NutrientValues {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayEntries = entries.filter { calendar.startOfDay(for: $0.date) == today }
        return todayEntries.reduce(.zero) { $0 + $1.effectiveNutrients }
    }

    /// Weekly average calories
    public var weeklyAverageCalories: Double? {
        let recentData = dailySummaries.suffix(7)
        guard !recentData.isEmpty else { return nil }
        let total = recentData.reduce(0.0) { $0 + $1.totalNutrients.calories }
        return total / Double(recentData.count)
    }

    /// Calorie trend (percentage change from first half to second half of data)
    public var calorieTrend: Double? {
        dailySummaries.halfTrendPercentage { $0.totalNutrients.calories }
    }

    /// Rebuild insight from current data
    private func rebuildInsight() {
        insight = NutritionInsightProvider.build(from: dailySummaries)
    }

    // MARK: - Filtered Data

    /// Filter entries by time range
    public func filteredEntries(for timeRange: TimeRange) -> [NutritionEntry] {
        let cutoffDate = timeRange.startDate(from: Date())
        let filtered = entries.filter { $0.date >= cutoffDate }

        // For "all" time range, limit to most recent 500 entries
        if timeRange == .all && filtered.count > 500 {
            return Array(filtered.suffix(500))
        }
        return filtered
    }

    /// Filter daily summaries by time range
    public func filteredDailySummaries(for timeRange: TimeRange) -> [NutritionDailySummary] {
        let cutoffDate = timeRange.startDate(from: Date())
        let filtered = dailySummaries.filter { $0.date >= cutoffDate }

        // For "all" time range, limit to 90 days for chart performance
        if timeRange == .all && filtered.count > 90 {
            return Array(filtered.suffix(90))
        }
        return filtered
    }

    /// Calculate 7-day moving average for calories
    public func movingAverageData(for summaries: [NutritionDailySummary]) -> [(date: Date, value: Double)] {
        let data = summaries.map { (date: $0.date, value: $0.totalCalories) }
        return InsightCalculations.calculateMovingAverage(for: data, window: 7)
    }

    /// Calculate Y-axis range for chart
    public func chartYAxisRange(for summaries: [NutritionDailySummary]) -> ClosedRange<Double> {
        let values = summaries.map { $0.totalCalories }
        guard let minVal = values.min(), let maxVal = values.max() else {
            return 0...2000
        }
        let padding = (maxVal - minVal) * 0.1
        return max(0, minVal - padding)...(maxVal + padding)
    }

    // MARK: - Data Loading

    public func loadCachedData() async {
        let endDate = Date()
        let startDate = TimeRange.all.startDate(from: endDate)

        do {
            entries = try await nutritionRepository.fetchEntries(from: startDate, to: endDate)
            if !entries.isEmpty {
                rebuildInsight()
                fetchStatus = .success
            }
        } catch {
            // Silently fail for cached data loading
        }
    }

    public func loadData() async {
        errorMessage = nil
        fetchStatus = .loading

        let endDate = Date()
        let startDate = TimeRange.all.startDate(from: endDate)

        do {
            entries = try await nutritionRepository.fetchEntries(from: startDate, to: endDate)
            rebuildInsight()
            fetchStatus = .success

            // Cache daily summaries for widget access
            await cacheDataForWidget()
        } catch {
            errorMessage = "Failed to load nutrition data: \(error.localizedDescription)"
            fetchStatus = .error
        }
    }

    /// Cache nutrition daily summaries to shared storage for widget access
    private func cacheDataForWidget() async {
        guard let container = modelContainer else { return }

        do {
            try NutritionDailySummaryModel.store(dailySummaries, in: container)
        } catch {
            // Silently fail - widget will just not have nutrition data
            print("NutritionInsightsViewModel: Failed to cache data for widget: \(error)")
        }
    }

    // MARK: - Formatting Helpers

    public func formatCalories(_ calories: Double) -> String {
        "\(Int(calories)) kcal"
    }
}

// MARK: - Array Extension for Trend Calculation

extension Array where Element == NutritionDailySummary {
    /// Calculate half trend percentage (change from first half to second half)
    func halfTrendPercentage(_ value: (Element) -> Double) -> Double? {
        guard count >= 4 else { return nil }

        let midpoint = count / 2
        let firstHalf = self[0..<midpoint]
        let secondHalf = self[midpoint...]

        let firstAverage = firstHalf.reduce(0.0) { $0 + value($1) } / Double(firstHalf.count)
        let secondAverage = secondHalf.reduce(0.0) { $0 + value($1) } / Double(secondHalf.count)

        guard firstAverage > 0 else { return nil }
        return ((secondAverage - firstAverage) / firstAverage) * 100
    }
}
