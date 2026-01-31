import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for persisting LocationDefinition entities
@Model
public final class LocationDefinitionModel {
    public var id: UUID = UUID()
    public var name: String = ""
    public var latitude: Double = 0
    public var longitude: Double = 0
    public var radiusMeters: Double = 100
    public var colorRawValue: String = "blue"
    public var icon: String = "mappin.circle.fill"
    public var isArchived: Bool = false
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var sortOrder: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \LocationSessionModel.location)
    public var sessions: [LocationSessionModel] = []

    public init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 100,
        colorRawValue: String = "blue",
        icon: String = "mappin.circle.fill",
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.colorRawValue = colorRawValue
        self.icon = icon
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
    }
}

// MARK: - Domain Conversion

public extension LocationDefinitionModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> LocationDefinition {
        LocationDefinition(
            id: id,
            name: name,
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters,
            color: LocationColor(rawValue: colorRawValue) ?? .blue,
            icon: icon,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sortOrder: sortOrder
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ location: LocationDefinition) -> LocationDefinitionModel {
        LocationDefinitionModel(
            id: location.id,
            name: location.name,
            latitude: location.latitude,
            longitude: location.longitude,
            radiusMeters: location.radiusMeters,
            colorRawValue: location.color.rawValue,
            icon: location.icon,
            isArchived: location.isArchived,
            createdAt: location.createdAt,
            updatedAt: location.updatedAt,
            sortOrder: location.sortOrder
        )
    }

    /// Updates model from domain entity
    func update(from location: LocationDefinition) {
        name = location.name
        latitude = location.latitude
        longitude = location.longitude
        radiusMeters = location.radiusMeters
        colorRawValue = location.color.rawValue
        icon = location.icon
        isArchived = location.isArchived
        updatedAt = Date()
        sortOrder = location.sortOrder
    }
}
