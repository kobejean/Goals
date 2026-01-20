import SwiftUI
import GoalsDomain
import GoalsData

/// Main ViewModel for the Insights view
/// Owns all section view models and provides observable card data
@MainActor @Observable
public final class InsightsViewModel {
    // MARK: - Section ViewModels (concrete types for proper observation)

    public let typeQuicker: TypeQuickerInsightsViewModel
    public let atCoder: AtCoderInsightsViewModel
    public let sleep: SleepInsightsViewModel

    // MARK: - Initialization

    public init(
        typeQuickerDataSource: CachedTypeQuickerDataSource,
        atCoderDataSource: CachedAtCoderDataSource,
        sleepDataSource: CachedHealthKitSleepDataSource,
        goalRepository: GoalRepositoryProtocol
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
    }

    // MARK: - Card Data (computed from owned view models)

    /// All insight cards for display
    public var cards: [InsightCardConfig] {
        [
            InsightCardConfig(
                title: typeQuicker.title,
                systemImage: typeQuicker.systemImage,
                color: typeQuicker.color,
                summary: typeQuicker.summary,
                activityData: typeQuicker.activityData,
                makeDetailView: { AnyView(TypeQuickerInsightsDetailView(viewModel: self.typeQuicker)) }
            ),
            InsightCardConfig(
                title: atCoder.title,
                systemImage: atCoder.systemImage,
                color: atCoder.color,
                summary: atCoder.summary,
                activityData: atCoder.activityData,
                makeDetailView: { AnyView(AtCoderInsightsDetailView(viewModel: self.atCoder)) }
            ),
            InsightCardConfig(
                title: sleep.title,
                systemImage: sleep.systemImage,
                color: sleep.color,
                summary: sleep.summary,
                activityData: sleep.activityData,
                makeDetailView: { AnyView(SleepInsightsDetailView(viewModel: self.sleep)) }
            )
        ]
    }

    // MARK: - Data Loading

    /// Load all section data in parallel
    public func loadAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.typeQuicker.loadData() }
            group.addTask { await self.atCoder.loadData() }
            group.addTask { await self.sleep.loadData() }
        }
    }
}
