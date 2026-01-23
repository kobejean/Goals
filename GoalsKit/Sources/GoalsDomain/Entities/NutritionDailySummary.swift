import Foundation

/// Daily summary of nutrition entries
public struct NutritionDailySummary: Sendable, Equatable, Codable, Identifiable {
    public var id: Date { date }

    /// Date for this summary (start of day)
    public let date: Date

    /// All nutrition entries for this day
    public let entries: [NutritionEntry]

    public init(date: Date, entries: [NutritionEntry]) {
        self.date = Calendar.current.startOfDay(for: date)
        self.entries = entries
    }

    /// Total nutrients for the day (sum of all entries with portion multipliers applied)
    public var totalNutrients: NutrientValues {
        entries.reduce(.zero) { $0 + $1.effectiveNutrients }
    }

    /// Number of entries logged
    public var entryCount: Int {
        entries.count
    }

    /// Total calories for the day
    public var totalCalories: Double {
        totalNutrients.calories
    }
}

// MARK: - CacheableRecord Conformance

extension NutritionDailySummary: CacheableRecord {
    public static var dataSource: DataSourceType { .nutrition }
    public static var recordType: String { "daily" }

    private static let cacheKeyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    public var cacheKey: String {
        "nutrition:daily:\(Self.cacheKeyDateFormatter.string(from: date))"
    }

    public var recordDate: Date { date }
}

// MARK: - Collection Helpers

extension Array where Element == NutritionDailySummary {
    /// Calculate total nutrients across all summaries
    public var totalNutrients: NutrientValues {
        reduce(.zero) { $0 + $1.totalNutrients }
    }

    /// Calculate average daily calories
    public var averageDailyCalories: Double {
        guard !isEmpty else { return 0 }
        return totalNutrients.calories / Double(count)
    }

    /// Calculate average daily protein
    public var averageDailyProtein: Double {
        guard !isEmpty else { return 0 }
        return totalNutrients.protein / Double(count)
    }
}
