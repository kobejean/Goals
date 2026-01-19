import Foundation

/// Protocol defining the contract for Badge persistence operations
public protocol BadgeRepositoryProtocol: Sendable {
    /// Fetches all earned badges
    func fetchAll() async throws -> [EarnedBadge]

    /// Fetches an earned badge by category
    func fetch(category: BadgeCategory) async throws -> EarnedBadge?

    /// Fetches badges related to a specific goal
    func fetch(relatedTo goalId: UUID) async throws -> [EarnedBadge]

    /// Creates or updates an earned badge
    @discardableResult
    func upsert(_ badge: EarnedBadge) async throws -> EarnedBadge

    /// Deletes all earned badges
    func deleteAll() async throws
}
