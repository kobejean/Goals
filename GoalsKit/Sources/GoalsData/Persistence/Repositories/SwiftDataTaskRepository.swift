import Foundation
import SwiftData
import GoalsDomain

/// SwiftData implementation of TaskRepositoryProtocol
@MainActor
public final class SwiftDataTaskRepository: TaskRepositoryProtocol {
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Task Definition Operations

    public func fetchAllTasks() async throws -> [TaskDefinition] {
        let descriptor = FetchDescriptor<TaskDefinitionModel>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetchActiveTasks() async throws -> [TaskDefinition] {
        let descriptor = FetchDescriptor<TaskDefinitionModel>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetchTask(id: UUID) async throws -> TaskDefinition? {
        let descriptor = FetchDescriptor<TaskDefinitionModel>(
            predicate: #Predicate { $0.id == id }
        )
        let models = try modelContext.fetch(descriptor)
        return models.first?.toDomain()
    }

    @discardableResult
    public func createTask(_ task: TaskDefinition) async throws -> TaskDefinition {
        let model = TaskDefinitionModel.from(task)
        modelContext.insert(model)
        try modelContext.save()
        return model.toDomain()
    }

    @discardableResult
    public func updateTask(_ task: TaskDefinition) async throws -> TaskDefinition {
        let taskId = task.id
        let descriptor = FetchDescriptor<TaskDefinitionModel>(
            predicate: #Predicate { $0.id == taskId }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        model.update(from: task)
        try modelContext.save()
        return model.toDomain()
    }

    public func deleteTask(id: UUID) async throws {
        let descriptor = FetchDescriptor<TaskDefinitionModel>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    // MARK: - Session Operations

    public func fetchActiveSession() async throws -> TaskSession? {
        let descriptor = FetchDescriptor<TaskSessionModel>(
            predicate: #Predicate { $0.endDate == nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.first?.toDomain()
    }

    @discardableResult
    public func startSession(taskId: UUID) async throws -> TaskSession {
        // First, stop any active sessions
        let activeDescriptor = FetchDescriptor<TaskSessionModel>(
            predicate: #Predicate { $0.endDate == nil }
        )
        let activeSessions = try modelContext.fetch(activeDescriptor)
        let now = Date()
        for session in activeSessions {
            session.endDate = now
        }

        // Create new session
        let newSession = TaskSession(taskId: taskId, startDate: now)
        let model = TaskSessionModel.from(newSession)

        // Link to task
        let taskDescriptor = FetchDescriptor<TaskDefinitionModel>(
            predicate: #Predicate { $0.id == taskId }
        )
        if let taskModel = try modelContext.fetch(taskDescriptor).first {
            model.task = taskModel
        }

        modelContext.insert(model)
        try modelContext.save()
        return model.toDomain()
    }

    @discardableResult
    public func stopSession(id: UUID) async throws -> TaskSession {
        let descriptor = FetchDescriptor<TaskSessionModel>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        model.endDate = Date()
        try modelContext.save()
        return model.toDomain()
    }

    public func fetchSessions(from startDate: Date, to endDate: Date) async throws -> [TaskSession] {
        let descriptor = FetchDescriptor<TaskSessionModel>(
            predicate: #Predicate { session in
                session.startDate >= startDate && session.startDate <= endDate
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetchSessions(taskId: UUID) async throws -> [TaskSession] {
        let descriptor = FetchDescriptor<TaskSessionModel>(
            predicate: #Predicate { $0.taskId == taskId },
            sortBy: [SortDescriptor(\.startDate)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func deleteSession(id: UUID) async throws {
        let descriptor = FetchDescriptor<TaskSessionModel>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    @discardableResult
    public func createSession(_ session: TaskSession) async throws -> TaskSession {
        let model = TaskSessionModel.from(session)

        // Link to task if it exists
        let taskId = session.taskId
        let taskDescriptor = FetchDescriptor<TaskDefinitionModel>(
            predicate: #Predicate { $0.id == taskId }
        )
        if let taskModel = try modelContext.fetch(taskDescriptor).first {
            model.task = taskModel
        }

        modelContext.insert(model)
        try modelContext.save()
        return model.toDomain()
    }

    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    nonisolated public static func == (lhs: SwiftDataTaskRepository, rhs: SwiftDataTaskRepository) -> Bool {
        lhs === rhs
    }
}
