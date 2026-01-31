import Foundation
import GoalsDomain

/// Decorator that wraps a LocationRepository and queues changes for CloudKit backup
/// Note: Only syncs definitions and sessions, not high-frequency entries
@MainActor
public final class CloudBackedLocationRepository: LocationRepositoryProtocol {
    private let local: LocationRepositoryProtocol
    private let syncQueue: CloudSyncQueue

    public init(local: LocationRepositoryProtocol, syncQueue: CloudSyncQueue) {
        self.local = local
        self.syncQueue = syncQueue
    }

    // MARK: - Location Definition Read Operations

    public func fetchAllLocations() async throws -> [LocationDefinition] {
        try await local.fetchAllLocations()
    }

    public func fetchActiveLocations() async throws -> [LocationDefinition] {
        try await local.fetchActiveLocations()
    }

    public func fetchLocation(id: UUID) async throws -> LocationDefinition? {
        try await local.fetchLocation(id: id)
    }

    // MARK: - Location Definition Write Operations

    @discardableResult
    public func createLocation(_ location: LocationDefinition) async throws -> LocationDefinition {
        let created = try await local.createLocation(location)
        await syncQueue.enqueueUpsert(created)
        return created
    }

    @discardableResult
    public func updateLocation(_ location: LocationDefinition) async throws -> LocationDefinition {
        let updated = try await local.updateLocation(location)
        await syncQueue.enqueueUpsert(updated)
        return updated
    }

    public func deleteLocation(id: UUID) async throws {
        try await local.deleteLocation(id: id)
        await syncQueue.enqueueDelete(recordType: LocationDefinition.recordType, id: id)
    }

    // MARK: - Session Read Operations

    public func fetchActiveSession() async throws -> LocationSession? {
        try await local.fetchActiveSession()
    }

    public func fetchSessions(for date: Date) async throws -> [LocationSession] {
        try await local.fetchSessions(for: date)
    }

    public func fetchSessions(locationId: UUID, from startDate: Date, to endDate: Date) async throws -> [LocationSession] {
        try await local.fetchSessions(locationId: locationId, from: startDate, to: endDate)
    }

    public func fetchSessions(from startDate: Date, to endDate: Date) async throws -> [LocationSession] {
        try await local.fetchSessions(from: startDate, to: endDate)
    }

    // MARK: - Session Write Operations

    @discardableResult
    public func startSession(locationId: UUID, at date: Date) async throws -> LocationSession {
        let session = try await local.startSession(locationId: locationId, at: date)
        await syncQueue.enqueueUpsert(session)
        return session
    }

    @discardableResult
    public func endSession(id: UUID, at date: Date) async throws -> LocationSession {
        let session = try await local.endSession(id: id, at: date)
        await syncQueue.enqueueUpsert(session)
        return session
    }

    @discardableResult
    public func confirmSession(id: UUID) async throws -> LocationSession {
        let session = try await local.confirmSession(id: id)
        await syncQueue.enqueueUpsert(session)
        return session
    }

    public func deleteSession(id: UUID) async throws {
        try await local.deleteSession(id: id)
        await syncQueue.enqueueDelete(recordType: LocationSession.recordType, id: id)
    }

    @discardableResult
    public func createSession(_ session: LocationSession) async throws -> LocationSession {
        let created = try await local.createSession(session)
        await syncQueue.enqueueUpsert(created)
        return created
    }

    // MARK: - High-Frequency Entry Operations (Not synced to cloud)

    public func addEntries(_ entries: [LocationEntry]) async throws {
        try await local.addEntries(entries)
        // Entries are not synced to cloud - too high frequency
    }

    public func fetchEntries(sessionId: UUID) async throws -> [LocationEntry] {
        try await local.fetchEntries(sessionId: sessionId)
    }

    public func pruneOldEntries(olderThan date: Date) async throws {
        try await local.pruneOldEntries(olderThan: date)
    }

    // MARK: - Path Tracking Operations (Not synced to cloud)

    public func addPathEntries(_ entries: [PathEntry]) async throws {
        try await local.addPathEntries(entries)
        // Path entries are not synced to cloud - local only
    }

    public func fetchPathEntries(for date: Date) async throws -> [PathEntry] {
        try await local.fetchPathEntries(for: date)
    }

    public func fetchPathEntries(from startDate: Date, to endDate: Date) async throws -> [PathEntry] {
        try await local.fetchPathEntries(from: startDate, to: endDate)
    }

    public func pruneOldPathEntries(olderThan date: Date) async throws {
        try await local.pruneOldPathEntries(olderThan: date)
    }
}
