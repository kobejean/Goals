import Foundation
import GoalsCore

/// Represents a time tracking session at a specific location
public struct LocationSession: Sendable, Equatable, UUIDIdentifiable, Codable {
    public let id: UUID
    public let locationId: UUID
    public let startDate: Date
    public var endDate: Date?
    public var isConfirmed: Bool
    public var updatedAt: Date

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

    /// Whether this session is currently active (no end date)
    public var isActive: Bool {
        endDate == nil
    }

    /// Duration of the session in seconds
    public var duration: TimeInterval {
        let end = endDate ?? Date()
        return end.timeIntervalSince(startDate)
    }

    /// Duration calculated at a specific reference date
    public func duration(at referenceDate: Date) -> TimeInterval {
        let end = endDate ?? referenceDate
        return end.timeIntervalSince(startDate)
    }

    /// Duration formatted as hours and minutes
    public var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Session Collection Helpers

public extension Array where Element == LocationSession {
    /// Total duration of all sessions in seconds
    var totalDuration: TimeInterval {
        reduce(0) { $0 + $1.duration }
    }

    /// Total duration calculated at a specific reference date
    func totalDuration(at referenceDate: Date) -> TimeInterval {
        reduce(0) { $0 + $1.duration(at: referenceDate) }
    }

    /// Total duration formatted as hours and minutes
    var formattedTotalDuration: String {
        let totalSeconds = Int(totalDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Filter sessions for a specific location
    func sessions(for locationId: UUID) -> [LocationSession] {
        filter { $0.locationId == locationId }
    }

    /// Get the currently active session, if any
    var activeSession: LocationSession? {
        first { $0.isActive }
    }
}
