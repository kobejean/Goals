import Foundation
import GoalsCore

/// Represents a time tracking entry for a task
public struct TaskSession: Sendable, Equatable, UUIDIdentifiable, Codable {
    public let id: UUID
    public let taskId: UUID
    public let startDate: Date
    public var endDate: Date?
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        taskId: UUID,
        startDate: Date = Date(),
        endDate: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.taskId = taskId
        self.startDate = startDate
        self.endDate = endDate
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

public extension Array where Element == TaskSession {
    /// Total duration of all sessions in seconds
    var totalDuration: TimeInterval {
        reduce(0) { $0 + $1.duration }
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

    /// Filter sessions for a specific task
    func sessions(for taskId: UUID) -> [TaskSession] {
        filter { $0.taskId == taskId }
    }

    /// Get the currently active session, if any
    var activeSession: TaskSession? {
        first { $0.isActive }
    }
}
