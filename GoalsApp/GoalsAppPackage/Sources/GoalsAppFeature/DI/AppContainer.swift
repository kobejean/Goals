import Foundation
import SwiftData
import GoalsDomain
import GoalsData

/// Dependency injection container for the app
@MainActor
@Observable
public final class AppContainer {
    // MARK: - Settings Change Notification

    /// Increments when settings change, observed by views to trigger refresh
    public private(set) var settingsRevision: Int = 0

    /// Call this after saving settings to notify views of changes
    public func notifySettingsChanged() {
        settingsRevision += 1
    }

    // MARK: - ViewModels (lazily created, persist for app lifetime)

    private var _insightsViewModel: InsightsViewModel?

    /// Shared InsightsViewModel - persists across navigation
    public var insightsViewModel: InsightsViewModel {
        if let existing = _insightsViewModel {
            return existing
        }
        let vm = InsightsViewModel(
            typeQuickerDataSource: typeQuickerDataSource,
            atCoderDataSource: atCoderDataSource,
            sleepDataSource: healthKitSleepDataSource,
            goalRepository: goalRepository
        )
        _insightsViewModel = vm
        return vm
    }
    // MARK: - Model Container

    public let modelContainer: ModelContainer

    // MARK: - Repositories

    public let goalRepository: GoalRepositoryProtocol
    public let badgeRepository: BadgeRepositoryProtocol

    // MARK: - Caching

    public let dataCache: DataCache

    // MARK: - Networking

    public let httpClient: HTTPClient

    // MARK: - Data Sources

    public let typeQuickerDataSource: CachedTypeQuickerDataSource
    public let atCoderDataSource: CachedAtCoderDataSource
    public let healthKitSleepDataSource: CachedHealthKitSleepDataSource

    // MARK: - Use Cases

    public let createGoalUseCase: CreateGoalUseCase
    public let syncDataSourcesUseCase: SyncDataSourcesUseCase
    public let badgeEvaluationUseCase: BadgeEvaluationUseCase

    // MARK: - Managers

    public let badgeNotificationManager: BadgeNotificationManager

    // MARK: - Initialization

    public init() throws {
        // Create LOCAL-ONLY cache container FIRST for fast startup
        // This allows cached data to load immediately
        let cacheSchema = Schema([CachedDataEntry.self])
        let cacheConfiguration = ModelConfiguration(
            "CacheStore",
            schema: cacheSchema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // Local only - fast initialization
        )
        let cacheContainer = try ModelContainer(
            for: cacheSchema,
            configurations: [cacheConfiguration]
        )

        // Initialize caching EARLY so data sources can use it
        self.dataCache = DataCache(modelContainer: cacheContainer)

        // Configure SwiftData for CloudKit-synced data (Goals, Badges)
        // NOTE: CloudKit temporarily disabled to fix slow startup from migration
        // Re-enable with .automatic once migration completes
        let cloudSchema = Schema([
            GoalModel.self,
            EarnedBadgeModel.self,
        ])

        let cloudConfiguration = ModelConfiguration(
            schema: cloudSchema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // Temporarily disabled - was causing 30+ second startup
        )

        self.modelContainer = try ModelContainer(
            for: cloudSchema,
            configurations: [cloudConfiguration]
        )

        // Initialize repositories
        let goalRepo = SwiftDataGoalRepository(modelContainer: modelContainer)
        self.goalRepository = goalRepo
        let badgeRepo = SwiftDataBadgeRepository(modelContainer: modelContainer)
        self.badgeRepository = badgeRepo

        // Initialize networking
        self.httpClient = HTTPClient()

        // Initialize data sources with caching
        let remoteTypeQuicker = TypeQuickerDataSource(httpClient: httpClient)
        let remoteAtCoder = AtCoderDataSource(httpClient: httpClient)
        let remoteHealthKitSleep = HealthKitSleepDataSource()

        self.typeQuickerDataSource = CachedTypeQuickerDataSource(
            remote: remoteTypeQuicker,
            cache: dataCache
        )
        self.atCoderDataSource = CachedAtCoderDataSource(
            remote: remoteAtCoder,
            cache: dataCache
        )
        self.healthKitSleepDataSource = CachedHealthKitSleepDataSource(
            remote: remoteHealthKitSleep,
            cache: dataCache
        )

        // Initialize use cases
        self.createGoalUseCase = CreateGoalUseCase(goalRepository: goalRepo)
        self.syncDataSourcesUseCase = SyncDataSourcesUseCase(
            goalRepository: goalRepo,
            dataSources: [
                .typeQuicker: typeQuickerDataSource,
                .atCoder: atCoderDataSource,
                .healthKitSleep: healthKitSleepDataSource
            ]
        )
        self.badgeEvaluationUseCase = BadgeEvaluationUseCase(
            goalRepository: goalRepo,
            badgeRepository: badgeRepo
        )

        // Initialize managers
        self.badgeNotificationManager = BadgeNotificationManager()
    }

    /// Creates an in-memory container for previews and testing
    public static func preview() throws -> AppContainer {
        try AppContainer(inMemory: true)
    }

    private init(inMemory: Bool) throws {
        // Main container for Goals and Badges
        let cloudSchema = Schema([
            GoalModel.self,
            EarnedBadgeModel.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: cloudSchema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )

        self.modelContainer = try ModelContainer(
            for: cloudSchema,
            configurations: [modelConfiguration]
        )

        // Separate container for cache
        let cacheSchema = Schema([CachedDataEntry.self])
        let cacheConfiguration = ModelConfiguration(
            "CacheStore",
            schema: cacheSchema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        let cacheContainer = try ModelContainer(
            for: cacheSchema,
            configurations: [cacheConfiguration]
        )

        let goalRepo = SwiftDataGoalRepository(modelContainer: modelContainer)
        self.goalRepository = goalRepo
        let badgeRepo = SwiftDataBadgeRepository(modelContainer: modelContainer)
        self.badgeRepository = badgeRepo

        // Initialize caching with separate container
        self.dataCache = DataCache(modelContainer: cacheContainer)

        // Initialize networking
        self.httpClient = HTTPClient()

        // Initialize data sources with caching
        let remoteTypeQuicker = TypeQuickerDataSource(httpClient: httpClient)
        let remoteAtCoder = AtCoderDataSource(httpClient: httpClient)
        let remoteHealthKitSleep = HealthKitSleepDataSource()

        self.typeQuickerDataSource = CachedTypeQuickerDataSource(
            remote: remoteTypeQuicker,
            cache: dataCache
        )
        self.atCoderDataSource = CachedAtCoderDataSource(
            remote: remoteAtCoder,
            cache: dataCache
        )
        self.healthKitSleepDataSource = CachedHealthKitSleepDataSource(
            remote: remoteHealthKitSleep,
            cache: dataCache
        )

        self.createGoalUseCase = CreateGoalUseCase(goalRepository: goalRepo)
        self.syncDataSourcesUseCase = SyncDataSourcesUseCase(
            goalRepository: goalRepo,
            dataSources: [
                .typeQuicker: typeQuickerDataSource,
                .atCoder: atCoderDataSource,
                .healthKitSleep: healthKitSleepDataSource
            ]
        )
        self.badgeEvaluationUseCase = BadgeEvaluationUseCase(
            goalRepository: goalRepo,
            badgeRepository: badgeRepo
        )

        // Initialize managers
        self.badgeNotificationManager = BadgeNotificationManager()
    }
}
