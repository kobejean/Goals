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
2. **Actor-Based Concurrency**: Thread-safe operations via Swift actors
3. **Repository Pattern**: Protocol-based abstraction for data persistence
4. **Decorator Pattern**: Cached data sources wrap remote sources transparently
5. **Smart Fetching**: Only fetch missing date ranges to minimize API calls

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

The `DataCache` actor provides thread-safe cache operations backed by SwiftData.

**Location**: `GoalsKit/Sources/GoalsData/Caching/DataCache.swift`

```swift
public actor DataCache {
    private let modelContainer: ModelContainer

    // Store Operations
    public func store<T: CacheableRecord>(_ records: [T]) async throws
    public func store<T: CacheableRecord>(_ record: T) async throws

    // Fetch Operations
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
}
```

**Key Features**:
- Conflict resolution based on `fetchedAt` timestamp (newer wins)
- Date range queries via predicates
- Type-safe operations via generics

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

### CachedDataEntry Model

**Location**: `GoalsKit/Sources/GoalsData/Persistence/Models/CachedDataEntry.swift`

```swift
@Model
public final class CachedDataEntry {
    public var cacheKey: String       // "{dataSource}:{recordType}:{uniqueKey}"
    public var dataSourceRaw: String  // DataSourceType raw value
    public var recordType: String     // e.g., "stats", "submission"
    public var recordDate: Date       // For date range queries
    public var payload: Data          // JSON-encoded domain object
    public var fetchedAt: Date        // When fetched from API
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

### Two ModelContainers

The app uses separate ModelContainers for different purposes:

#### 1. Main Store
**Models**: `GoalModel`, `TaskDefinitionModel`, `TaskSessionModel`, `EarnedBadgeModel`, `NutritionEntryModel`

```swift
let mainSchema = Schema([
    GoalModel.self,
    EarnedBadgeModel.self,
    TaskDefinitionModel.self,
    TaskSessionModel.self,
    NutritionEntryModel.self,
])
```

#### 2. Cache Store
**Models**: `CachedDataEntry`

```swift
let cacheSchema = Schema([CachedDataEntry.self])
```

### Shared Storage (App Group)

Both stores use a shared App Group container for widget access:

```swift
if let containerURL = SharedStorage.sharedContainerURL {
    let storeURL = containerURL.appendingPathComponent("Library/Application Support/CacheStore.sqlite")
    // ...
}
```

### SwiftData Models

**Location**: `GoalsKit/Sources/GoalsData/Persistence/Models/`

| Model | Purpose |
|-------|---------|
| `GoalModel` | User goals with progress tracking |
| `TaskDefinitionModel` | Task definitions for time tracking |
| `TaskSessionModel` | Individual task sessions |
| `EarnedBadgeModel` | Badges earned by users |
| `NutritionEntryModel` | Nutrition entries with nutrients and photo data |
| `CachedDataEntry` | Cached external data |

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
1. Creates and owns all ModelContainers (main store + cache store)
2. Instantiates all repositories with cloud-backed decorators
3. Creates cached data source wrappers
4. Provides use case instances
5. Manages cloud backup services
6. Offers lazy ViewModel properties

```swift
@MainActor
@Observable
public final class AppContainer {
    // Model Container
    public let modelContainer: ModelContainer      // Main store (goals, tasks, badges, nutrition)

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
    public let thumbnailBackfillService: ThumbnailBackfillService

    // Use Cases
    public let createGoalUseCase: CreateGoalUseCase
    public let syncDataSourcesUseCase: SyncDataSourcesUseCase
    public let badgeEvaluationUseCase: BadgeEvaluationUseCase

    // Cloud Backup
    public let cloudSyncQueue: CloudSyncQueue
    public private(set) var cloudBackupService: CloudKitBackupService?
    public private(set) var cloudSyncScheduler: BackgroundCloudSyncScheduler?
    public private(set) var dataRecoveryService: DataRecoveryService?

    // ViewModels (lazily created, persist for app lifetime)
    public var insightsViewModel: InsightsViewModel { ... }
    public var tasksViewModel: TasksViewModel { ... }
}
```

### Wiring Example

```swift
// In AppContainer.init()

// 1. Create cache container first (for data sources)
self.dataCache = DataCache(modelContainer: cacheContainer)

// 2. Create repositories
let goalRepo = SwiftDataGoalRepository(modelContainer: modelContainer)
self.goalRepository = goalRepo

// 3. Create cached data sources
self.typeQuickerDataSource = CachedTypeQuickerDataSource(
    remote: TypeQuickerDataSource(httpClient: httpClient),
    cache: dataCache
)

// 4. Create use cases with dependencies
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

### Data Recovery

`DataRecoveryService` enables restoring data from CloudKit backup:
- Fetches all records from CloudKit zone
- Replaces local data with cloud data
- Used for device migration or data recovery

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
| SwiftData Models | `GoalsKit/Sources/GoalsData/Persistence/Models/` |
| Repository Implementations | `GoalsKit/Sources/GoalsData/Persistence/Repositories/` |
| Repository Protocols | `GoalsKit/Sources/GoalsDomain/Repositories/` |
| Use Cases | `GoalsKit/Sources/GoalsDomain/UseCases/` |
| Cloud Sync | `GoalsKit/Sources/GoalsData/CloudSync/` |
| AppContainer | `GoalsApp/GoalsAppPackage/Sources/GoalsAppFeature/DI/AppContainer.swift` |
| Domain Entities | `GoalsKit/Sources/GoalsDomain/Entities/` |
| ViewModels | `GoalsApp/GoalsAppPackage/Sources/GoalsAppFeature/ViewModels/` |
| Insight Builders | `GoalsApp/GoalsAppPackage/Sources/GoalsWidgetShared/Data/InsightBuilders.swift` |
| Shared Charts | `GoalsApp/GoalsAppPackage/Sources/GoalsWidgetShared/Charts/` |
