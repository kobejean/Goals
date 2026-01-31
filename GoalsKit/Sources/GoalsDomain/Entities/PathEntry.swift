import Foundation

/// Represents a single point in the user's daily path
/// These are collected throughout the day, independent of location sessions
public struct PathEntry: Identifiable, Sendable, Codable, Hashable {
    public let id: UUID
    public let timestamp: Date
    public let latitude: Double
    public let longitude: Double
    public let horizontalAccuracy: Double
    public let altitude: Double?
    public let speed: Double?
    public let course: Double?

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
}

// MARK: - Array Extensions

extension Array where Element == PathEntry {
    /// Get entries for a specific date
    public func entries(for date: Date) -> [PathEntry] {
        let calendar = Calendar.current
        return filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
    }

    /// Get entries sorted by timestamp
    public var sortedByTime: [PathEntry] {
        sorted { $0.timestamp < $1.timestamp }
    }
}
