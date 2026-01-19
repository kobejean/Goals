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

    // MARK: - ViewModel Factories

    public func makeInsightsViewModels() -> [any InsightsSectionViewModel] {
        [
            TypeQuickerInsightsViewModel(
                dataSource: typeQuickerDataSource,
                goalRepository: goalRepository
            ),
            AtCoderInsightsViewModel(
                dataSource: atCoderDataSource,
                goalRepository: goalRepository
            ),
            SleepInsightsViewModel(
                dataSource: healthKitSleepDataSource,
                goalRepository: goalRepository
            )
        ]
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
        // Configure SwiftData
        let schema = Schema([
            GoalModel.self,
            CachedDataEntry.self,
            EarnedBadgeModel.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        self.modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )

        // Initialize repositories
        let goalRepo = SwiftDataGoalRepository(modelContainer: modelContainer)
        self.goalRepository = goalRepo
        let badgeRepo = SwiftDataBadgeRepository(modelContainer: modelContainer)
        self.badgeRepository = badgeRepo

        // Initialize caching
        self.dataCache = DataCache(modelContainer: modelContainer)

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
        let schema = Schema([
            GoalModel.self,
            CachedDataEntry.self,
            EarnedBadgeModel.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )

        self.modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )

        let goalRepo = SwiftDataGoalRepository(modelContainer: modelContainer)
        self.goalRepository = goalRepo
        let badgeRepo = SwiftDataBadgeRepository(modelContainer: modelContainer)
        self.badgeRepository = badgeRepo

        // Initialize caching
        self.dataCache = DataCache(modelContainer: modelContainer)

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
