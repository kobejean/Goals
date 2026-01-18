import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for persisting Goal entities
@Model
public final class GoalModel {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var goalDescription: String?
    public var typeRawValue: String
    public var dataSourceRawValue: String
    public var createdAt: Date
    public var updatedAt: Date

    // Numeric goal properties
    public var targetValue: Double?
    public var currentValue: Double?
    public var unit: String?

    // Habit goal properties
    public var frequencyRawValue: String?
    public var targetCount: Int?
    public var currentStreak: Int?
    public var longestStreak: Int?

    // Milestone goal properties
    public var isCompleted: Bool
    public var completedAt: Date?

    // Compound goal properties
    public var subGoalIds: [UUID]?

    // Common properties
    public var deadline: Date?
    public var isArchived: Bool
    public var colorRawValue: String

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \DataPointModel.goal)
    public var dataPoints: [DataPointModel]?

    public init(
        id: UUID = UUID(),
        title: String,
        goalDescription: String? = nil,
        typeRawValue: String,
        dataSourceRawValue: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        targetValue: Double? = nil,
        currentValue: Double? = nil,
        unit: String? = nil,
        frequencyRawValue: String? = nil,
        targetCount: Int? = nil,
        currentStreak: Int? = nil,
        longestStreak: Int? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        subGoalIds: [UUID]? = nil,
        deadline: Date? = nil,
        isArchived: Bool = false,
        colorRawValue: String = "blue"
    ) {
        self.id = id
        self.title = title
        self.goalDescription = goalDescription
        self.typeRawValue = typeRawValue
        self.dataSourceRawValue = dataSourceRawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.unit = unit
        self.frequencyRawValue = frequencyRawValue
        self.targetCount = targetCount
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.subGoalIds = subGoalIds
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
            type: GoalType(rawValue: typeRawValue) ?? .numeric,
            dataSource: DataSourceType(rawValue: dataSourceRawValue) ?? .manual,
            createdAt: createdAt,
            updatedAt: updatedAt,
            targetValue: targetValue,
            currentValue: currentValue,
            unit: unit,
            frequency: frequencyRawValue.flatMap { HabitFrequency(rawValue: $0) },
            targetCount: targetCount,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            isCompleted: isCompleted,
            completedAt: completedAt,
            subGoalIds: subGoalIds,
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
            typeRawValue: goal.type.rawValue,
            dataSourceRawValue: goal.dataSource.rawValue,
            createdAt: goal.createdAt,
            updatedAt: goal.updatedAt,
            targetValue: goal.targetValue,
            currentValue: goal.currentValue,
            unit: goal.unit,
            frequencyRawValue: goal.frequency?.rawValue,
            targetCount: goal.targetCount,
            currentStreak: goal.currentStreak,
            longestStreak: goal.longestStreak,
            isCompleted: goal.isCompleted,
            completedAt: goal.completedAt,
            subGoalIds: goal.subGoalIds,
            deadline: goal.deadline,
            isArchived: goal.isArchived,
            colorRawValue: goal.color.rawValue
        )
    }

    /// Updates model from domain entity
    func update(from goal: Goal) {
        title = goal.title
        goalDescription = goal.description
        typeRawValue = goal.type.rawValue
        dataSourceRawValue = goal.dataSource.rawValue
        updatedAt = Date()
        targetValue = goal.targetValue
        currentValue = goal.currentValue
        unit = goal.unit
        frequencyRawValue = goal.frequency?.rawValue
        targetCount = goal.targetCount
        currentStreak = goal.currentStreak
        longestStreak = goal.longestStreak
        isCompleted = goal.isCompleted
        completedAt = goal.completedAt
        subGoalIds = goal.subGoalIds
        deadline = goal.deadline
        isArchived = goal.isArchived
        colorRawValue = goal.color.rawValue
    }
}
