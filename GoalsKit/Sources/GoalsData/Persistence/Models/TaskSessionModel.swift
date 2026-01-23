import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for persisting TaskSession entities
@Model
public final class TaskSessionModel {
    public var id: UUID = UUID()
    public var taskId: UUID = UUID()
    public var startDate: Date = Date()
    public var endDate: Date?
    public var updatedAt: Date = Date()

    public var task: TaskDefinitionModel?

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
}

// MARK: - Domain Conversion

public extension TaskSessionModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> TaskSession {
        TaskSession(
            id: id,
            taskId: taskId,
            startDate: startDate,
            endDate: endDate,
            updatedAt: updatedAt
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ session: TaskSession) -> TaskSessionModel {
        TaskSessionModel(
            id: session.id,
            taskId: session.taskId,
            startDate: session.startDate,
            endDate: session.endDate,
            updatedAt: session.updatedAt
        )
    }

    /// Updates model from domain entity
    func update(from session: TaskSession) {
        taskId = session.taskId
        startDate = session.startDate
        endDate = session.endDate
        updatedAt = Date()
    }
}
