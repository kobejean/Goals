import Foundation

/// Protocol defining the contract for Task persistence operations
public protocol TaskRepositoryProtocol: Sendable {
    // MARK: - Task Definition Operations

    /// Fetches all task definitions
    func fetchAllTasks() async throws -> [TaskDefinition]

    /// Fetches active (non-archived) task definitions
    func fetchActiveTasks() async throws -> [TaskDefinition]

    /// Fetches a task by its ID
    func fetchTask(id: UUID) async throws -> TaskDefinition?

    /// Creates a new task definition
    @discardableResult
    func createTask(_ task: TaskDefinition) async throws -> TaskDefinition

    /// Updates an existing task definition
    @discardableResult
    func updateTask(_ task: TaskDefinition) async throws -> TaskDefinition

    /// Deletes a task definition by its ID
    func deleteTask(id: UUID) async throws

    // MARK: - Session Operations

    /// Fetches the currently active session, if any
    func fetchActiveSession() async throws -> TaskSession?

    /// Starts a new session for a task
    /// If there's an active session, it will be stopped first
    @discardableResult
    func startSession(taskId: UUID) async throws -> TaskSession

    /// Stops an active session
    @discardableResult
    func stopSession(id: UUID) async throws -> TaskSession

    /// Fetches sessions within a date range
    func fetchSessions(from startDate: Date, to endDate: Date) async throws -> [TaskSession]

    /// Fetches all sessions for a specific task
    func fetchSessions(taskId: UUID) async throws -> [TaskSession]

    /// Deletes a session by its ID
    func deleteSession(id: UUID) async throws

    /// Creates a session directly (for backup restoration)
    /// Unlike startSession, this doesn't stop active sessions or set defaults
    @discardableResult
    func createSession(_ session: TaskSession) async throws -> TaskSession
}
