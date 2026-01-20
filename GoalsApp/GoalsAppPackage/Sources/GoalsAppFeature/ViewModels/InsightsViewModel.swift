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
            makeCardConfig(from: typeQuicker) {
                AnyView(TypeQuickerInsightsDetailView(viewModel: self.typeQuicker))
            },
            makeCardConfig(from: atCoder) {
                AnyView(AtCoderInsightsDetailView(viewModel: self.atCoder))
            },
            makeCardConfig(from: sleep) {
                AnyView(SleepInsightsDetailView(viewModel: self.sleep))
            }
        ]
    }

    /// Factory method to create card config from any InsightsSectionViewModel
    private func makeCardConfig<VM: InsightsSectionViewModel>(
        from viewModel: VM,
        detailView: @escaping @MainActor () -> AnyView
    ) -> InsightCardConfig {
        InsightCardConfig(
            title: viewModel.title,
            systemImage: viewModel.systemImage,
            color: viewModel.color,
            summary: viewModel.summary,
            activityData: viewModel.activityData,
            makeDetailView: detailView
        )
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
