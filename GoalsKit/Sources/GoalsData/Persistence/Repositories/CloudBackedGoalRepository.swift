import Foundation
import GoalsDomain

/// Decorator that wraps a GoalRepository and queues changes for CloudKit backup
@MainActor
public final class CloudBackedGoalRepository: GoalRepositoryProtocol {
    private let local: GoalRepositoryProtocol
    private let syncQueue: CloudSyncQueue

    public init(local: GoalRepositoryProtocol, syncQueue: CloudSyncQueue) {
        self.local = local
        self.syncQueue = syncQueue
    }

    // MARK: - Read Operations (delegate to local)

    public func fetchAll() async throws -> [Goal] {
        try await local.fetchAll()
    }

    public func fetchActive() async throws -> [Goal] {
        try await local.fetchActive()
    }

    public func fetchArchived() async throws -> [Goal] {
        try await local.fetchArchived()
    }

    public func fetch(id: UUID) async throws -> Goal? {
        try await local.fetch(id: id)
    }

    public func fetch(dataSource: DataSourceType) async throws -> [Goal] {
        try await local.fetch(dataSource: dataSource)
    }

    // MARK: - Write Operations (delegate + queue for sync)

    @discardableResult
    public func create(_ goal: Goal) async throws -> Goal {
        let created = try await local.create(goal)
        await syncQueue.enqueueUpsert(created)
        return created
    }

    @discardableResult
    public func update(_ goal: Goal) async throws -> Goal {
        let updated = try await local.update(goal)
        await syncQueue.enqueueUpsert(updated)
        return updated
    }

    public func delete(id: UUID) async throws {
        try await local.delete(id: id)
        await syncQueue.enqueueDelete(recordType: Goal.recordType, id: id)
    }

    public func archive(id: UUID) async throws {
        try await local.archive(id: id)
        // Fetch the archived goal to sync its updated state
        if let goal = try await local.fetch(id: id) {
            await syncQueue.enqueueUpsert(goal)
        }
    }

    public func unarchive(id: UUID) async throws {
        try await local.unarchive(id: id)
        // Fetch the unarchived goal to sync its updated state
        if let goal = try await local.fetch(id: id) {
            await syncQueue.enqueueUpsert(goal)
        }
    }

    public func updateProgress(goalId: UUID, currentValue: Double) async throws {
        try await local.updateProgress(goalId: goalId, currentValue: currentValue)
        // Fetch the updated goal to sync
        if let goal = try await local.fetch(id: goalId) {
            await syncQueue.enqueueUpsert(goal)
        }
    }
}
