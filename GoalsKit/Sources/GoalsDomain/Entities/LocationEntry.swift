import Foundation
import GoalsCore

/// Represents a high-frequency location data point recorded during a session
public struct LocationEntry: Sendable, Equatable, UUIDIdentifiable, Codable {
    public let id: UUID
    public let sessionId: UUID
    public let timestamp: Date
    public let latitude: Double
    public let longitude: Double
    public let horizontalAccuracy: Double
    public let altitude: Double?
    public let verticalAccuracy: Double?
    public let speed: Double?
    public let course: Double?

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
