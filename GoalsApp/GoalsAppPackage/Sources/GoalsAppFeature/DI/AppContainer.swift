import Foundation
import SwiftData
import GoalsDomain
import GoalsData

/// Dependency injection container for the app
@MainActor
@Observable
public final class AppContainer {
    // MARK: - Model Container

    public let modelContainer: ModelContainer

    // MARK: - Repositories

    public let goalRepository: GoalRepositoryProtocol
    public let dataPointRepository: DataPointRepositoryProtocol

    // MARK: - Data Sources

    public let typeQuickerDataSource: TypeQuickerDataSource
    public let atCoderDataSource: AtCoderDataSource

    // MARK: - Use Cases

    public let createGoalUseCase: CreateGoalUseCase
    public let trackProgressUseCase: TrackProgressUseCase
    public let syncDataSourcesUseCase: SyncDataSourcesUseCase

    // MARK: - Initialization

    public init() throws {
        // Configure SwiftData
        let schema = Schema([
            GoalModel.self,
            DataPointModel.self,
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
        let dataPointRepo = SwiftDataDataPointRepository(modelContainer: modelContainer)

        self.goalRepository = goalRepo
        self.dataPointRepository = dataPointRepo

        // Initialize data sources
        self.typeQuickerDataSource = TypeQuickerDataSource()
        self.atCoderDataSource = AtCoderDataSource()

        // Initialize use cases
        self.createGoalUseCase = CreateGoalUseCase(goalRepository: goalRepo)
        self.trackProgressUseCase = TrackProgressUseCase(
            goalRepository: goalRepo,
            dataPointRepository: dataPointRepo
        )
        self.syncDataSourcesUseCase = SyncDataSourcesUseCase(
            goalRepository: goalRepo,
            dataPointRepository: dataPointRepo,
            dataSources: [
                .typeQuicker: typeQuickerDataSource,
                .atCoder: atCoderDataSource
            ]
        )
    }

    /// Creates an in-memory container for previews and testing
    public static func preview() throws -> AppContainer {
        try AppContainer(inMemory: true)
    }

    private init(inMemory: Bool) throws {
        let schema = Schema([
            GoalModel.self,
            DataPointModel.self,
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
        let dataPointRepo = SwiftDataDataPointRepository(modelContainer: modelContainer)

        self.goalRepository = goalRepo
        self.dataPointRepository = dataPointRepo

        self.typeQuickerDataSource = TypeQuickerDataSource()
        self.atCoderDataSource = AtCoderDataSource()

        self.createGoalUseCase = CreateGoalUseCase(goalRepository: goalRepo)
        self.trackProgressUseCase = TrackProgressUseCase(
            goalRepository: goalRepo,
            dataPointRepository: dataPointRepo
        )
        self.syncDataSourcesUseCase = SyncDataSourcesUseCase(
            goalRepository: goalRepo,
            dataPointRepository: dataPointRepo,
            dataSources: [
                .typeQuicker: typeQuickerDataSource,
                .atCoder: atCoderDataSource
            ]
        )
    }
}
