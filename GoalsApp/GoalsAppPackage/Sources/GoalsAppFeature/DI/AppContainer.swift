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

    /// Get available metrics for a data source type
    public func availableMetrics(for dataSource: DataSourceType) -> [MetricInfo] {
        switch dataSource {
        case .typeQuicker: return typeQuickerDataSource.availableMetrics
        case .atCoder: return atCoderDataSource.availableMetrics
        case .healthKitSleep: return healthKitSleepDataSource.availableMetrics
        }
    }

    /// Configure all data sources from stored settings
    /// Call this before syncing to ensure data sources are ready
    public func configureDataSources() async {
        // Configure TypeQuicker
        if let username = UserDefaults.standard.typeQuickerUsername, !username.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .typeQuicker,
                credentials: ["username": username]
            )
            try? await typeQuickerDataSource.configure(settings: settings)
        }

        // Configure AtCoder
        if let username = UserDefaults.standard.atCoderUsername, !username.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .atCoder,
                credentials: ["username": username]
            )
            try? await atCoderDataSource.configure(settings: settings)
        }

        // HealthKit doesn't need configuration - it uses system authorization
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

    public convenience init() throws {
        try self.init(inMemory: false)
    }

    /// Creates an in-memory container for previews and testing
    public static func preview() throws -> AppContainer {
        try AppContainer(inMemory: true)
    }

    private init(inMemory: Bool) throws {
        // Create LOCAL-ONLY cache container FIRST for fast startup
        let cacheSchema = Schema([CachedDataEntry.self])
        let cacheConfiguration = ModelConfiguration(
            "CacheStore",
            schema: cacheSchema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none  // Local only - fast initialization
        )
        let cacheContainer = try ModelContainer(
            for: cacheSchema,
            configurations: [cacheConfiguration]
        )

        // Initialize caching EARLY so data sources can use it
        self.dataCache = DataCache(modelContainer: cacheContainer)

        // Configure SwiftData for Goals and Badges
        // NOTE: CloudKit temporarily disabled to fix slow startup from migration
        // Re-enable with .automatic once migration completes
        let mainSchema = Schema([
            GoalModel.self,
            EarnedBadgeModel.self,
        ])

        let mainConfiguration = ModelConfiguration(
            schema: mainSchema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none  // Temporarily disabled - was causing 30+ second startup
        )

        self.modelContainer = try ModelContainer(
            for: mainSchema,
            configurations: [mainConfiguration]
        )

        // Initialize repositories
        let goalRepo = SwiftDataGoalRepository(modelContainer: modelContainer)
        self.goalRepository = goalRepo
        let badgeRepo = SwiftDataBadgeRepository(modelContainer: modelContainer)
        self.badgeRepository = badgeRepo

        // Initialize networking
        self.httpClient = HTTPClient()

        // Initialize data sources with caching
        self.typeQuickerDataSource = CachedTypeQuickerDataSource(
            remote: TypeQuickerDataSource(httpClient: httpClient),
            cache: dataCache
        )
        self.atCoderDataSource = CachedAtCoderDataSource(
            remote: AtCoderDataSource(httpClient: httpClient),
            cache: dataCache
        )
        self.healthKitSleepDataSource = CachedHealthKitSleepDataSource(
            remote: HealthKitSleepDataSource(),
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
}
