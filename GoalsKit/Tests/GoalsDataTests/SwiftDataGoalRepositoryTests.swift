import Testing
import Foundation
import SwiftData
@testable import GoalsData
@testable import GoalsDomain

@Suite("SwiftDataGoalRepository Tests")
@MainActor
struct SwiftDataGoalRepositoryTests {

    // Helper to create in-memory model container
    private func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([GoalModel.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - Fetch Tests

    @Test("fetchAll returns goals sorted by createdAt descending")
    func fetchAllReturnsSortedGoals() async throws {
        let container = try makeModelContainer()
        let repository = SwiftDataGoalRepository(modelContainer: container)

        // Create goals with different dates
        let oldDate = Date().addingTimeInterval(-3600 * 24) // 1 day ago
        let recentDate = Date()

        let goal1 = Goal(
            title: "Old Goal",
            dataSource: .typeQuicker,
            createdAt: oldDate,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM"
        )

        let goal2 = Goal(
            title: "Recent Goal",
            dataSource: .typeQuicker,
            createdAt: recentDate,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM"
        )

        try await repository.create(goal1)
        try await repository.create(goal2)

        let goals = try await repository.fetchAll()

        #expect(goals.count == 2)
        #expect(goals.first?.title == "Recent Goal")
        #expect(goals.last?.title == "Old Goal")
    }

    @Test("fetchActive excludes archived goals")
    func fetchActiveExcludesArchived() async throws {
        let container = try makeModelContainer()
        let repository = SwiftDataGoalRepository(modelContainer: container)

        let activeGoal = Goal(
            title: "Active Goal",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM",
            isArchived: false
        )

        let archivedGoal = Goal(
            title: "Archived Goal",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM",
            isArchived: true
        )

        try await repository.create(activeGoal)
        try await repository.create(archivedGoal)

        let goals = try await repository.fetchActive()

        #expect(goals.count == 1)
        #expect(goals.first?.title == "Active Goal")
    }

    @Test("fetchArchived only returns archived goals")
    func fetchArchivedOnlyReturnsArchived() async throws {
        let container = try makeModelContainer()
        let repository = SwiftDataGoalRepository(modelContainer: container)

        let activeGoal = Goal(
            title: "Active Goal",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM",
            isArchived: false
        )

        let archivedGoal = Goal(
            title: "Archived Goal",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM",
            isArchived: true
        )

        try await repository.create(activeGoal)
        try await repository.create(archivedGoal)

        let goals = try await repository.fetchArchived()

        #expect(goals.count == 1)
        #expect(goals.first?.title == "Archived Goal")
    }

    @Test("fetch by dataSource filters correctly")
    func fetchByDataSourceFilters() async throws {
        let container = try makeModelContainer()
        let repository = SwiftDataGoalRepository(modelContainer: container)

        let typeQuickerGoal = Goal(
            title: "TypeQuicker Goal",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM"
        )

        let atCoderGoal = Goal(
            title: "AtCoder Goal",
            dataSource: .atCoder,
            metricKey: "rating",
            targetValue: 1600,
            unit: ""
        )

        try await repository.create(typeQuickerGoal)
        try await repository.create(atCoderGoal)

        let typeQuickerGoals = try await repository.fetch(dataSource: .typeQuicker)

        #expect(typeQuickerGoals.count == 1)
        #expect(typeQuickerGoals.first?.dataSource == .typeQuicker)
    }

    @Test("fetch by id returns specific goal")
    func fetchByIdReturnsGoal() async throws {
        let container = try makeModelContainer()
        let repository = SwiftDataGoalRepository(modelContainer: container)

        let goalId = UUID()
        let goal = Goal(
            id: goalId,
            title: "Specific Goal",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM"
        )

        try await repository.create(goal)

        let fetchedGoal = try await repository.fetch(id: goalId)

        #expect(fetchedGoal != nil)
        #expect(fetchedGoal?.id == goalId)
        #expect(fetchedGoal?.title == "Specific Goal")
    }

    @Test("fetch by id returns nil for missing goal")
    func fetchByIdReturnsNilForMissing() async throws {
        let container = try makeModelContainer()
        let repository = SwiftDataGoalRepository(modelContainer: container)

        let fetchedGoal = try await repository.fetch(id: UUID())

        #expect(fetchedGoal == nil)
    }

    // MARK: - Create Tests

    @Test("create inserts and saves goal")
    func createInsertsAndSaves() async throws {
        let container = try makeModelContainer()
        let repository = SwiftDataGoalRepository(modelContainer: container)

        let goal = Goal(
            title: "New Goal",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM"
        )

        let createdGoal = try await repository.create(goal)

        #expect(createdGoal.title == "New Goal")

        let allGoals = try await repository.fetchAll()
        #expect(allGoals.count == 1)
    }

    // MARK: - Update Tests

    @Test("update modifies existing goal")
    func updateModifiesGoal() async throws {
        let container = try makeModelContainer()
        let repository = SwiftDataGoalRepository(modelContainer: container)

        let goalId = UUID()
        let goal = Goal(
            id: goalId,
            title: "Original Title",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM"
        )

        try await repository.create(goal)

        var updatedGoal = goal
        updatedGoal = Goal(
            id: goalId,
            title: "Updated Title",
            dataSource: goal.dataSource,
            createdAt: goal.createdAt,
            metricKey: goal.metricKey,
            targetValue: 150,
            currentValue: goal.currentValue,
            unit: goal.unit
        )

        let result = try await repository.update(updatedGoal)

        #expect(result.title == "Updated Title")
        #expect(result.targetValue == 150)
    }

    @Test("update throws notFound for missing goal")
    func updateThrowsForMissing() async throws {
        let container = try makeModelContainer()
        let repository = SwiftDataGoalRepository(modelContainer: container)

        let goal = Goal(
            id: UUID(),
            title: "Nonexistent Goal",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM"
        )

        await #expect(throws: RepositoryError.notFound) {
            try await repository.update(goal)
        }
    }

    // MARK: - Delete Tests

    @Test("delete removes goal from store")
    func deleteRemovesGoal() async throws {
        let container = try makeModelContainer()
        let repository = SwiftDataGoalRepository(modelContainer: container)

        let goalId = UUID()
        let goal = Goal(
            id: goalId,
            title: "Goal to Delete",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM"
        )

        try await repository.create(goal)

        var goals = try await repository.fetchAll()
        #expect(goals.count == 1)

        try await repository.delete(id: goalId)

        goals = try await repository.fetchAll()
        #expect(goals.isEmpty)
    }

    // MARK: - Archive Tests

    @Test("archive sets isArchived flag and updates timestamp")
    func archiveSetsFlag() async throws {
        let container = try makeModelContainer()
        let repository = SwiftDataGoalRepository(modelContainer: container)

        let goalId = UUID()
        let goal = Goal(
            id: goalId,
            title: "Goal to Archive",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM",
            isArchived: false
        )

        try await repository.create(goal)

        try await repository.archive(id: goalId)

        let archivedGoal = try await repository.fetch(id: goalId)
        #expect(archivedGoal?.isArchived == true)
    }

    @Test("unarchive clears isArchived flag")
    func unarchiveClearsFlag() async throws {
        let container = try makeModelContainer()
        let repository = SwiftDataGoalRepository(modelContainer: container)

        let goalId = UUID()
        let goal = Goal(
            id: goalId,
            title: "Archived Goal",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM",
            isArchived: true
        )

        try await repository.create(goal)

        try await repository.unarchive(id: goalId)

        let unarchivedGoal = try await repository.fetch(id: goalId)
        #expect(unarchivedGoal?.isArchived == false)
    }

    // MARK: - Update Progress Tests

    @Test("updateProgress modifies currentValue")
    func updateProgressModifiesValue() async throws {
        let container = try makeModelContainer()
        let repository = SwiftDataGoalRepository(modelContainer: container)

        let goalId = UUID()
        let goal = Goal(
            id: goalId,
            title: "Progress Goal",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            currentValue: 0,
            unit: "WPM"
        )

        try await repository.create(goal)

        try await repository.updateProgress(goalId: goalId, currentValue: 75.5)

        let updatedGoal = try await repository.fetch(id: goalId)
        #expect(updatedGoal?.currentValue == 75.5)
    }

    @Test("updateProgress throws notFound for missing goal")
    func updateProgressThrowsForMissing() async throws {
        let container = try makeModelContainer()
        let repository = SwiftDataGoalRepository(modelContainer: container)

        await #expect(throws: RepositoryError.notFound) {
            try await repository.updateProgress(goalId: UUID(), currentValue: 50)
        }
    }
}
