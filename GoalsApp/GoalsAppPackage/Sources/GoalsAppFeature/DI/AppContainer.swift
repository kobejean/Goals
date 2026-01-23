import Foundation
import SwiftData
import WidgetKit
import GoalsDomain
import GoalsData
import GoalsWidgetShared

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
        case .tasks: return tasksDataSource.availableMetrics
        case .anki: return ankiDataSource.availableMetrics
        case .zotero: return zoteroDataSource.availableMetrics
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

        // Configure Anki
        if let host = UserDefaults.standard.ankiHost, !host.isEmpty {
            let port = UserDefaults.standard.ankiPort ?? "8765"
            let decks = UserDefaults.standard.ankiDecks ?? ""
            let settings = DataSourceSettings(
                dataSourceType: .anki,
                options: ["host": host, "port": port, "decks": decks]
            )
            try? await ankiDataSource.configure(settings: settings)
        }

        // Configure Zotero
        if let apiKey = UserDefaults.standard.zoteroAPIKey, !apiKey.isEmpty,
           let userID = UserDefaults.standard.zoteroUserID, !userID.isEmpty {
            let toReadCollection = UserDefaults.standard.zoteroToReadCollection ?? ""
            let inProgressCollection = UserDefaults.standard.zoteroInProgressCollection ?? ""
            let readCollection = UserDefaults.standard.zoteroReadCollection ?? ""
            let settings = DataSourceSettings(
                dataSourceType: .zotero,
                credentials: ["apiKey": apiKey, "userID": userID],
                options: [
                    "toReadCollection": toReadCollection,
                    "inProgressCollection": inProgressCollection,
                    "readCollection": readCollection
                ]
            )
            try? await zoteroDataSource.configure(settings: settings)
        }

        // HealthKit doesn't need configuration - it uses system authorization
    }

    // MARK: - ViewModels (lazily created, persist for app lifetime)

    private var _insightsViewModel: InsightsViewModel?
    private var _tasksViewModel: TasksViewModel?

    /// Shared InsightsViewModel - persists across navigation
    public var insightsViewModel: InsightsViewModel {
        if let existing = _insightsViewModel {
            return existing
        }
        let vm = InsightsViewModel(
            typeQuickerDataSource: typeQuickerDataSource,
            atCoderDataSource: atCoderDataSource,
            sleepDataSource: healthKitSleepDataSource,
            taskRepository: taskRepository,
            goalRepository: goalRepository,
            ankiDataSource: ankiDataSource,
            zoteroDataSource: zoteroDataSource,
            taskCachingService: taskCachingService
        )
        _insightsViewModel = vm
        return vm
    }

    /// Shared TasksViewModel - persists across navigation
    public var tasksViewModel: TasksViewModel {
        if let existing = _tasksViewModel {
            return existing
        }
        let vm = TasksViewModel(
            taskRepository: taskRepository,
            taskCachingService: taskCachingService
        )
        _tasksViewModel = vm
        return vm
    }

    // MARK: - Model Container

    public let modelContainer: ModelContainer

    // MARK: - Repositories

    public let goalRepository: GoalRepositoryProtocol
    public let badgeRepository: BadgeRepositoryProtocol
    public let taskRepository: TaskRepositoryProtocol

    // MARK: - Caching

    public let dataCache: DataCache

    // MARK: - Networking

    public let httpClient: HTTPClient

    // MARK: - Data Sources

    public let typeQuickerDataSource: CachedTypeQuickerDataSource
    public let atCoderDataSource: CachedAtCoderDataSource
    public let healthKitSleepDataSource: CachedHealthKitSleepDataSource
    public let tasksDataSource: TasksDataSource
    public let ankiDataSource: CachedAnkiDataSource
    public let zoteroDataSource: CachedZoteroDataSource

    // MARK: - Caching Services

    public let taskCachingService: TaskCachingService

    // MARK: - Use Cases

    public let createGoalUseCase: CreateGoalUseCase
    public let syncDataSourcesUseCase: SyncDataSourcesUseCase
    public let badgeEvaluationUseCase: BadgeEvaluationUseCase

    // MARK: - Managers

    public let badgeNotificationManager: BadgeNotificationManager

    // MARK: - Cloud Backup

    /// Sync queue for queueing CloudKit operations (always available)
    public let cloudSyncQueue: CloudSyncQueue

    /// CloudKit backup service (nil until configured)
    public private(set) var cloudBackupService: CloudKitBackupService?

    /// Background sync scheduler (nil until configured)
    public private(set) var cloudSyncScheduler: BackgroundCloudSyncScheduler?

    /// Data recovery service (nil until configured)
    public private(set) var dataRecoveryService: DataRecoveryService?

    // MARK: - Initialization

    public convenience init() throws {
        try self.init(inMemory: false)
    }

    /// Creates an in-memory container for previews and testing
    public static func preview() throws -> AppContainer {
        try AppContainer(inMemory: true)
    }

    private init(inMemory: Bool) throws {
        // Migrate data from old store to shared store (one-time migration)
        if !inMemory {
            DataMigrationService.migrateToSharedStoreIfNeeded()
        }

        // Create LOCAL-ONLY cache container FIRST for fast startup
        // Use shared App Group container so widgets can read the cache
        let cacheSchema = Schema([CachedDataEntry.self])
        let cacheConfiguration: ModelConfiguration

        if inMemory {
            cacheConfiguration = ModelConfiguration(
                "CacheStore",
                schema: cacheSchema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else if let containerURL = SharedStorage.sharedContainerURL {
            // Use shared container for widget access
            let storeURL = containerURL.appendingPathComponent("Library/Application Support/CacheStore.sqlite")
            // Ensure directory exists
            try? FileManager.default.createDirectory(
                at: containerURL.appendingPathComponent("Library/Application Support"),
                withIntermediateDirectories: true
            )
            cacheConfiguration = ModelConfiguration(
                "CacheStore",
                schema: cacheSchema,
                url: storeURL,
                cloudKitDatabase: .none
            )
        } else {
            // Fallback to default location
            cacheConfiguration = ModelConfiguration(
                "CacheStore",
                schema: cacheSchema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        }

        let cacheContainer = try ModelContainer(
            for: cacheSchema,
            configurations: [cacheConfiguration]
        )

        // Initialize caching EARLY so data sources can use it
        self.dataCache = DataCache(modelContainer: cacheContainer)

        // Configure SwiftData for Goals, Badges, and Tasks
        // NOTE: CloudKit temporarily disabled to fix slow startup from migration
        // Re-enable with .automatic once migration completes
        let mainSchema = Schema([
            GoalModel.self,
            EarnedBadgeModel.self,
            TaskDefinitionModel.self,
            TaskSessionModel.self,
        ])

        let mainConfiguration: ModelConfiguration
        if inMemory {
            mainConfiguration = ModelConfiguration(
                schema: mainSchema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else if let storeURL = SharedStorage.sharedMainStoreURL {
            // Use shared container for widget access to tasks
            mainConfiguration = ModelConfiguration(
                schema: mainSchema,
                url: storeURL,
                cloudKitDatabase: .none  // Temporarily disabled - was causing 30+ second startup
            )
        } else {
            mainConfiguration = ModelConfiguration(
                schema: mainSchema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        }

        self.modelContainer = try ModelContainer(
            for: mainSchema,
            configurations: [mainConfiguration]
        )

        // Initialize cloud sync queue BEFORE repositories (so decorators can use it)
        let queueURL: URL
        if let containerURL = SharedStorage.sharedContainerURL {
            queueURL = containerURL.appendingPathComponent("Library/Application Support/CloudSyncQueue.json")
        } else {
            queueURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("CloudSyncQueue.json")
        }
        self.cloudSyncQueue = CloudSyncQueue(storageURL: queueURL)

        // Initialize repositories with cloud backup decorators
        let localGoalRepo = SwiftDataGoalRepository(modelContainer: modelContainer)
        self.goalRepository = CloudBackedGoalRepository(local: localGoalRepo, syncQueue: cloudSyncQueue)

        let localBadgeRepo = SwiftDataBadgeRepository(modelContainer: modelContainer)
        self.badgeRepository = CloudBackedBadgeRepository(local: localBadgeRepo, syncQueue: cloudSyncQueue)

        let localTaskRepo = SwiftDataTaskRepository(modelContainer: modelContainer)
        self.taskRepository = CloudBackedTaskRepository(local: localTaskRepo, syncQueue: cloudSyncQueue)

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
        self.tasksDataSource = TasksDataSource(taskRepository: taskRepository)
        self.ankiDataSource = CachedAnkiDataSource(
            remote: AnkiDataSource(),
            cache: dataCache
        )
        self.zoteroDataSource = CachedZoteroDataSource(
            remote: ZoteroDataSource(),
            cache: dataCache
        )

        // Initialize caching services
        self.taskCachingService = TaskCachingService(
            taskRepository: taskRepository,
            cache: dataCache
        )

        // Initialize use cases
        self.createGoalUseCase = CreateGoalUseCase(goalRepository: goalRepository)
        self.syncDataSourcesUseCase = SyncDataSourcesUseCase(
            goalRepository: goalRepository,
            dataSources: [
                .typeQuicker: typeQuickerDataSource,
                .atCoder: atCoderDataSource,
                .healthKitSleep: healthKitSleepDataSource,
                .tasks: tasksDataSource,
                .anki: ankiDataSource,
                .zotero: zoteroDataSource
            ]
        )
        self.badgeEvaluationUseCase = BadgeEvaluationUseCase(
            goalRepository: goalRepository,
            badgeRepository: badgeRepository
        )

        // Initialize managers
        self.badgeNotificationManager = BadgeNotificationManager()

        // Cloud backup service is configured asynchronously after init
        self.cloudBackupService = nil
        self.cloudSyncScheduler = nil
        self.dataRecoveryService = nil
    }

    /// Configure cloud backup services
    /// Call this after initialization to set up iCloud backup
    public func configureCloudBackup() async {
        guard cloudBackupService == nil else { return } // Already configured

        // Load any persisted queue operations
        try? await cloudSyncQueue.loadFromDisk()

        // Create backup service and setup the CloudKit zone
        let backupService = CloudKitBackupService()
        self.cloudBackupService = backupService

        // Setup CloudKit zone (creates if needed)
        try? await backupService.setupZone()

        // Create sync scheduler
        let scheduler = BackgroundCloudSyncScheduler(
            syncQueue: cloudSyncQueue,
            backupService: backupService
        )
        self.cloudSyncScheduler = scheduler

        // Set shared instance for background task handler
        BackgroundCloudSyncScheduler.shared = scheduler

        // Configure the sync queue handler
        await scheduler.configure()

        // Create recovery service
        let recoveryService = DataRecoveryService(
            backupService: backupService,
            goalRepository: goalRepository,
            taskRepository: taskRepository,
            badgeRepository: badgeRepository
        )
        self.dataRecoveryService = recoveryService
    }
}
