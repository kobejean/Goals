import Foundation

/// A single session with embedded task info for caching
/// Contains all task metadata needed for widget display without requiring TaskDefinition access
public struct CachedTaskSession: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let sessionId: UUID
    public let taskId: UUID
    public let taskName: String
    public let taskColorRaw: String  // TaskColor.rawValue
    public let startDate: Date
    public let endDate: Date?  // nil for active sessions

    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        taskId: UUID,
        taskName: String,
        taskColorRaw: String,
        startDate: Date,
        endDate: Date?
    ) {
        self.id = id
        self.sessionId = sessionId
        self.taskId = taskId
        self.taskName = taskName
        self.taskColorRaw = taskColorRaw
        self.startDate = startDate
        self.endDate = endDate
    }

    /// Create from a TaskSession and TaskDefinition
    public init(session: TaskSession, task: TaskDefinition) {
        self.id = UUID()
        self.sessionId = session.id
        self.taskId = task.id
        self.taskName = task.name
        self.taskColorRaw = task.color.rawValue
        self.startDate = session.startDate
        self.endDate = session.endDate
    }

    /// Duration of the session in seconds
    public var duration: TimeInterval {
        let end = endDate ?? Date()
        return end.timeIntervalSince(startDate)
    }

    /// Duration at a specific reference date (for live updates)
    public func duration(at referenceDate: Date) -> TimeInterval {
        let end = endDate ?? referenceDate
        return end.timeIntervalSince(startDate)
    }

    /// Whether this session is currently active (no end date)
    public var isActive: Bool {
        endDate == nil
    }

    /// The task color parsed from raw value
    public var taskColor: TaskColor {
        TaskColor(rawValue: taskColorRaw) ?? .orange
    }
}

/// Daily summary of task sessions (cacheable for widget access)
public struct TaskDailySummary: Codable, Sendable, Equatable, Identifiable {
    public var id: Date { date }
    public let date: Date
    public let sessions: [CachedTaskSession]

    public init(date: Date, sessions: [CachedTaskSession]) {
        self.date = date
        self.sessions = sessions
    }

    /// Create from sessions and tasks (converts to cached format)
    public init(date: Date, sessions: [TaskSession], tasks: [TaskDefinition]) {
        self.date = date
        self.sessions = sessions.compactMap { session in
            guard let task = tasks.first(where: { $0.id == session.taskId }) else { return nil }
            return CachedTaskSession(session: session, task: task)
        }
    }

    /// Total tracked duration for the day in seconds
    public var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }

    /// Total tracked duration at a specific reference date (for live updates)
    public func totalDuration(at referenceDate: Date) -> TimeInterval {
        sessions.reduce(0) { $0 + $1.duration(at: referenceDate) }
    }

    /// Sessions grouped by task ID
    public var sessionsByTask: [UUID: [CachedTaskSession]] {
        Dictionary(grouping: sessions) { $0.taskId }
    }
}

// MARK: - CachedTaskSession Collection Helpers

public extension Array where Element == CachedTaskSession {
    /// Total duration of all sessions in seconds
    var totalDuration: TimeInterval {
        reduce(0) { $0 + $1.duration }
    }

    /// Total duration at a specific reference date (for live updates)
    func totalDuration(at referenceDate: Date) -> TimeInterval {
        reduce(0) { $0 + $1.duration(at: referenceDate) }
    }
}

// MARK: - CacheableRecord Conformance

extension TaskDailySummary: CacheableRecord {
    public static var dataSource: DataSourceType { .tasks }
    public static var recordType: String { "daily" }

    /// Shared date formatter for cache key generation (thread-safe)
    private static let cacheKeyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    public var cacheKey: String {
        "tasks:daily:\(Self.cacheKeyDateFormatter.string(from: date))"
    }

    public var recordDate: Date { date }
}
