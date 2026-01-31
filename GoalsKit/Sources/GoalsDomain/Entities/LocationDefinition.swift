import Foundation
import GoalsCore

/// Represents a user-configured location for automatic time tracking
public struct LocationDefinition: Sendable, Equatable, UUIDIdentifiable, Codable {
    public let id: UUID
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var radiusMeters: Double
    public var color: LocationColor
    public var icon: String
    public var isArchived: Bool
    public let createdAt: Date
    public var updatedAt: Date
    public var sortOrder: Int

    public init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 100,
        color: LocationColor = .blue,
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
        self.color = color
        self.icon = icon
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
    }
}

/// Available colors for locations (matches TaskColor for consistency)
public enum LocationColor: String, Codable, Sendable, CaseIterable {
    case blue
    case green
    case orange
    case purple
    case red
    case pink
    case yellow
    case teal

    public var displayName: String {
        rawValue.capitalized
    }
}
