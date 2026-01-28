import Foundation
import SwiftData

/// Extension providing data fetching capability for InsightType.
/// Uses InsightProvider registry to eliminate switch statements.
extension InsightType {
    /// Registry mapping insight types to their providers
    private static let providerTypes: [InsightType: any InsightProvider.Type] = [
        .typeQuicker: TypeQuickerInsightProvider.self,
        .atCoder: AtCoderInsightProvider.self,
        .sleep: SleepInsightProvider.self,
        .tasks: TasksInsightProvider.self,
        .anki: AnkiInsightProvider.self,
        .zotero: ZoteroInsightProvider.self,
        .nutrition: NutritionInsightProvider.self,
    ]

    /// Convenience method that creates a shared container and fetches insight data.
    /// This is the simplest API for widget use - just call `type.fetchInsight()`.
    /// - Returns: Tuple of optional summary and activity data
    public func fetchInsight() -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard let container = SharedStorage.createWidgetModelContainer() else {
            return (nil, nil)
        }
        return fetchAndBuildInsight(from: container)
    }

    /// Fetches data and builds insight summary for this insight type.
    /// - Parameter container: The ModelContainer to fetch data from
    /// - Returns: Tuple of optional summary and activity data
    public func fetchAndBuildInsight(from container: ModelContainer) -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard let providerType = Self.providerTypes[self] else {
            return (nil, nil)
        }
        let provider = providerType.init(container: container)
        provider.load()
        return (provider.summary, provider.activityData)
    }
}
