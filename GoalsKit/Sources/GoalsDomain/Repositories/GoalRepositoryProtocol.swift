import Foundation

/// Protocol defining the contract for Goal persistence operations
public protocol GoalRepositoryProtocol: Sendable {
    /// Fetches all goals
    func fetchAll() async throws -> [Goal]

    /// Fetches all active (non-archived) goals
    func fetchActive() async throws -> [Goal]

    /// Fetches archived goals
    func fetchArchived() async throws -> [Goal]

    /// Fetches a goal by its ID
    func fetch(id: UUID) async throws -> Goal?

    /// Fetches goals by type
    func fetch(type: GoalType) async throws -> [Goal]

    /// Fetches goals by data source
    func fetch(dataSource: DataSourceType) async throws -> [Goal]

    /// Creates a new goal
    @discardableResult
    func create(_ goal: Goal) async throws -> Goal

    /// Updates an existing goal
    @discardableResult
    func update(_ goal: Goal) async throws -> Goal

    /// Deletes a goal by its ID
    func delete(id: UUID) async throws

    /// Archives a goal
    func archive(id: UUID) async throws

    /// Unarchives a goal
    func unarchive(id: UUID) async throws

    /// Updates the progress of a numeric goal
    func updateProgress(goalId: UUID, currentValue: Double) async throws

    /// Increments the streak for a habit goal
    func incrementStreak(goalId: UUID) async throws

    /// Resets the streak for a habit goal
    func resetStreak(goalId: UUID) async throws

    /// Marks a milestone goal as completed
    func markCompleted(goalId: UUID) async throws

    /// Marks a milestone goal as incomplete
    func markIncomplete(goalId: UUID) async throws
}
