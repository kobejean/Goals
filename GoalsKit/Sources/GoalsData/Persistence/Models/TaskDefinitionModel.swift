import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for persisting TaskDefinition entities
@Model
public final class TaskDefinitionModel {
    public var id: UUID = UUID()
    public var name: String = ""
    public var colorRawValue: String = "blue"
    public var icon: String = "checkmark.circle"
    public var isArchived: Bool = false
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var sortOrder: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \TaskSessionModel.task)
    public var sessions: [TaskSessionModel] = []

    public init(
        id: UUID = UUID(),
        name: String,
        colorRawValue: String = "blue",
        icon: String = "checkmark.circle",
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorRawValue = colorRawValue
        self.icon = icon
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
    }
}

// MARK: - Domain Conversion

public extension TaskDefinitionModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> TaskDefinition {
        TaskDefinition(
            id: id,
            name: name,
            color: TaskColor(rawValue: colorRawValue) ?? .blue,
            icon: icon,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sortOrder: sortOrder
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ task: TaskDefinition) -> TaskDefinitionModel {
        TaskDefinitionModel(
            id: task.id,
            name: task.name,
            colorRawValue: task.color.rawValue,
            icon: task.icon,
            isArchived: task.isArchived,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            sortOrder: task.sortOrder
        )
    }

    /// Updates model from domain entity
    func update(from task: TaskDefinition) {
        name = task.name
        colorRawValue = task.color.rawValue
        icon = task.icon
        isArchived = task.isArchived
        updatedAt = Date()
        sortOrder = task.sortOrder
    }
}
