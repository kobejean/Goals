import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for persisting LocationSession entities
@Model
public final class LocationSessionModel {
    public var id: UUID = UUID()
    public var locationId: UUID = UUID()
    public var startDate: Date = Date()
    public var endDate: Date?
    public var isConfirmed: Bool = true
    public var updatedAt: Date = Date()

    public var location: LocationDefinitionModel?

    @Relationship(deleteRule: .cascade, inverse: \LocationEntryModel.session)
    public var entries: [LocationEntryModel] = []

    public init(
        id: UUID = UUID(),
        locationId: UUID,
        startDate: Date = Date(),
        endDate: Date? = nil,
        isConfirmed: Bool = true,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.locationId = locationId
        self.startDate = startDate
        self.endDate = endDate
        self.isConfirmed = isConfirmed
        self.updatedAt = updatedAt
    }
}

// MARK: - Domain Conversion

public extension LocationSessionModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> LocationSession {
        LocationSession(
            id: id,
            locationId: locationId,
            startDate: startDate,
            endDate: endDate,
            isConfirmed: isConfirmed,
            updatedAt: updatedAt
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ session: LocationSession) -> LocationSessionModel {
        LocationSessionModel(
            id: session.id,
            locationId: session.locationId,
            startDate: session.startDate,
            endDate: session.endDate,
            isConfirmed: session.isConfirmed,
            updatedAt: session.updatedAt
        )
    }

    /// Updates model from domain entity
    func update(from session: LocationSession) {
        locationId = session.locationId
        startDate = session.startDate
        endDate = session.endDate
        isConfirmed = session.isConfirmed
        updatedAt = Date()
    }
}
