import Testing
import Foundation
@testable import GoalsDomain

@Suite("SyncDataSourcesUseCase Tests")
struct SyncDataSourcesUseCaseTests {

    // MARK: - syncAll Tests

    @Test("syncAll runs all data sources in parallel")
    func syncAllRunsAllSourcesInParallel() async throws {
        let goal1 = Goal(
            title: "Typing Goal",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM"
        )

        let goal2 = Goal(
            title: "Rating Goal",
            dataSource: .atCoder,
            metricKey: "rating",
            targetValue: 1600,
            unit: ""
        )

        let goalRepo = MockGoalRepository(goals: [goal1, goal2])

        let typeQuickerRepo = MockDataSourceRepository(
            dataSourceType: .typeQuicker,
            isConfigured: true,
            metricValues: ["wpm": 85.0]
        )
        let atCoderRepo = MockDataSourceRepository(
            dataSourceType: .atCoder,
            isConfigured: true,
            metricValues: ["rating": 1200.0]
        )

        let useCase = SyncDataSourcesUseCase(
            goalRepository: goalRepo,
            dataSources: [
                .typeQuicker: typeQuickerRepo,
                .atCoder: atCoderRepo
            ]
        )

        let result = try await useCase.syncAll()

        #expect(result.sourceResults.count == 2)
        #expect(result.sourceResults[.typeQuicker]?.success == true)
        #expect(result.sourceResults[.atCoder]?.success == true)
    }

    @Test("syncAll isolates per-source errors")
    func syncAllIsolatesErrors() async throws {
        let goal1 = Goal(
            title: "Typing Goal",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM"
        )

        let goal2 = Goal(
            title: "Rating Goal",
            dataSource: .atCoder,
            metricKey: "rating",
            targetValue: 1600,
            unit: ""
        )

        let goalRepo = MockGoalRepository(goals: [goal1, goal2])

        let typeQuickerRepo = MockDataSourceRepository(
            dataSourceType: .typeQuicker,
            isConfigured: true,
            metricValues: ["wpm": 85.0]
        )
        typeQuickerRepo.shouldThrowOnFetch = true // This will fail

        let atCoderRepo = MockDataSourceRepository(
            dataSourceType: .atCoder,
            isConfigured: true,
            metricValues: ["rating": 1200.0]
        )

        let useCase = SyncDataSourcesUseCase(
            goalRepository: goalRepo,
            dataSources: [
                .typeQuicker: typeQuickerRepo,
                .atCoder: atCoderRepo
            ]
        )

        let result = try await useCase.syncAll()

        // TypeQuicker should fail, AtCoder should succeed
        #expect(result.sourceResults[.typeQuicker]?.success == false)
        #expect(result.sourceResults[.typeQuicker]?.error != nil)
        #expect(result.sourceResults[.atCoder]?.success == true)
    }

    @Test("syncAll aggregates results from all sources")
    func syncAllAggregatesResults() async throws {
        let goals = (0..<3).map { i in
            Goal(
                title: "Goal \(i)",
                dataSource: .typeQuicker,
                metricKey: "wpm",
                targetValue: 100,
                unit: "WPM"
            )
        }

        let goalRepo = MockGoalRepository(goals: goals)

        let typeQuickerRepo = MockDataSourceRepository(
            dataSourceType: .typeQuicker,
            isConfigured: true,
            metricValues: ["wpm": 85.0]
        )

        let useCase = SyncDataSourcesUseCase(
            goalRepository: goalRepo,
            dataSources: [.typeQuicker: typeQuickerRepo]
        )

        let result = try await useCase.syncAll()

        #expect(result.sourceResults[.typeQuicker]?.goalsUpdated == 3)
        #expect(result.totalGoalsUpdated == 3)
    }

    @Test("syncAll returns success for empty goals list")
    func syncAllReturnsSuccessForEmptyGoals() async throws {
        let goalRepo = MockGoalRepository(goals: [])

        let typeQuickerRepo = MockDataSourceRepository(
            dataSourceType: .typeQuicker,
            isConfigured: true,
            metricValues: ["wpm": 85.0]
        )

        let useCase = SyncDataSourcesUseCase(
            goalRepository: goalRepo,
            dataSources: [.typeQuicker: typeQuickerRepo]
        )

        let result = try await useCase.syncAll()

        #expect(result.sourceResults[.typeQuicker]?.success == true)
        #expect(result.sourceResults[.typeQuicker]?.goalsUpdated == 0)
    }

    @Test("syncAll updates goal progress with fetched metric values")
    func syncAllUpdatesGoalProgress() async throws {
        let goalId = UUID()
        let goal = Goal(
            id: goalId,
            title: "Typing Goal",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            currentValue: 0,
            unit: "WPM"
        )

        let goalRepo = MockGoalRepository(goals: [goal])

        let typeQuickerRepo = MockDataSourceRepository(
            dataSourceType: .typeQuicker,
            isConfigured: true,
            metricValues: ["wpm": 85.0]
        )

        let useCase = SyncDataSourcesUseCase(
            goalRepository: goalRepo,
            dataSources: [.typeQuicker: typeQuickerRepo]
        )

        _ = try await useCase.syncAll()

        // Check that updateProgress was called
        #expect(goalRepo.updatedProgressCalls.count == 1)
        #expect(goalRepo.updatedProgressCalls.first?.goalId == goalId)
        #expect(goalRepo.updatedProgressCalls.first?.currentValue == 85.0)
    }

    // MARK: - sync Single Source Tests

    @Test("sync throws dataSourceNotFound for unknown source")
    func syncThrowsDataSourceNotFound() async throws {
        let goalRepo = MockGoalRepository(goals: [])
        let useCase = SyncDataSourcesUseCase(
            goalRepository: goalRepo,
            dataSources: [:] // Empty
        )

        await #expect(throws: (any Error).self) {
            _ = try await useCase.sync(dataSource: .typeQuicker)
        }
    }

    @Test("sync throws notConfigured when unconfigured")
    func syncThrowsNotConfigured() async throws {
        let goal = Goal(
            title: "Typing Goal",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM"
        )

        let goalRepo = MockGoalRepository(goals: [goal])

        let typeQuickerRepo = MockDataSourceRepository(
            dataSourceType: .typeQuicker,
            isConfigured: false, // Not configured
            metricValues: [:]
        )

        let useCase = SyncDataSourcesUseCase(
            goalRepository: goalRepo,
            dataSources: [.typeQuicker: typeQuickerRepo]
        )

        await #expect(throws: (any Error).self) {
            _ = try await useCase.sync(dataSource: .typeQuicker)
        }
    }

    // MARK: - SyncResult Tests

    @Test("SyncResult.allSuccessful returns true only when all succeed")
    func syncResultAllSuccessful() async throws {
        // Test with all successful
        let allSuccess = SyncResult(
            timestamp: Date(),
            sourceResults: [
                .typeQuicker: SyncSourceResult(
                    dataSource: .typeQuicker,
                    success: true,
                    goalsUpdated: 1,
                    error: nil
                ),
                .atCoder: SyncSourceResult(
                    dataSource: .atCoder,
                    success: true,
                    goalsUpdated: 2,
                    error: nil
                )
            ]
        )

        #expect(allSuccess.allSuccessful == true)

        // Test with one failure
        let partialSuccess = SyncResult(
            timestamp: Date(),
            sourceResults: [
                .typeQuicker: SyncSourceResult(
                    dataSource: .typeQuicker,
                    success: true,
                    goalsUpdated: 1,
                    error: nil
                ),
                .atCoder: SyncSourceResult(
                    dataSource: .atCoder,
                    success: false,
                    goalsUpdated: 0,
                    error: MockError.fetchFailed
                )
            ]
        )

        #expect(partialSuccess.allSuccessful == false)
    }

    @Test("SyncResult.totalGoalsUpdated sums across all sources")
    func syncResultTotalGoalsUpdated() async throws {
        let result = SyncResult(
            timestamp: Date(),
            sourceResults: [
                .typeQuicker: SyncSourceResult(
                    dataSource: .typeQuicker,
                    success: true,
                    goalsUpdated: 3,
                    error: nil
                ),
                .atCoder: SyncSourceResult(
                    dataSource: .atCoder,
                    success: true,
                    goalsUpdated: 2,
                    error: nil
                ),
                .anki: SyncSourceResult(
                    dataSource: .anki,
                    success: false,
                    goalsUpdated: 0,
                    error: MockError.fetchFailed
                )
            ]
        )

        #expect(result.totalGoalsUpdated == 5)
    }
}
