import Foundation
import GoalsDomain

/// Decorator that wraps a TaskRepository and queues changes for CloudKit backup
@MainActor
public final class CloudBackedTaskRepository: TaskRepositoryProtocol {
    private let local: TaskRepositoryProtocol
    private let syncQueue: CloudSyncQueue

    public init(local: TaskRepositoryProtocol, syncQueue: CloudSyncQueue) {
        self.local = local
        self.syncQueue = syncQueue
    }

    // MARK: - Task Definition Read Operations

    public func fetchAllTasks() async throws -> [TaskDefinition] {
        try await local.fetchAllTasks()
    }

    public func fetchActiveTasks() async throws -> [TaskDefinition] {
        try await local.fetchActiveTasks()
    }

    public func fetchTask(id: UUID) async throws -> TaskDefinition? {
        try await local.fetchTask(id: id)
    }

    // MARK: - Task Definition Write Operations

    @discardableResult
    public func createTask(_ task: TaskDefinition) async throws -> TaskDefinition {
        let created = try await local.createTask(task)
        await syncQueue.enqueueUpsert(created)
        return created
    }

    @discardableResult
    public func updateTask(_ task: TaskDefinition) async throws -> TaskDefinition {
        let updated = try await local.updateTask(task)
        await syncQueue.enqueueUpsert(updated)
        return updated
    }

    public func deleteTask(id: UUID) async throws {
        try await local.deleteTask(id: id)
        await syncQueue.enqueueDelete(recordType: TaskDefinition.recordType, id: id)
    }

    // MARK: - Session Read Operations

    public func fetchActiveSession() async throws -> TaskSession? {
        try await local.fetchActiveSession()
    }

    public func fetchSessions(from startDate: Date, to endDate: Date) async throws -> [TaskSession] {
        try await local.fetchSessions(from: startDate, to: endDate)
    }

    public func fetchSessions(taskId: UUID) async throws -> [TaskSession] {
        try await local.fetchSessions(taskId: taskId)
    }

    // MARK: - Session Write Operations

    @discardableResult
    public func startSession(taskId: UUID) async throws -> TaskSession {
        let session = try await local.startSession(taskId: taskId)
        await syncQueue.enqueueUpsert(session)
        return session
    }

    @discardableResult
    public func stopSession(id: UUID) async throws -> TaskSession {
        let session = try await local.stopSession(id: id)
        await syncQueue.enqueueUpsert(session)
        return session
    }

    public func deleteSession(id: UUID) async throws {
        try await local.deleteSession(id: id)
        await syncQueue.enqueueDelete(recordType: TaskSession.recordType, id: id)
    }

    @discardableResult
    public func createSession(_ session: TaskSession) async throws -> TaskSession {
        let created = try await local.createSession(session)
        await syncQueue.enqueueUpsert(created)
        return created
    }
}
