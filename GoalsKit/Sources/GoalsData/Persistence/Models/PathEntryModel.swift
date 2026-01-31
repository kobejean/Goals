import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for storing path entries
@Model
public final class PathEntryModel {
    public var id: UUID = UUID()
    public var timestamp: Date = Date()
    public var latitude: Double = 0
    public var longitude: Double = 0
    public var horizontalAccuracy: Double = 0
    public var altitude: Double?
    public var speed: Double?
    public var course: Double?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double,
        altitude: Double? = nil,
        speed: Double? = nil,
        course: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.altitude = altitude
        self.speed = speed
        self.course = course
    }

    // MARK: - Domain Conversion

    public func toDomain() -> PathEntry {
        PathEntry(
            id: id,
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracy: horizontalAccuracy,
            altitude: altitude,
            speed: speed,
            course: course
        )
    }

    public static func from(_ entry: PathEntry) -> PathEntryModel {
        PathEntryModel(
            id: entry.id,
            timestamp: entry.timestamp,
            latitude: entry.latitude,
            longitude: entry.longitude,
            horizontalAccuracy: entry.horizontalAccuracy,
            altitude: entry.altitude,
            speed: entry.speed,
            course: entry.course
        )
    }
}
