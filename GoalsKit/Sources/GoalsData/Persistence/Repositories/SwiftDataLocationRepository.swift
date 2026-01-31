import Foundation
import SwiftData
import GoalsDomain

/// SwiftData implementation of LocationRepositoryProtocol
@MainActor
public final class SwiftDataLocationRepository: LocationRepositoryProtocol {
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Location Definition Operations

    public func fetchAllLocations() async throws -> [LocationDefinition] {
        let descriptor = FetchDescriptor<LocationDefinitionModel>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetchActiveLocations() async throws -> [LocationDefinition] {
        let descriptor = FetchDescriptor<LocationDefinitionModel>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetchLocation(id: UUID) async throws -> LocationDefinition? {
        let descriptor = FetchDescriptor<LocationDefinitionModel>(
            predicate: #Predicate { $0.id == id }
        )
        let models = try modelContext.fetch(descriptor)
        return models.first?.toDomain()
    }

    @discardableResult
    public func createLocation(_ location: LocationDefinition) async throws -> LocationDefinition {
        let model = LocationDefinitionModel.from(location)
        modelContext.insert(model)
        try modelContext.save()
        return model.toDomain()
    }

    @discardableResult
    public func updateLocation(_ location: LocationDefinition) async throws -> LocationDefinition {
        let locationId = location.id
        let descriptor = FetchDescriptor<LocationDefinitionModel>(
            predicate: #Predicate { $0.id == locationId }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        model.update(from: location)
        try modelContext.save()
        return model.toDomain()
    }

    public func deleteLocation(id: UUID) async throws {
        let descriptor = FetchDescriptor<LocationDefinitionModel>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    // MARK: - Session Operations

    public func fetchActiveSession() async throws -> LocationSession? {
        let descriptor = FetchDescriptor<LocationSessionModel>(
            predicate: #Predicate { $0.endDate == nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.first?.toDomain()
    }

    public func fetchSessions(for date: Date) async throws -> [LocationSession] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        let descriptor = FetchDescriptor<LocationSessionModel>(
            predicate: #Predicate { session in
                session.startDate >= startOfDay && session.startDate < endOfDay
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetchSessions(locationId: UUID, from startDate: Date, to endDate: Date) async throws -> [LocationSession] {
        let descriptor = FetchDescriptor<LocationSessionModel>(
            predicate: #Predicate { session in
                session.locationId == locationId &&
                session.startDate >= startDate &&
                session.startDate <= endDate
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetchSessions(from startDate: Date, to endDate: Date) async throws -> [LocationSession] {
        let descriptor = FetchDescriptor<LocationSessionModel>(
            predicate: #Predicate { session in
                session.startDate >= startDate && session.startDate <= endDate
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    @discardableResult
    public func startSession(locationId: UUID, at date: Date) async throws -> LocationSession {
        // First, stop any active sessions
        let activeDescriptor = FetchDescriptor<LocationSessionModel>(
            predicate: #Predicate { $0.endDate == nil }
        )
        let activeSessions = try modelContext.fetch(activeDescriptor)
        for session in activeSessions {
            session.endDate = date
        }

        // Create new session
        let newSession = LocationSession(locationId: locationId, startDate: date)
        let model = LocationSessionModel.from(newSession)

        // Link to location
        let locationDescriptor = FetchDescriptor<LocationDefinitionModel>(
            predicate: #Predicate { $0.id == locationId }
        )
        if let locationModel = try modelContext.fetch(locationDescriptor).first {
            model.location = locationModel
        }

        modelContext.insert(model)
        try modelContext.save()
        return model.toDomain()
    }

    @discardableResult
    public func endSession(id: UUID, at date: Date) async throws -> LocationSession {
        let descriptor = FetchDescriptor<LocationSessionModel>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        model.endDate = date
        model.updatedAt = Date()
        try modelContext.save()
        return model.toDomain()
    }

    @discardableResult
    public func confirmSession(id: UUID) async throws -> LocationSession {
        let descriptor = FetchDescriptor<LocationSessionModel>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        model.isConfirmed = true
        model.updatedAt = Date()
        try modelContext.save()
        return model.toDomain()
    }

    public func deleteSession(id: UUID) async throws {
        let descriptor = FetchDescriptor<LocationSessionModel>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    @discardableResult
    public func createSession(_ session: LocationSession) async throws -> LocationSession {
        let model = LocationSessionModel.from(session)

        // Link to location if it exists
        let locationId = session.locationId
        let locationDescriptor = FetchDescriptor<LocationDefinitionModel>(
            predicate: #Predicate { $0.id == locationId }
        )
        if let locationModel = try modelContext.fetch(locationDescriptor).first {
            model.location = locationModel
        }

        modelContext.insert(model)
        try modelContext.save()
        return model.toDomain()
    }

    // MARK: - High-Frequency Entry Operations

    public func addEntries(_ entries: [LocationEntry]) async throws {
        for entry in entries {
            let model = LocationEntryModel.from(entry)

            // Link to session if it exists
            let sessionId = entry.sessionId
            let sessionDescriptor = FetchDescriptor<LocationSessionModel>(
                predicate: #Predicate { $0.id == sessionId }
            )
            if let sessionModel = try modelContext.fetch(sessionDescriptor).first {
                model.session = sessionModel
            }

            modelContext.insert(model)
        }
        try modelContext.save()
    }

    public func fetchEntries(sessionId: UUID) async throws -> [LocationEntry] {
        let descriptor = FetchDescriptor<LocationEntryModel>(
            predicate: #Predicate { $0.sessionId == sessionId },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func pruneOldEntries(olderThan date: Date) async throws {
        let descriptor = FetchDescriptor<LocationEntryModel>(
            predicate: #Predicate { $0.timestamp < date }
        )
        let oldEntries = try modelContext.fetch(descriptor)
        for entry in oldEntries {
            modelContext.delete(entry)
        }
        try modelContext.save()
    }

    // MARK: - Hashable & Equatable

    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    nonisolated public static func == (lhs: SwiftDataLocationRepository, rhs: SwiftDataLocationRepository) -> Bool {
        lhs === rhs
    }
}
