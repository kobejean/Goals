import Foundation
import SwiftData

/// Unified SwiftData schema containing all models for the single store architecture.
/// This schema should be used everywhere a ModelContainer is created to ensure consistency.
public enum UnifiedSchema {
    /// All SwiftData model types in the unified schema
    public static let allModels: [any PersistentModel.Type] = [
        // User data models
        GoalModel.self,
        EarnedBadgeModel.self,
        TaskDefinitionModel.self,
        TaskSessionModel.self,
        NutritionEntryModel.self,

        // Cached external data models
        TypeQuickerStatsModel.self,
        AtCoderContestResultModel.self,
        AtCoderSubmissionModel.self,
        AtCoderDailyEffortModel.self,
        AnkiDailyStatsModel.self,
        ZoteroDailyStatsModel.self,
        ZoteroReadingStatusModel.self,
        SleepDailySummaryModel.self,
        TaskDailySummaryModel.self,
        NutritionDailySummaryModel.self,
    ]

    /// Creates the unified schema containing all models
    public static func createSchema() -> Schema {
        Schema(allModels)
    }

    /// Creates a model configuration for the main store
    /// - Parameters:
    ///   - url: Optional URL for the store. If nil, uses default location.
    ///   - inMemory: Whether to use in-memory storage (for testing/previews)
    ///   - cloudKit: CloudKit database configuration
    /// - Returns: A configured ModelConfiguration
    public static func createConfiguration(
        url: URL? = nil,
        inMemory: Bool = false,
        cloudKit: ModelConfiguration.CloudKitDatabase = .none
    ) -> ModelConfiguration {
        let schema = createSchema()

        if inMemory {
            return ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: cloudKit
            )
        } else if let url = url {
            return ModelConfiguration(
                schema: schema,
                url: url,
                cloudKitDatabase: cloudKit
            )
        } else {
            return ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: cloudKit
            )
        }
    }

    /// Creates a ModelContainer with the unified schema
    /// - Parameters:
    ///   - url: Optional URL for the store. If nil, uses default location.
    ///   - inMemory: Whether to use in-memory storage (for testing/previews)
    ///   - cloudKit: CloudKit database configuration
    /// - Returns: A configured ModelContainer
    public static func createContainer(
        url: URL? = nil,
        inMemory: Bool = false,
        cloudKit: ModelConfiguration.CloudKitDatabase = .none
    ) throws -> ModelContainer {
        let schema = createSchema()
        let configuration = createConfiguration(url: url, inMemory: inMemory, cloudKit: cloudKit)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
