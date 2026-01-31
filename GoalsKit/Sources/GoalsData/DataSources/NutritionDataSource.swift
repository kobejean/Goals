import Foundation
import GoalsDomain

/// Data source for nutrition tracking metrics
/// Since nutrition data is stored locally, this doesn't need remote/caching layers
@MainActor
public final class NutritionDataSource: DataSourceRepositoryProtocol, Sendable {
    public let dataSourceType: DataSourceType = .nutrition

    private let nutritionRepository: NutritionRepositoryProtocol

    public nonisolated var availableMetrics: [MetricInfo] {
        [
            MetricInfo(key: "calories", name: "Daily Calories", unit: "kcal", icon: "flame"),
            MetricInfo(key: "protein", name: "Daily Protein", unit: "g", icon: "fish"),
            MetricInfo(key: "carbs", name: "Daily Carbs", unit: "g", icon: "leaf"),
            MetricInfo(key: "fat", name: "Daily Fat", unit: "g", icon: "drop.fill", direction: .decrease),
            MetricInfo(key: "fiber", name: "Daily Fiber", unit: "g", icon: "circle.hexagongrid"),
            MetricInfo(key: "sugar", name: "Daily Sugar", unit: "g", icon: "cube", direction: .decrease),
        ]
    }

    public init(nutritionRepository: NutritionRepositoryProtocol) {
        self.nutritionRepository = nutritionRepository
    }

    // MARK: - Configuration (always configured since data is local)

    public func isConfigured() async -> Bool {
        true
    }

    public func configure(settings: DataSourceSettings) async throws {
        // No configuration needed - data is local
    }

    public func clearConfiguration() async throws {
        // No configuration to clear
    }

    // MARK: - Metric Fetching

    public func fetchLatestMetricValue(for metricKey: String, taskId: UUID?) async throws -> Double? {
        guard let summary = try await nutritionRepository.fetchTodaySummary() else {
            return nil
        }

        let nutrients = summary.totalNutrients

        switch metricKey {
        case "calories":
            return nutrients.calories

        case "protein":
            return nutrients.protein

        case "carbs":
            return nutrients.carbohydrates

        case "fat":
            return nutrients.fat

        case "fiber":
            return nutrients.fiber

        case "sugar":
            return nutrients.sugar

        default:
            return nil
        }
    }

    public nonisolated func metricValue(for key: String, from stats: Any) -> Double? {
        // For nutrition, we don't have a stats object - data comes directly from repository
        nil
    }
}
