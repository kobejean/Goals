import Foundation
@testable import GoalsDomain

// MARK: - Mock Goal Repository

/// Mock implementation of GoalRepositoryProtocol for testing
public final class MockGoalRepository: GoalRepositoryProtocol, @unchecked Sendable {
    public var goals: [Goal] = []
    public var updatedProgressCalls: [(goalId: UUID, currentValue: Double)] = []
    public var shouldThrowOnFetch = false
    public var shouldThrowOnUpdate = false

    public init(goals: [Goal] = []) {
        self.goals = goals
    }

    public func fetchAll() async throws -> [Goal] {
        if shouldThrowOnFetch {
            throw MockError.fetchFailed
        }
        return goals
    }

    public func fetchActive() async throws -> [Goal] {
        if shouldThrowOnFetch {
            throw MockError.fetchFailed
        }
        return goals.filter { !$0.isArchived }
    }

    public func fetchArchived() async throws -> [Goal] {
        if shouldThrowOnFetch {
            throw MockError.fetchFailed
        }
        return goals.filter { $0.isArchived }
    }

    public func fetch(id: UUID) async throws -> Goal? {
        if shouldThrowOnFetch {
            throw MockError.fetchFailed
        }
        return goals.first { $0.id == id }
    }

    public func fetch(dataSource: DataSourceType) async throws -> [Goal] {
        if shouldThrowOnFetch {
            throw MockError.fetchFailed
        }
        return goals.filter { $0.dataSource == dataSource }
    }

    @discardableResult
    public func create(_ goal: Goal) async throws -> Goal {
        goals.append(goal)
        return goal
    }

    @discardableResult
    public func update(_ goal: Goal) async throws -> Goal {
        if shouldThrowOnUpdate {
            throw MockError.updateFailed
        }
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
            return goal
        }
        throw MockError.notFound
    }

    public func delete(id: UUID) async throws {
        goals.removeAll { $0.id == id }
    }

    public func archive(id: UUID) async throws {
        if let index = goals.firstIndex(where: { $0.id == id }) {
            var goal = goals[index]
            goal = Goal(
                id: goal.id,
                title: goal.title,
                description: goal.description,
                dataSource: goal.dataSource,
                createdAt: goal.createdAt,
                updatedAt: Date(),
                metricKey: goal.metricKey,
                targetValue: goal.targetValue,
                currentValue: goal.currentValue,
                unit: goal.unit,
                deadline: goal.deadline,
                isArchived: true,
                color: goal.color,
                taskId: goal.taskId
            )
            goals[index] = goal
        }
    }

    public func unarchive(id: UUID) async throws {
        if let index = goals.firstIndex(where: { $0.id == id }) {
            var goal = goals[index]
            goal = Goal(
                id: goal.id,
                title: goal.title,
                description: goal.description,
                dataSource: goal.dataSource,
                createdAt: goal.createdAt,
                updatedAt: Date(),
                metricKey: goal.metricKey,
                targetValue: goal.targetValue,
                currentValue: goal.currentValue,
                unit: goal.unit,
                deadline: goal.deadline,
                isArchived: false,
                color: goal.color,
                taskId: goal.taskId
            )
            goals[index] = goal
        }
    }

    public func updateProgress(goalId: UUID, currentValue: Double) async throws {
        updatedProgressCalls.append((goalId: goalId, currentValue: currentValue))
        if let index = goals.firstIndex(where: { $0.id == goalId }) {
            var goal = goals[index]
            goal = Goal(
                id: goal.id,
                title: goal.title,
                description: goal.description,
                dataSource: goal.dataSource,
                createdAt: goal.createdAt,
                updatedAt: Date(),
                metricKey: goal.metricKey,
                targetValue: goal.targetValue,
                currentValue: currentValue,
                unit: goal.unit,
                deadline: goal.deadline,
                isArchived: goal.isArchived,
                color: goal.color,
                taskId: goal.taskId
            )
            goals[index] = goal
        }
    }
}

// MARK: - Mock Badge Repository

/// Mock implementation of BadgeRepositoryProtocol for testing
public final class MockBadgeRepository: BadgeRepositoryProtocol, @unchecked Sendable {
    public var badges: [EarnedBadge] = []
    public var upsertCalls: [EarnedBadge] = []
    public var shouldThrowOnFetch = false

    public init(badges: [EarnedBadge] = []) {
        self.badges = badges
    }

    public func fetchAll() async throws -> [EarnedBadge] {
        if shouldThrowOnFetch {
            throw MockError.fetchFailed
        }
        return badges
    }

    public func fetch(category: BadgeCategory) async throws -> EarnedBadge? {
        if shouldThrowOnFetch {
            throw MockError.fetchFailed
        }
        return badges.first { $0.category == category }
    }

    public func fetch(relatedTo goalId: UUID) async throws -> [EarnedBadge] {
        if shouldThrowOnFetch {
            throw MockError.fetchFailed
        }
        return badges.filter { $0.relatedGoalId == goalId }
    }

    @discardableResult
    public func upsert(_ badge: EarnedBadge) async throws -> EarnedBadge {
        upsertCalls.append(badge)
        if let index = badges.firstIndex(where: { $0.category == badge.category }) {
            badges[index] = badge
        } else {
            badges.append(badge)
        }
        return badge
    }

    public func deleteAll() async throws {
        badges.removeAll()
    }
}

// MARK: - Mock Data Source Repository

/// Mock implementation of DataSourceRepositoryProtocol for testing
public final class MockDataSourceRepository: DataSourceRepositoryProtocol, @unchecked Sendable {
    public let dataSourceType: DataSourceType
    public var isConfiguredValue = true
    public var metricValues: [String: Double] = [:]
    public var shouldThrowOnFetch = false
    public var configureCallCount = 0
    public var lastConfiguredSettings: DataSourceSettings?

    public var availableMetrics: [MetricInfo] {
        metricValues.keys.map { MetricInfo(key: $0, name: $0, unit: "", icon: "star") }
    }

    public init(dataSourceType: DataSourceType, isConfigured: Bool = true, metricValues: [String: Double] = [:]) {
        self.dataSourceType = dataSourceType
        self.isConfiguredValue = isConfigured
        self.metricValues = metricValues
    }

    public func isConfigured() async -> Bool {
        isConfiguredValue
    }

    public func configure(settings: DataSourceSettings) async throws {
        configureCallCount += 1
        lastConfiguredSettings = settings
        isConfiguredValue = true
    }

    public func clearConfiguration() async throws {
        isConfiguredValue = false
        metricValues.removeAll()
    }

    public func fetchLatestMetricValue(for metricKey: String, taskId: UUID?) async throws -> Double? {
        if shouldThrowOnFetch {
            throw MockError.fetchFailed
        }
        return metricValues[metricKey]
    }

    public func metricValue(for key: String, from stats: Any) -> Double? {
        metricValues[key]
    }
}

// MARK: - Mock Errors

public enum MockError: Error, Equatable {
    case fetchFailed
    case updateFailed
    case notFound
    case networkError
    case parseError
}
