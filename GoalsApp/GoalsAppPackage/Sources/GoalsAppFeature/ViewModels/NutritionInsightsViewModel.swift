import SwiftUI
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
    public private(set) var errorMessage: String?
    public private(set) var fetchStatus: InsightFetchStatus = .idle

    // MARK: - Dependencies

    private let nutritionRepository: NutritionRepositoryProtocol

    // MARK: - Initialization

    public init(nutritionRepository: NutritionRepositoryProtocol) {
        self.nutritionRepository = nutritionRepository
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

    /// Summary data for the overview card (uses shared InsightBuilders for consistency with widgets)
    public var summary: InsightSummary? {
        InsightBuilders.buildNutritionInsight(from: dailySummaries).summary
    }

    /// Activity data for GitHub-style contribution chart (uses shared InsightBuilders for consistency with widgets)
    public var activityData: InsightActivityData? {
        InsightBuilders.buildNutritionInsight(from: dailySummaries).activityData
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

    // MARK: - Data Loading

    public func loadCachedData() async {
        let endDate = Date()
        let startDate = TimeRange.all.startDate(from: endDate)

        do {
            entries = try await nutritionRepository.fetchEntries(from: startDate, to: endDate)
            if !entries.isEmpty {
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
            fetchStatus = .success
        } catch {
            errorMessage = "Failed to load nutrition data: \(error.localizedDescription)"
            fetchStatus = .error
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
