import Foundation
import GoalsCore

/// Represents a user's goal with tracking capabilities
public struct Goal: Sendable, Equatable, UUIDIdentifiable {
    public let id: UUID
    public var title: String
    public var description: String?
    public var type: GoalType
    public var dataSource: DataSourceType
    public var createdAt: Date
    public var updatedAt: Date

    // Data source metric key (e.g., "wpm", "accuracy", "rating")
    public var metricKey: String?

    // Numeric goal properties
    public var targetValue: Double?
    public var currentValue: Double?
    public var unit: String?

    // Habit goal properties
    public var frequency: HabitFrequency?
    public var targetCount: Int? // e.g., 5 times per week
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
    public var color: GoalColor

    public init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        type: GoalType,
        dataSource: DataSourceType = .manual,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        metricKey: String? = nil,
        targetValue: Double? = nil,
        currentValue: Double? = nil,
        unit: String? = nil,
        frequency: HabitFrequency? = nil,
        targetCount: Int? = nil,
        currentStreak: Int? = nil,
        longestStreak: Int? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        subGoalIds: [UUID]? = nil,
        deadline: Date? = nil,
        isArchived: Bool = false,
        color: GoalColor = .blue
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.dataSource = dataSource
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metricKey = metricKey
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.unit = unit
        self.frequency = frequency
        self.targetCount = targetCount
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.subGoalIds = subGoalIds
        self.deadline = deadline
        self.isArchived = isArchived
        self.color = color
    }

    /// Progress percentage (0.0 to 1.0)
    public var progress: Double {
        switch type {
        case .numeric:
            guard let target = targetValue, target > 0, let current = currentValue else {
                return 0
            }
            return min(current / target, 1.0)

        case .habit:
            guard let target = targetCount, target > 0, let streak = currentStreak else {
                return 0
            }
            return min(Double(streak) / Double(target), 1.0)

        case .milestone:
            return isCompleted ? 1.0 : 0.0

        case .compound:
            // Progress calculated based on sub-goals (handled at repository level)
            return 0
        }
    }

    /// Returns true if the goal has been achieved
    public var isAchieved: Bool {
        switch type {
        case .numeric:
            return progress >= 1.0

        case .habit:
            guard let target = targetCount, let streak = currentStreak else {
                return false
            }
            return streak >= target

        case .milestone:
            return isCompleted

        case .compound:
            // Achieved when all sub-goals are completed (handled at repository level)
            return false
        }
    }
}

/// Available colors for goals
public enum GoalColor: String, Codable, Sendable, CaseIterable {
    case blue
    case green
    case orange
    case purple
    case red
    case pink
    case yellow
    case teal

    public var displayName: String {
        rawValue.capitalized
    }
}
