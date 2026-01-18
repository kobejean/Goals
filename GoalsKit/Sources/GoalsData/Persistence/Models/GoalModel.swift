import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for persisting Goal entities
@Model
public final class GoalModel {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var goalDescription: String?
    public var dataSourceRawValue: String
    public var createdAt: Date
    public var updatedAt: Date

    // Data source metric key
    public var metricKey: String

    // Target and current values
    public var targetValue: Double
    public var currentValue: Double
    public var unit: String

    // Common properties
    public var deadline: Date?
    public var isArchived: Bool
    public var colorRawValue: String

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
        colorRawValue: String = "blue"
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
            color: GoalColor(rawValue: colorRawValue) ?? .blue
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
            colorRawValue: goal.color.rawValue
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
    }
}
