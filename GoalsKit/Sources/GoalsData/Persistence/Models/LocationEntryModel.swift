import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for persisting high-frequency LocationEntry records
@Model
public final class LocationEntryModel {
    public var id: UUID = UUID()
    public var sessionId: UUID = UUID()
    public var timestamp: Date = Date()
    public var latitude: Double = 0
    public var longitude: Double = 0
    public var horizontalAccuracy: Double = 0
    public var altitude: Double?
    public var verticalAccuracy: Double?
    public var speed: Double?
    public var course: Double?

    public var session: LocationSessionModel?

    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        timestamp: Date = Date(),
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double,
        altitude: Double? = nil,
        verticalAccuracy: Double? = nil,
        speed: Double? = nil,
        course: Double? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.altitude = altitude
        self.verticalAccuracy = verticalAccuracy
        self.speed = speed
        self.course = course
    }
}

// MARK: - Domain Conversion

public extension LocationEntryModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> LocationEntry {
        LocationEntry(
            id: id,
            sessionId: sessionId,
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracy: horizontalAccuracy,
            altitude: altitude,
            verticalAccuracy: verticalAccuracy,
            speed: speed,
            course: course
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ entry: LocationEntry) -> LocationEntryModel {
        LocationEntryModel(
            id: entry.id,
            sessionId: entry.sessionId,
            timestamp: entry.timestamp,
            latitude: entry.latitude,
            longitude: entry.longitude,
            horizontalAccuracy: entry.horizontalAccuracy,
            altitude: entry.altitude,
            verticalAccuracy: entry.verticalAccuracy,
            speed: entry.speed,
            course: entry.course
        )
    }
}
