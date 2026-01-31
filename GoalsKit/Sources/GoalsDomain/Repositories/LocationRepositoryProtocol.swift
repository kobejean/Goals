import Foundation

/// Protocol defining the contract for Location persistence operations
public protocol LocationRepositoryProtocol: Sendable {
    // MARK: - Location Definition Operations

    /// Fetches all location definitions
    func fetchAllLocations() async throws -> [LocationDefinition]

    /// Fetches active (non-archived) location definitions
    func fetchActiveLocations() async throws -> [LocationDefinition]

    /// Fetches a location by its ID
    func fetchLocation(id: UUID) async throws -> LocationDefinition?

    /// Creates a new location definition
    @discardableResult
    func createLocation(_ location: LocationDefinition) async throws -> LocationDefinition

    /// Updates an existing location definition
    @discardableResult
    func updateLocation(_ location: LocationDefinition) async throws -> LocationDefinition

    /// Deletes a location definition by its ID
    func deleteLocation(id: UUID) async throws

    // MARK: - Session Operations

    /// Fetches the currently active session, if any
    func fetchActiveSession() async throws -> LocationSession?

    /// Fetches sessions for a specific date
    func fetchSessions(for date: Date) async throws -> [LocationSession]

    /// Fetches sessions within a date range for a specific location
    func fetchSessions(locationId: UUID, from startDate: Date, to endDate: Date) async throws -> [LocationSession]

    /// Fetches all sessions within a date range
    func fetchSessions(from startDate: Date, to endDate: Date) async throws -> [LocationSession]

    /// Starts a new session for a location
    /// If there's an active session, it will be stopped first
    @discardableResult
    func startSession(locationId: UUID, at date: Date) async throws -> LocationSession

    /// Ends an active session
    @discardableResult
    func endSession(id: UUID, at date: Date) async throws -> LocationSession

    /// Confirms a session (marks it as user-verified)
    @discardableResult
    func confirmSession(id: UUID) async throws -> LocationSession

    /// Deletes a session by its ID
    func deleteSession(id: UUID) async throws

    /// Creates a session directly (for backup restoration)
    @discardableResult
    func createSession(_ session: LocationSession) async throws -> LocationSession

    // MARK: - High-Frequency Entry Operations

    /// Adds location entries in batch
    func addEntries(_ entries: [LocationEntry]) async throws

    /// Fetches entries for a specific session
    func fetchEntries(sessionId: UUID) async throws -> [LocationEntry]

    /// Prunes entries older than the specified date
    func pruneOldEntries(olderThan date: Date) async throws
}
