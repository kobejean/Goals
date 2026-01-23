import SwiftUI
import WidgetKit
import GoalsDomain
import GoalsData
import GoalsWidgetShared

/// Main ViewModel for the Insights view
/// Owns all section view models and provides observable card data
@MainActor @Observable
public final class InsightsViewModel {
    // MARK: - Section ViewModels (concrete types for proper observation)

    public let typeQuicker: TypeQuickerInsightsViewModel

    // MARK: - Throttling

    private var lastLoadedAt: Date? {
        didSet { saveLastLoadedAt() }
    }
    private let minRefreshInterval: TimeInterval = 60 * 60  // 1 hour
    public let atCoder: AtCoderInsightsViewModel
    public let sleep: SleepInsightsViewModel
    public let tasks: TasksInsightsViewModel
    public let anki: AnkiInsightsViewModel
    public let zotero: ZoteroInsightsViewModel

    // MARK: - Card Ordering

    /// Current order of insight cards (persisted to UserDefaults)
    public var cardOrder: [InsightType] {
        didSet {
            saveCardOrder()
        }
    }

    // MARK: - Initialization

    public init(
        typeQuickerDataSource: CachedTypeQuickerDataSource,
        atCoderDataSource: CachedAtCoderDataSource,
        sleepDataSource: CachedHealthKitSleepDataSource,
        taskRepository: TaskRepositoryProtocol,
        goalRepository: GoalRepositoryProtocol,
        ankiDataSource: CachedAnkiDataSource,
        zoteroDataSource: CachedZoteroDataSource,
        taskCachingService: TaskCachingService? = nil
    ) {
        self.typeQuicker = TypeQuickerInsightsViewModel(
            dataSource: typeQuickerDataSource,
            goalRepository: goalRepository
        )
        self.atCoder = AtCoderInsightsViewModel(
            dataSource: atCoderDataSource,
            goalRepository: goalRepository
        )
        self.sleep = SleepInsightsViewModel(
            dataSource: sleepDataSource,
            goalRepository: goalRepository
        )
        self.tasks = TasksInsightsViewModel(
            taskRepository: taskRepository,
            goalRepository: goalRepository,
            taskCachingService: taskCachingService
        )
        self.anki = AnkiInsightsViewModel(
            dataSource: ankiDataSource,
            goalRepository: goalRepository
        )
        self.zotero = ZoteroInsightsViewModel(
            dataSource: zoteroDataSource,
            goalRepository: goalRepository
        )

        // Load persisted card order or use default
        self.cardOrder = Self.loadCardOrder()

        // Load persisted throttle timestamp
        self.lastLoadedAt = Self.loadLastLoadedAt()
    }

    // MARK: - Card Data (computed from owned view models)

    /// All insight cards for display, ordered by cardOrder
    public var cards: [InsightCardConfig] {
        cardOrder.compactMap { type in
            allCards[type]
        }
    }

    /// Dictionary of all available cards by type
    private var allCards: [InsightType: InsightCardConfig] {
        [
            .typeQuicker: makeCardConfig(type: .typeQuicker, from: typeQuicker) {
                AnyView(TypeQuickerInsightsDetailView(viewModel: self.typeQuicker))
            },
            .atCoder: makeCardConfig(type: .atCoder, from: atCoder) {
                AnyView(AtCoderInsightsDetailView(viewModel: self.atCoder))
            },
            .sleep: makeCardConfig(type: .sleep, from: sleep) {
                AnyView(SleepInsightsDetailView(viewModel: self.sleep))
            },
            .tasks: makeCardConfig(type: .tasks, from: tasks) {
                AnyView(TasksInsightsDetailView(viewModel: self.tasks))
            },
            .anki: makeCardConfig(type: .anki, from: anki) {
                AnyView(AnkiInsightsDetailView(viewModel: self.anki))
            },
            .zotero: makeCardConfig(type: .zotero, from: zotero) {
                AnyView(ZoteroInsightsDetailView(viewModel: self.zotero))
            }
        ]
    }

    /// Factory method to create card config from any InsightsSectionViewModel
    private func makeCardConfig<VM: InsightsSectionViewModel>(
        type: InsightType,
        from viewModel: VM,
        detailView: @escaping @MainActor () -> AnyView
    ) -> InsightCardConfig {
        InsightCardConfig(
            type: type,
            title: viewModel.title,
            systemImage: viewModel.systemImage,
            color: viewModel.color,
            summary: viewModel.summary,
            activityData: viewModel.activityData,
            fetchStatus: viewModel.fetchStatus,
            makeDetailView: detailView
        )
    }

    // MARK: - Card Reordering

    /// Move a card from one position to another
    public func moveCard(from source: IndexSet, to destination: Int) {
        cardOrder.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Persistence

    private static func loadCardOrder() -> [InsightType] {
        guard let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.insightsCardOrder),
              let order = try? JSONDecoder().decode([InsightType].self, from: data) else {
            return InsightType.defaultOrder
        }

        // Ensure all types are present (handles new types added in updates)
        var result = order.filter { InsightType.allCases.contains($0) }
        for type in InsightType.allCases where !result.contains(type) {
            result.append(type)
        }
        return result
    }

    private func saveCardOrder() {
        guard let data = try? JSONEncoder().encode(cardOrder) else { return }
        UserDefaults.standard.set(data, forKey: UserDefaultsKeys.insightsCardOrder)
        // Also save to shared defaults for widget access
        UserDefaults.shared.set(data, forKey: UserDefaultsKeys.insightsCardOrder)
    }

    private static func loadLastLoadedAt() -> Date? {
        UserDefaults.standard.object(forKey: UserDefaultsKeys.insightsLastLoadedAt) as? Date
    }

    private func saveLastLoadedAt() {
        UserDefaults.standard.set(lastLoadedAt, forKey: UserDefaultsKeys.insightsLastLoadedAt)
    }

    // MARK: - Data Loading

    /// Load all section data in parallel
    /// - Parameter force: If true, bypasses the throttle check (used for pull-to-refresh)
    public func loadAll(force: Bool = false) async {
        // Check throttle first
        let shouldFetchFresh = force || lastLoadedAt == nil ||
            Date().timeIntervalSince(lastLoadedAt!) >= minRefreshInterval

        if shouldFetchFresh {
            // Not throttled: loadData() handles both cached + fresh fetching
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.typeQuicker.loadData() }
                group.addTask { await self.atCoder.loadData() }
                group.addTask { await self.sleep.loadData() }
                group.addTask { await self.tasks.loadData() }
                group.addTask { await self.anki.loadData() }
                group.addTask { await self.zotero.loadData() }
            }

            lastLoadedAt = Date()

            // Trigger widget refresh after all data is loaded
            WidgetCenter.shared.reloadAllTimelines()
        } else {
            // Throttled: only load cached data for instant display
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.typeQuicker.loadCachedData() }
                group.addTask { await self.atCoder.loadCachedData() }
                group.addTask { await self.sleep.loadCachedData() }
                group.addTask { await self.tasks.loadCachedData() }
                group.addTask { await self.anki.loadCachedData() }
                group.addTask { await self.zotero.loadCachedData() }
            }
        }
    }
}
