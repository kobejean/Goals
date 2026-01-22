import Foundation

/// Cached active session data for widget display
public struct CachedActiveSession: Codable, Sendable {
    public let sessionId: UUID
    public let taskId: UUID
    public let taskName: String
    public let taskColorRaw: String
    public let startDate: Date

    public init(
        sessionId: UUID,
        taskId: UUID,
        taskName: String,
        taskColorRaw: String,
        startDate: Date
    ) {
        self.sessionId = sessionId
        self.taskId = taskId
        self.taskName = taskName
        self.taskColorRaw = taskColorRaw
        self.startDate = startDate
    }
}
