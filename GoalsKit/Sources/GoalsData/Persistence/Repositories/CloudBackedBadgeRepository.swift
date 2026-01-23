import Foundation
import GoalsDomain

/// Decorator that wraps a BadgeRepository and queues changes for CloudKit backup
@MainActor
public final class CloudBackedBadgeRepository: BadgeRepositoryProtocol {
    private let local: BadgeRepositoryProtocol
    private let syncQueue: CloudSyncQueue

    public init(local: BadgeRepositoryProtocol, syncQueue: CloudSyncQueue) {
        self.local = local
        self.syncQueue = syncQueue
    }

    // MARK: - Read Operations

    public func fetchAll() async throws -> [EarnedBadge] {
        try await local.fetchAll()
    }

    public func fetch(category: BadgeCategory) async throws -> EarnedBadge? {
        try await local.fetch(category: category)
    }

    public func fetch(relatedTo goalId: UUID) async throws -> [EarnedBadge] {
        try await local.fetch(relatedTo: goalId)
    }

    // MARK: - Write Operations

    @discardableResult
    public func upsert(_ badge: EarnedBadge) async throws -> EarnedBadge {
        let upserted = try await local.upsert(badge)
        await syncQueue.enqueueUpsert(upserted)
        return upserted
    }

    public func deleteAll() async throws {
        // Fetch all badges first to queue deletes
        let badges = try await local.fetchAll()
        try await local.deleteAll()

        // Queue deletes for all badges
        for badge in badges {
            await syncQueue.enqueueDelete(recordType: EarnedBadge.recordType, id: badge.id)
        }
    }
}
