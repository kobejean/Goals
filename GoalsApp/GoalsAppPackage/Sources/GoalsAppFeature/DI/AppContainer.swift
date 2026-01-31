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

    // MARK: - Data Source Registry

    /// Registry mapping data source types to their implementations.
    /// Used for dynamic lookup of data sources by type.
    private var dataSourceRegistry: [DataSourceType: any DataSourceRepositoryProtocol] {
        [
            .typeQuicker: typeQuickerDataSource,
            .atCoder: atCoderDataSource,
            .healthKitSleep: healthKitSleepDataSource,
            .tasks: tasksDataSource,
            .anki: ankiDataSource,
            .zotero: zoteroDataSource,
            .wiiFit: wiiFitDataSource,
            .tensorTonic: tensorTonicDataSource
            // Note: nutrition is excluded - it doesn't expose metrics for goals
        ]
    }

    /// Get available metrics for a data source type
    public func availableMetrics(for dataSource: DataSourceType) -> [MetricInfo] {
        dataSourceRegistry[dataSource]?.availableMetrics ?? []
    }

    /// Configure all data sources from stored settings
    /// Call this before syncing to ensure data sources are ready
    public func configureDataSources() async {
        // Configure data sources using DataSourceConfigurable protocol
        if let settings = TypeQuickerDataSource.loadSettingsFromUserDefaults() {
            try? await typeQuickerDataSource.configure(settings: settings)
        }

        if let settings = AtCoderDataSource.loadSettingsFromUserDefaults() {
            try? await atCoderDataSource.configure(settings: settings)
        }

        if let settings = AnkiDataSource.loadSettingsFromUserDefaults() {
            try? await ankiDataSource.configure(settings: settings)
        }

        if let settings = ZoteroDataSource.loadSettingsFromUserDefaults() {
            try? await zoteroDataSource.configure(settings: settings)
        }

        if let settings = WiiFitDataSource.loadSettingsFromUserDefaults() {
            try? await wiiFitDataSource.configure(settings: settings)
        }

        if let settings = TensorTonicDataSource.loadSettingsFromUserDefaults() {
            try? await tensorTonicDataSource.configure(settings: settings)
        }

        // HealthKit doesn't need configuration - it uses system authorization

        // Configure Gemini (not using DataSourceConfigurable - different pattern)
        if let apiKey = UserDefaults.standard.geminiAPIKey, !apiKey.isEmpty {
            await geminiDataSource.configure(apiKey: apiKey)
        }
    }

    // MARK: - ViewModels (lazily created, persist for app lifetime)

    private var _insightsViewModel: InsightsViewModel?
    private var _tasksViewModel: TasksViewModel?
    private var _locationsViewModel: LocationsViewModel?

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
            locationRepository: locationRepository,
            goalRepository: goalRepository,
            ankiDataSource: ankiDataSource,
            zoteroDataSource: zoteroDataSource,
            nutritionRepository: nutritionRepository,
            wiiFitDataSource: wiiFitDataSource,
            tensorTonicDataSource: tensorTonicDataSource,
            taskCachingService: taskCachingService,
            locationCachingService: locationCachingService
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

    /// Shared LocationsViewModel - persists across navigation
    public var locationsViewModel: LocationsViewModel {
        if let existing = _locationsViewModel {
            return existing
        }
        let vm = LocationsViewModel(
            locationRepository: locationRepository,
            locationTrackingService: locationTrackingService
        )
        _locationsViewModel = vm
        return vm
    }

    // MARK: - Model Container

    public let modelContainer: ModelContainer

    // MARK: - Repositories

    public let goalRepository: GoalRepositoryProtocol
    public let badgeRepository: BadgeRepositoryProtocol
    public let taskRepository: TaskRepositoryProtocol
    public let nutritionRepository: NutritionRepositoryProtocol
    public let locationRepository: LocationRepositoryProtocol

    // MARK: - Networking

    public let httpClient: HTTPClient

    // MARK: - Data Sources

    public let typeQuickerDataSource: TypeQuickerDataSource
    public let atCoderDataSource: AtCoderDataSource
    public let healthKitSleepDataSource: HealthKitSleepDataSource
    public let tasksDataSource: TasksDataSource
    public let ankiDataSource: AnkiDataSource
    public let zoteroDataSource: ZoteroDataSource
    public let wiiFitDataSource: WiiFitDataSource
    public let tensorTonicDataSource: TensorTonicDataSource
    public let geminiDataSource: GeminiDataSource

    // MARK: - Caching Services

    public let taskCachingService: TaskCachingService

    // MARK: - Location Services

    public let locationManager: LocationManager
    public let locationTrackingService: LocationTrackingService
    public let locationCachingService: LocationCachingService

    // MARK: - Use Cases

    public let createGoalUseCase: CreateGoalUseCase
    public let syncDataSourcesUseCase: SyncDataSourcesUseCase
    public let badgeEvaluationUseCase: BadgeEvaluationUseCase

    // MARK: - Managers

    public let badgeNotificationManager: BadgeNotificationManager

    // MARK: - Audio

    public let bgmPlayer: BGMPlayer

    // MARK: - Cloud Backup

    /// Sync queue for queueing CloudKit operations (always available)
    public let cloudSyncQueue: CloudSyncQueue

    /// CloudKit backup service (nil until configured)
    public private(set) var cloudBackupService: CloudKitBackupService?

    /// Background sync scheduler (nil until configured)
    public private(set) var cloudSyncScheduler: BackgroundCloudSyncScheduler?

    // MARK: - Initialization

    public convenience init() throws {
        try self.init(inMemory: false)
    }

    /// Creates an in-memory container for previews and testing
    public static func preview() throws -> AppContainer {
        try AppContainer(inMemory: true)
    }

    private init(inMemory: Bool) throws {
        // Create SINGLE unified ModelContainer with all models
        // NOTE: CloudKit temporarily disabled to fix slow startup
        let unifiedSchema = UnifiedSchema.createSchema()

        let mainConfiguration: ModelConfiguration
        if inMemory {
            mainConfiguration = ModelConfiguration(
                schema: unifiedSchema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else if let storeURL = SharedStorage.sharedMainStoreURL {
            // Use shared container for widget access
            mainConfiguration = ModelConfiguration(
                schema: unifiedSchema,
                url: storeURL,
                cloudKitDatabase: .none  // Temporarily disabled - was causing 30+ second startup
            )
        } else {
            mainConfiguration = ModelConfiguration(
                schema: unifiedSchema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        }

        self.modelContainer = try ModelContainer(
            for: unifiedSchema,
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

        self.nutritionRepository = SwiftDataNutritionRepository(modelContainer: modelContainer)

        let localLocationRepo = SwiftDataLocationRepository(modelContainer: modelContainer)
        self.locationRepository = CloudBackedLocationRepository(local: localLocationRepo, syncQueue: cloudSyncQueue)

        // Initialize networking
        self.httpClient = HTTPClient()

        // Initialize data sources with caching enabled
        self.typeQuickerDataSource = TypeQuickerDataSource(modelContainer: modelContainer, httpClient: httpClient)
        self.atCoderDataSource = AtCoderDataSource(modelContainer: modelContainer, httpClient: httpClient)
        self.healthKitSleepDataSource = HealthKitSleepDataSource(modelContainer: modelContainer)
        self.tasksDataSource = TasksDataSource(taskRepository: taskRepository)
        self.ankiDataSource = AnkiDataSource(modelContainer: modelContainer)
        self.zoteroDataSource = ZoteroDataSource(modelContainer: modelContainer)
        self.wiiFitDataSource = WiiFitDataSource(modelContainer: modelContainer)
        self.tensorTonicDataSource = TensorTonicDataSource(modelContainer: modelContainer)
        self.geminiDataSource = GeminiDataSource()

        // Initialize caching services
        self.taskCachingService = TaskCachingService(
            taskRepository: taskRepository,
            modelContainer: modelContainer
        )

        // Initialize location services
        self.locationManager = LocationManager()
        self.locationTrackingService = LocationTrackingService(
            locationManager: locationManager,
            locationRepository: locationRepository
        )
        self.locationCachingService = LocationCachingService(
            locationRepository: locationRepository,
            modelContainer: modelContainer
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
                .zotero: zoteroDataSource,
                .wiiFit: wiiFitDataSource,
                .tensorTonic: tensorTonicDataSource
            ]
        )
        self.badgeEvaluationUseCase = BadgeEvaluationUseCase(
            goalRepository: goalRepository,
            badgeRepository: badgeRepository
        )

        // Initialize managers
        self.badgeNotificationManager = BadgeNotificationManager()

        // Initialize audio
        self.bgmPlayer = BGMPlayer()

        // Cloud backup service is configured asynchronously after init
        self.cloudBackupService = nil
        self.cloudSyncScheduler = nil
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
    }
}
