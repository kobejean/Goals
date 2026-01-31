import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for persisting Goal entities
@Model
public final class GoalModel {
    public var id: UUID = UUID()
    public var title: String = ""
    public var goalDescription: String?
    public var dataSourceRawValue: String = ""
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    // Data source metric key
    public var metricKey: String = ""

    // Target and current values
    public var targetValue: Double = 0
    public var currentValue: Double = 0
    public var unit: String = ""

    // Common properties
    public var deadline: Date?
    public var isArchived: Bool = false
    public var colorRawValue: String = "blue"

    /// Direction for progress tracking (increase or decrease toward target)
    public var directionRawValue: String = "increase"

    // Per-task tracking (for .tasks data source)
    public var taskId: UUID?

    public init(
        id: UUID = UUID(),
        title: String,
        goalDescription: String? = nil,
        dataSourceRawValue: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        metricKey: String,
        targetValue: Double,
        currentValue: Double = 0,
        unit: String,
        deadline: Date? = nil,
        isArchived: Bool = false,
        colorRawValue: String = "blue",
        directionRawValue: String = "increase",
        taskId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.goalDescription = goalDescription
        self.dataSourceRawValue = dataSourceRawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metricKey = metricKey
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.unit = unit
        self.deadline = deadline
        self.isArchived = isArchived
        self.colorRawValue = colorRawValue
        self.directionRawValue = directionRawValue
        self.taskId = taskId
    }
}

// MARK: - Domain Conversion

public extension GoalModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> Goal {
        Goal(
            id: id,
            title: title,
            description: goalDescription,
            dataSource: DataSourceType(rawValue: dataSourceRawValue) ?? .typeQuicker,
            createdAt: createdAt,
            updatedAt: updatedAt,
            metricKey: metricKey,
            targetValue: targetValue,
            currentValue: currentValue,
            unit: unit,
            deadline: deadline,
            isArchived: isArchived,
            color: GoalColor(rawValue: colorRawValue) ?? .blue,
            direction: GoalDirection(rawValue: directionRawValue) ?? .increase,
            taskId: taskId
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ goal: Goal) -> GoalModel {
        GoalModel(
            id: goal.id,
            title: goal.title,
            goalDescription: goal.description,
            dataSourceRawValue: goal.dataSource.rawValue,
            createdAt: goal.createdAt,
            updatedAt: goal.updatedAt,
            metricKey: goal.metricKey,
            targetValue: goal.targetValue,
            currentValue: goal.currentValue,
            unit: goal.unit,
            deadline: goal.deadline,
            isArchived: goal.isArchived,
            colorRawValue: goal.color.rawValue,
            directionRawValue: goal.direction.rawValue,
            taskId: goal.taskId
        )
    }

    /// Updates model from domain entity
    func update(from goal: Goal) {
        title = goal.title
        goalDescription = goal.description
        dataSourceRawValue = goal.dataSource.rawValue
        updatedAt = Date()
        metricKey = goal.metricKey
        targetValue = goal.targetValue
        currentValue = goal.currentValue
        unit = goal.unit
        deadline = goal.deadline
        isArchived = goal.isArchived
        colorRawValue = goal.color.rawValue
        directionRawValue = goal.direction.rawValue
        taskId = goal.taskId
    }
}
