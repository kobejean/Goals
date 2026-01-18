import Foundation
import SwiftData
import GoalsDomain

/// SwiftData implementation of GoalRepositoryProtocol
@MainActor
public final class SwiftDataGoalRepository: GoalRepositoryProtocol {
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    public func fetchAll() async throws -> [Goal] {
        let descriptor = FetchDescriptor<GoalModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetchActive() async throws -> [Goal] {
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetchArchived() async throws -> [Goal] {
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.isArchived },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetch(id: UUID) async throws -> Goal? {
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.id == id }
        )
        let models = try modelContext.fetch(descriptor)
        return models.first?.toDomain()
    }

    public func fetch(type: GoalType) async throws -> [Goal] {
        let typeRaw = type.rawValue
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.typeRawValue == typeRaw && !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetch(dataSource: DataSourceType) async throws -> [Goal] {
        let sourceRaw = dataSource.rawValue
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.dataSourceRawValue == sourceRaw && !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    @discardableResult
    public func create(_ goal: Goal) async throws -> Goal {
        let model = GoalModel.from(goal)
        modelContext.insert(model)
        try modelContext.save()
        return model.toDomain()
    }

    @discardableResult
    public func update(_ goal: Goal) async throws -> Goal {
        let goalId = goal.id
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.id == goalId }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        model.update(from: goal)
        try modelContext.save()
        return model.toDomain()
    }

    public func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    public func archive(id: UUID) async throws {
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        model.isArchived = true
        model.updatedAt = Date()
        try modelContext.save()
    }

    public func unarchive(id: UUID) async throws {
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        model.isArchived = false
        model.updatedAt = Date()
        try modelContext.save()
    }

    public func updateProgress(goalId: UUID, currentValue: Double) async throws {
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.id == goalId }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        model.currentValue = currentValue
        model.updatedAt = Date()
        try modelContext.save()
    }

    public func incrementStreak(goalId: UUID) async throws {
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.id == goalId }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        let newStreak = (model.currentStreak ?? 0) + 1
        model.currentStreak = newStreak
        if newStreak > (model.longestStreak ?? 0) {
            model.longestStreak = newStreak
        }
        model.updatedAt = Date()
        try modelContext.save()
    }

    public func resetStreak(goalId: UUID) async throws {
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.id == goalId }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        model.currentStreak = 0
        model.updatedAt = Date()
        try modelContext.save()
    }

    public func markCompleted(goalId: UUID) async throws {
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.id == goalId }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        model.isCompleted = true
        model.completedAt = Date()
        model.updatedAt = Date()
        try modelContext.save()
    }

    public func markIncomplete(goalId: UUID) async throws {
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.id == goalId }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        model.isCompleted = false
        model.completedAt = nil
        model.updatedAt = Date()
        try modelContext.save()
    }

    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    nonisolated public static func == (lhs: SwiftDataGoalRepository, rhs: SwiftDataGoalRepository) -> Bool {
        lhs === rhs
    }
}

/// Repository errors
public enum RepositoryError: Error, Sendable {
    case notFound
    case saveFailed
    case invalidData
}
