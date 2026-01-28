# Data Architecture

This document describes how data is managed, updated, and stored in the Goals app.

## Architecture Overview

The Goals app uses a layered architecture with clean separation of concerns:

```
┌─────────────────────────────────────────────────────────────────┐
│                           UI Layer                              │
│                    (SwiftUI Views, ViewModels)                  │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Dependency Injection                        │
│                        (AppContainer)                           │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                           Use Cases                             │
│       (SyncDataSourcesUseCase, CreateGoalUseCase, etc.)         │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Repositories                            │
│       (GoalRepository, TaskRepository, BadgeRepository)         │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                          Data Sources                           │
│          (Cached wrappers around remote data sources)           │
└─────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
┌───────────────────────────┐   ┌───────────────────────────────┐
│      Cache Layer          │   │       Network/Local           │
│    (DataCache actor)      │   │   (HTTP APIs, HealthKit,      │
│                           │   │    AnkiConnect, SwiftData)    │
└───────────────────────────┘   └───────────────────────────────┘
```

### Key Design Principles

1. **Single Source of Truth**: Cached wrappers always return data from cache after fetching
2. **Unified Schema**: All data (user data + cached external data) stored in a single SwiftData store
3. **Native Cache Models**: Cached data uses typed SwiftData models, eliminating JSON encoding overhead
4. **Actor-Based Concurrency**: Thread-safe operations via Swift actors
5. **Repository Pattern**: Protocol-based abstraction for data persistence
6. **Decorator Pattern**: Cached data sources wrap remote sources transparently
7. **Smart Fetching**: Only fetch missing date ranges to minimize API calls

---

## Data Sources

The app integrates with 7 data sources:

| Source | Type | Protocol/API | Description |
|--------|------|--------------|-------------|
| **TypeQuicker** | HTTP REST | `api.typequicker.com` | Typing practice metrics (WPM, accuracy, practice time) |
| **AtCoder** | HTTP REST | `atcoder.jp` + `kenkoooo.com` | Competitive programming stats (rating, problems solved, streak) |
| **Anki** | Local JSON-RPC | AnkiConnect (localhost) | Spaced repetition metrics (reviews, study time, retention) |
| **Zotero** | HTTP REST | `api.zotero.org` | Research reading stats (annotations, notes, reading progress) |
| **Tasks** | Local SwiftData | On-device | Time tracking (daily duration, session count) |
| **HealthKit Sleep** | iOS Framework | HealthKit | Sleep data (duration, stages, efficiency) |
| **Nutrition** | Local SwiftData | On-device | Meal tracking (calories, macros, photos via Gemini AI) |

### Data Source Protocols

Each data source implements `DataSourceRepositoryProtocol`:

```swift
public protocol DataSourceRepositoryProtocol: Sendable {
    var dataSourceType: DataSourceType { get }
    var availableMetrics: [MetricInfo] { get }

    func isConfigured() async -> Bool
    func configure(settings: DataSourceSettings) async throws
    func clearConfiguration() async throws
    func fetchLatestMetricValue(for metricKey: String, taskId: UUID?) async throws -> Double?
    func metricValue(for key: String, from stats: Any) -> Double?
}
```

### Source-Specific Details

#### TypeQuicker
- **Location**: `GoalsKit/Sources/GoalsData/DataSources/TypeQuickerDataSource.swift`
- **API**: REST API at `https://api.typequicker.com/stats/{username}`
- **Metrics**: WPM, accuracy, practice time, session count
- **Auth**: Username-based (no API key required)

#### AtCoder
- **Location**: `GoalsKit/Sources/GoalsData/DataSources/AtCoderDataSource.swift`
- **APIs**:
  - Official: `https://atcoder.jp/users/{user}/history/json`
  - Kenkoooo: `https://kenkoooo.com/atcoder/atcoder-api/v3/`
- **Metrics**: Rating, highest rating, contests participated, problems solved, longest streak
- **Auth**: Username-based (public data)

#### Anki
- **Location**: `GoalsKit/Sources/GoalsData/DataSources/AnkiDataSource.swift`
- **API**: JSON-RPC via AnkiConnect plugin (localhost)
- **Metrics**: Daily reviews, study time, retention rate, new cards
- **Auth**: Host/port configuration (default: `localhost:8765`)

#### Zotero
- **Location**: `GoalsKit/Sources/GoalsData/DataSources/ZoteroDataSource.swift`
- **API**: REST API at `https://api.zotero.org`
- **Metrics**: Daily annotations, daily notes, reading status (to-read/in-progress/read counts)
- **Auth**: API key + User ID + optional collection keys

#### Tasks
- **Location**: `GoalsKit/Sources/GoalsData/DataSources/TasksDataSource.swift`
- **Storage**: Local SwiftData
- **Metrics**: Daily duration, session count, total duration
- **Auth**: None (local data)

#### HealthKit Sleep
- **Location**: `GoalsKit/Sources/GoalsData/DataSources/HealthKitSleepDataSource.swift`
- **API**: iOS HealthKit framework
- **Metrics**: Sleep duration, efficiency, REM/deep/core sleep, bedtime, wake time
- **Auth**: HealthKit authorization request

#### Nutrition
- **Location**: `GoalsKit/Sources/GoalsData/Persistence/Repositories/SwiftDataNutritionRepository.swift`
- **Storage**: Local SwiftData (`NutritionEntryModel`)
- **Metrics**: Calories, protein, carbohydrates, fat, daily totals
- **Features**: Photo-based entry via Gemini AI analysis, thumbnail storage
- **Auth**: None (local data), Gemini API key for photo analysis

---

## Caching Layer

### DataCache Actor

The `DataCache` actor provides thread-safe cache operations backed by SwiftData with native cache models.

**Location**: `GoalsKit/Sources/GoalsData/Caching/DataCache.swift`

```swift
public actor DataCache {
    private let modelContainer: ModelContainer

    // Store Operations (type-routed to native SwiftData models)
    public func store<T: CacheableRecord>(_ records: [T]) async throws
    public func store<T: CacheableRecord>(_ record: T) async throws

    // Fetch Operations (type-routed to native SwiftData models)
    public func fetch<T: CacheableRecord>(_ type: T.Type, from: Date?, to: Date?) async throws -> [T]
    public func fetch<T: CacheableRecord>(_ type: T.Type, cacheKey: String) async throws -> T?

    // Query Operations
    public func latestRecordDate<T: CacheableRecord>(for type: T.Type) async throws -> Date?
    public func earliestRecordDate<T: CacheableRecord>(for type: T.Type) async throws -> Date?
    public func hasCachedData<T: CacheableRecord>(for type: T.Type) async throws -> Bool
    public func count<T: CacheableRecord>(for type: T.Type) async throws -> Int

    // Delete Operations
    public func deleteAll<T: CacheableRecord>(for type: T.Type) async throws
    public func deleteOlderThan<T: CacheableRecord>(_ date: Date, for type: T.Type) async throws

    // Strategy Metadata (stored in UserDefaults)
    public func storeStrategyMetadata<S: IncrementalFetchStrategy>(_ metadata: S.Metadata, for strategy: S) throws
    public func fetchStrategyMetadata<S: IncrementalFetchStrategy>(for strategy: S) throws -> S.Metadata?
    public func clearStrategyMetadata<S: IncrementalFetchStrategy>(for strategy: S)
}
```

**Key Features**:
- Type-specific routing to native SwiftData models (no JSON encoding overhead)
- Conflict resolution based on `fetchedAt` timestamp (newer wins)
- Date range queries via predicates
- Type-safe operations via generics with runtime type dispatch

### CacheableRecord Protocol

Domain objects implement `CacheableRecord` to be cacheable:

**Location**: `GoalsKit/Sources/GoalsDomain/Caching/CacheableRecord.swift`

```swift
public protocol CacheableRecord: Codable, Sendable {
    static var dataSource: DataSourceType { get }
    static var recordType: String { get }
    var cacheKey: String { get }
    var recordDate: Date { get }
}
```

**Example**: `TypeQuickerStats`
```swift
extension TypeQuickerStats: CacheableRecord {
    public static var dataSource: DataSourceType { .typeQuicker }
    public static var recordType: String { "stats" }

    public var cacheKey: String {
        "tq:stats:\(dateFormatter.string(from: date))"  // e.g., "tq:stats:2025-01-15"
    }

    public var recordDate: Date { date }
}
```

### Native Cache Models

Instead of generic JSON-encoded storage, each cached data type has a dedicated SwiftData model:

| Domain Type | SwiftData Cache Model |
|-------------|----------------------|
| `TypeQuickerStats` | `TypeQuickerStatsModel` |
| `AtCoderContestResult` | `AtCoderContestResultModel` |
| `AtCoderSubmission` | `AtCoderSubmissionModel` |
| `AtCoderDailyEffort` | `AtCoderDailyEffortModel` |
| `AnkiDailyStats` | `AnkiDailyStatsModel` |
| `ZoteroDailyStats` | `ZoteroDailyStatsModel` |
| `ZoteroReadingStatus` | `ZoteroReadingStatusModel` |
| `SleepDailySummary` | `SleepDailySummaryModel` |
| `TaskDailySummary` | `TaskDailySummaryModel` |
| `NutritionDailySummary` | `NutritionDailySummaryModel` |

**Example**: `TypeQuickerStatsModel`
```swift
@Model
public final class TypeQuickerStatsModel {
    @Attribute(.unique)
    public var cacheKey: String = ""
    public var recordDate: Date = Date()
    public var fetchedAt: Date = Date()

    // Typed fields (no JSON encoding)
    public var wordsPerMinute: Double = 0
    public var accuracy: Double = 0
    public var practiceTimeMinutes: Int = 0
    public var sessionsCount: Int = 0

    // Complex nested data uses external storage
    @Attribute(.externalStorage)
    public var byModeData: Data?

    // Domain conversion
    func toDomain() -> TypeQuickerStats { ... }
    static func from(_ record: TypeQuickerStats, fetchedAt: Date) -> TypeQuickerStatsModel { ... }
    func update(from record: TypeQuickerStats, fetchedAt: Date) { ... }
}
```

### Cached Data Source Wrappers (Decorator Pattern)

Cached wrappers implement `CachingDataSourceWrapper`:

**Location**: `GoalsKit/Sources/GoalsData/Caching/CachingDataSourceWrapper.swift`

```swift
public protocol CachingDataSourceWrapper: DataSourceRepositoryProtocol {
    associatedtype RemoteSource: DataSourceRepositoryProtocol
    var remote: RemoteSource { get }
    var cache: DataCache { get }
}
```

**Pattern**: Each remote data source has a cached wrapper:

| Remote Source | Cached Wrapper |
|---------------|----------------|
| `TypeQuickerDataSource` | `CachedTypeQuickerDataSource` |
| `AtCoderDataSource` | `CachedAtCoderDataSource` |
| `AnkiDataSource` | `CachedAnkiDataSource` |
| `ZoteroDataSource` | `CachedZoteroDataSource` |
| `HealthKitSleepDataSource` | `CachedHealthKitSleepDataSource` |

### Smart Fetching Algorithm

Cached wrappers use smart fetching to minimize API calls:

```swift
func fetchStats(from startDate: Date, to endDate: Date) async throws -> [Stats] {
    // 1. Get cached data to determine what's missing
    let cachedStats = try await fetchCached(Stats.self, from: startDate, to: endDate)
    let cachedDates = Set(cachedStats.map { Calendar.current.startOfDay(for: $0.date) })

    // 2. Calculate missing date ranges
    let missingRanges = calculateMissingDateRanges(from: startDate, to: endDate, cachedDates: cachedDates)

    // 3. Fetch only missing ranges from remote
    for range in missingRanges {
        let remoteStats = try await remote.fetchStats(from: range.start, to: range.end)
        try await cache.store(remoteStats)
    }

    // 4. Single source of truth: always return from cache
    return try await fetchCached(Stats.self, from: startDate, to: endDate)
}
```

---

## Persistence Layer (SwiftData)

### Unified Schema Architecture

The app uses a **single ModelContainer** with a unified schema containing all models. This approach:
- Simplifies container management (one store instead of two)
- Enables widget access to all data via App Group
- Allows native SwiftData models for cached data (better performance than JSON encoding)

**Location**: `GoalsKit/Sources/GoalsData/Persistence/UnifiedSchema.swift`

```swift
public enum UnifiedSchema {
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

    public static func createSchema() -> Schema { Schema(allModels) }
    public static func createContainer(url: URL?, inMemory: Bool, cloudKit: ...) throws -> ModelContainer
}
```

### Shared Storage (App Group)

The store uses a shared App Group container for widget access:

```swift
if let storeURL = SharedStorage.sharedMainStoreURL {
    // Use shared container: "Library/Application Support/default.store"
    let configuration = ModelConfiguration(schema: unifiedSchema, url: storeURL, ...)
}
```

**Location**: `GoalsApp/GoalsAppPackage/Sources/GoalsWidgetShared/Data/SharedStorage.swift`

```swift
public enum SharedStorage {
    public static let appGroupIdentifier = "group.com.kobejean.goals"
    public static var sharedMainStoreURL: URL? {
        sharedContainerURL?.appendingPathComponent("Library/Application Support/default.store")
    }
}
```

### SwiftData Models

**Location**: `GoalsKit/Sources/GoalsData/Persistence/Models/`

| Model | Purpose | Category |
|-------|---------|----------|
| `GoalModel` | User goals with progress tracking | User Data |
| `TaskDefinitionModel` | Task definitions for time tracking | User Data |
| `TaskSessionModel` | Individual task sessions | User Data |
| `EarnedBadgeModel` | Badges earned by users | User Data |
| `NutritionEntryModel` | Nutrition entries with nutrients and photo data | User Data |
| `TypeQuickerStatsModel` | Cached TypeQuicker daily stats | Cached Data |
| `AtCoderContestResultModel` | Cached AtCoder contest results | Cached Data |
| `AtCoderSubmissionModel` | Cached AtCoder submissions | Cached Data |
| `AtCoderDailyEffortModel` | Cached AtCoder daily effort summaries | Cached Data |
| `AnkiDailyStatsModel` | Cached Anki daily statistics | Cached Data |
| `ZoteroDailyStatsModel` | Cached Zotero daily stats | Cached Data |
| `ZoteroReadingStatusModel` | Cached Zotero reading status | Cached Data |
| `SleepDailySummaryModel` | Cached sleep daily summaries | Cached Data |
| `TaskDailySummaryModel` | Cached task daily summaries | Cached Data |
| `NutritionDailySummaryModel` | Cached nutrition daily summaries | Cached Data |

---

## Repository Pattern

### Protocol Definitions (GoalsDomain)

**Location**: `GoalsKit/Sources/GoalsDomain/Repositories/`

```swift
// GoalRepositoryProtocol
public protocol GoalRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Goal]
    func fetchActive() async throws -> [Goal]
    func fetchArchived() async throws -> [Goal]
    func fetch(id: UUID) async throws -> Goal?
    func fetch(dataSource: DataSourceType) async throws -> [Goal]
    func create(_ goal: Goal) async throws -> Goal
    func update(_ goal: Goal) async throws -> Goal
    func delete(id: UUID) async throws
    func archive(id: UUID) async throws
    func unarchive(id: UUID) async throws
    func updateProgress(goalId: UUID, currentValue: Double) async throws
}

// TaskRepositoryProtocol
public protocol TaskRepositoryProtocol: Sendable {
    func fetchAllTasks() async throws -> [TaskDefinition]
    func fetchTask(id: UUID) async throws -> TaskDefinition?
    func createTask(_ task: TaskDefinition) async throws -> TaskDefinition
    func updateTask(_ task: TaskDefinition) async throws
    func deleteTask(id: UUID) async throws
    func fetchSessions(taskId: UUID) async throws -> [TaskSession]
    func fetchSessions(from: Date, to: Date) async throws -> [TaskSession]
    func createSession(_ session: TaskSession) async throws -> TaskSession
    func updateSession(_ session: TaskSession) async throws
    func deleteSession(id: UUID) async throws
}

// BadgeRepositoryProtocol
public protocol BadgeRepositoryProtocol: Sendable {
    func fetchEarnedBadges() async throws -> [EarnedBadge]
    func fetchEarnedBadge(badgeId: String, goalId: UUID) async throws -> EarnedBadge?
    func earnBadge(_ badge: EarnedBadge) async throws
    func hasEarnedBadge(badgeId: String, goalId: UUID) async throws -> Bool
}

// NutritionRepositoryProtocol
public protocol NutritionRepositoryProtocol: Sendable {
    func fetchEntries(from startDate: Date, to endDate: Date) async throws -> [NutritionEntry]
    func fetchEntry(id: UUID) async throws -> NutritionEntry?
    func createEntry(_ entry: NutritionEntry) async throws -> NutritionEntry
    func updateEntry(_ entry: NutritionEntry) async throws
    func deleteEntry(id: UUID) async throws
}
```

### Repository Implementations (GoalsData)

**Location**: `GoalsKit/Sources/GoalsData/Persistence/Repositories/`

| Protocol | Implementation | Cloud-Backed Decorator |
|----------|----------------|------------------------|
| `GoalRepositoryProtocol` | `SwiftDataGoalRepository` | `CloudBackedGoalRepository` |
| `TaskRepositoryProtocol` | `SwiftDataTaskRepository` | `CloudBackedTaskRepository` |
| `BadgeRepositoryProtocol` | `SwiftDataBadgeRepository` | `CloudBackedBadgeRepository` |
| `NutritionRepositoryProtocol` | `SwiftDataNutritionRepository` | — |

All SwiftData repositories are `@MainActor` isolated and use `ModelContainer.mainContext`.

Cloud-backed decorators queue operations for CloudKit sync via `CloudSyncQueue`.

---

## Data Flow Diagrams

### Sync Flow (External API → Cache → Goal Update → UI)

```
User triggers sync
       │
       ▼
┌──────────────────────┐
│ SyncDataSourcesUseCase │
└──────────────────────┘
       │
       ▼
┌──────────────────────┐
│ CachedDataSource     │
│  (e.g., TypeQuicker) │
└──────────────────────┘
       │
       ├──────────────────────────────┐
       ▼                              ▼
┌──────────────────┐         ┌──────────────────┐
│   DataCache      │◄────────│  Remote API      │
│ (check cached)   │         │  (fetch missing) │
└──────────────────┘         └──────────────────┘
       │
       ▼
┌──────────────────────┐
│ Return from cache    │
│ (single source of    │
│  truth)              │
└──────────────────────┘
       │
       ▼
┌──────────────────────┐
│ GoalRepository       │
│ .updateProgress()    │
└──────────────────────┘
       │
       ▼
┌──────────────────────┐
│ UI Updates           │
│ (via @Observable)    │
└──────────────────────┘
```

### Task Session Flow (UI → Repository → SwiftData)

```
User starts task timer
       │
       ▼
┌──────────────────────┐
│ TasksViewModel       │
└──────────────────────┘
       │
       ▼
┌──────────────────────┐
│ TaskRepository       │
│ .createSession()     │
└──────────────────────┘
       │
       ▼
┌──────────────────────┐
│ SwiftData            │
│ (TaskSessionModel)   │
└──────────────────────┘
       │
       ▼
┌──────────────────────┐
│ TaskCachingService   │
│ (cache for widgets)  │
└──────────────────────┘
```

### Badge Evaluation Flow

```
Goal progress updated
       │
       ▼
┌──────────────────────┐
│ BadgeEvaluationUseCase │
└──────────────────────┘
       │
       ▼
┌──────────────────────┐
│ Check badge criteria │
│ against goal progress│
└──────────────────────┘
       │
       ▼ (if criteria met)
┌──────────────────────┐
│ BadgeRepository      │
│ .earnBadge()         │
└──────────────────────┘
       │
       ▼
┌──────────────────────┐
│ BadgeNotificationMgr │
│ (show notification)  │
└──────────────────────┘
```

---

## Dependency Injection

### AppContainer

**Location**: `GoalsApp/GoalsAppPackage/Sources/GoalsAppFeature/DI/AppContainer.swift`

The `AppContainer` is the central DI container that:
1. Creates and owns the unified ModelContainer (single store for all data)
2. Instantiates all repositories with cloud-backed decorators
3. Creates cached data source wrappers
4. Provides use case instances
5. Manages cloud backup services
6. Offers lazy ViewModel properties

```swift
@MainActor
@Observable
public final class AppContainer {
    // Model Container (unified schema with all models)
    public let modelContainer: ModelContainer

    // Repositories (with cloud-backed decorators)
    public let goalRepository: GoalRepositoryProtocol
    public let badgeRepository: BadgeRepositoryProtocol
    public let taskRepository: TaskRepositoryProtocol
    public let nutritionRepository: NutritionRepositoryProtocol

    // Caching
    public let dataCache: DataCache

    // Data Sources (cached wrappers)
    public let typeQuickerDataSource: CachedTypeQuickerDataSource
    public let atCoderDataSource: CachedAtCoderDataSource
    public let healthKitSleepDataSource: CachedHealthKitSleepDataSource
    public let tasksDataSource: TasksDataSource
    public let ankiDataSource: CachedAnkiDataSource
    public let zoteroDataSource: CachedZoteroDataSource
    public let geminiDataSource: GeminiDataSource  // For nutrition photo analysis

    // Caching Services
    public let taskCachingService: TaskCachingService

    // Use Cases
    public let createGoalUseCase: CreateGoalUseCase
    public let syncDataSourcesUseCase: SyncDataSourcesUseCase
    public let badgeEvaluationUseCase: BadgeEvaluationUseCase

    // Cloud Backup
    public let cloudSyncQueue: CloudSyncQueue
    public private(set) var cloudBackupService: CloudKitBackupService?
    public private(set) var cloudSyncScheduler: BackgroundCloudSyncScheduler?

    // ViewModels (lazily created, persist for app lifetime)
    public var insightsViewModel: InsightsViewModel { ... }
    public var tasksViewModel: TasksViewModel { ... }
}
```

### Wiring Example

```swift
// In AppContainer.init()

// 1. Create unified ModelContainer with all models
let unifiedSchema = UnifiedSchema.createSchema()
self.modelContainer = try ModelContainer(for: unifiedSchema, configurations: [mainConfiguration])

// 2. Create cache using the unified container
self.dataCache = DataCache(modelContainer: modelContainer)

// 3. Create repositories
let localGoalRepo = SwiftDataGoalRepository(modelContainer: modelContainer)
self.goalRepository = CloudBackedGoalRepository(local: localGoalRepo, syncQueue: cloudSyncQueue)

// 4. Create cached data sources
self.typeQuickerDataSource = CachedTypeQuickerDataSource(
    remote: TypeQuickerDataSource(httpClient: httpClient),
    cache: dataCache
)

// 5. Create use cases with dependencies
self.syncDataSourcesUseCase = SyncDataSourcesUseCase(
    goalRepository: goalRepo,
    dataSources: [
        .typeQuicker: typeQuickerDataSource,
        .atCoder: atCoderDataSource,
        // ...
    ]
)
```

---

## Cloud Backup & Sync

### CloudKit Integration

The app uses CloudKit for backup and cross-device sync (currently disabled for faster startup):

**Location**: `GoalsKit/Sources/GoalsData/CloudSync/`

| Component | Purpose |
|-----------|---------|
| `CloudKitBackupService` | Direct CloudKit operations (zone setup, record CRUD) |
| `CloudSyncQueue` | Queues operations for reliable sync (persisted to disk) |
| `SyncOperation` | Represents a queued sync operation (create/update/delete) |
| `BackgroundCloudSyncScheduler` | Schedules background sync tasks |
| `CloudBackupable` | Protocol for types that can be backed up |

### Cloud-Backed Repository Pattern

Repositories are wrapped with cloud-backed decorators that:
1. Perform local SwiftData operation first (fast, reliable)
2. Queue CloudKit operation for background sync
3. Handle conflicts and retries automatically

```swift
// Example: CloudBackedGoalRepository
public final class CloudBackedGoalRepository: GoalRepositoryProtocol {
    private let local: GoalRepositoryProtocol
    private let syncQueue: CloudSyncQueue

    public func create(_ goal: Goal) async throws -> Goal {
        let created = try await local.create(goal)  // Local first
        await syncQueue.enqueue(.create(goal))       // Queue for sync
        return created
    }
}
```

---

## Concurrency Model

### Actor Isolation

| Component | Isolation | Reason |
|-----------|-----------|--------|
| `DataCache` | Actor | Thread-safe cache operations |
| `TypeQuickerDataSource` | Actor | Thread-safe HTTP operations |
| `AtCoderDataSource` | Actor | Thread-safe HTTP operations |
| `AnkiDataSource` | Actor | Thread-safe JSON-RPC operations |
| `ZoteroDataSource` | Actor | Thread-safe HTTP operations |
| `HealthKitSleepDataSource` | Actor | Thread-safe HealthKit operations |
| `GeminiDataSource` | Actor | Thread-safe AI API operations |
| Cached wrappers | Actor | Inherits from wrapped source |
| `CloudSyncQueue` | Actor | Thread-safe queue operations |

### @MainActor Isolation

| Component | Reason |
|-----------|--------|
| `SwiftDataGoalRepository` | SwiftData mainContext access |
| `SwiftDataTaskRepository` | SwiftData mainContext access |
| `SwiftDataBadgeRepository` | SwiftData mainContext access |
| `SwiftDataNutritionRepository` | SwiftData mainContext access |
| `TasksDataSource` | Uses TaskRepository |
| `AppContainer` | UI state coordination |
| ViewModels | UI state management |

### Swift 6 Strict Concurrency

The codebase uses Swift 6 strict concurrency mode:
- All types crossing actor boundaries are `Sendable`
- Use cases are `Sendable` structs
- Domain entities are `Sendable` structs
- Repository protocols require `Sendable` conformance

```swift
// Example: SyncDataSourcesUseCase is Sendable
public struct SyncDataSourcesUseCase: Sendable {
    private let goalRepository: GoalRepositoryProtocol  // Sendable
    private let dataSources: [DataSourceType: any DataSourceRepositoryProtocol]  // Sendable
}
```

---

## File Reference

| Category | Location |
|----------|----------|
| Data Sources | `GoalsKit/Sources/GoalsData/DataSources/` |
| Cached Wrappers | `GoalsKit/Sources/GoalsData/DataSources/Cached/` |
| DataCache | `GoalsKit/Sources/GoalsData/Caching/DataCache.swift` |
| CacheableRecord | `GoalsKit/Sources/GoalsDomain/Caching/CacheableRecord.swift` |
| Caching Strategies | `GoalsKit/Sources/GoalsData/Caching/Strategies/` |
| Unified Schema | `GoalsKit/Sources/GoalsData/Persistence/UnifiedSchema.swift` |
| SwiftData Models | `GoalsKit/Sources/GoalsData/Persistence/Models/` |
| Repository Implementations | `GoalsKit/Sources/GoalsData/Persistence/Repositories/` |
| Repository Protocols | `GoalsKit/Sources/GoalsDomain/Repositories/` |
| Use Cases | `GoalsKit/Sources/GoalsDomain/UseCases/` |
| Cloud Sync | `GoalsKit/Sources/GoalsData/CloudSync/` |
| AppContainer | `GoalsApp/GoalsAppPackage/Sources/GoalsAppFeature/DI/AppContainer.swift` |
| Domain Entities | `GoalsKit/Sources/GoalsDomain/Entities/` |
| ViewModels | `GoalsApp/GoalsAppPackage/Sources/GoalsAppFeature/ViewModels/` |
| Insight Builders | `GoalsApp/GoalsAppPackage/Sources/GoalsWidgetShared/Data/InsightBuilders.swift` |
| Shared Storage | `GoalsApp/GoalsAppPackage/Sources/GoalsWidgetShared/Data/SharedStorage.swift` |
| Shared Charts | `GoalsApp/GoalsAppPackage/Sources/GoalsWidgetShared/Charts/` |
