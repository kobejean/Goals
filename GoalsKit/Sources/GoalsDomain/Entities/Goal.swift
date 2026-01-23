import Foundation
import GoalsCore

/// Represents a user's goal linked to a data source metric
public struct Goal: Sendable, Equatable, UUIDIdentifiable, Codable {
    public let id: UUID
    public var title: String
    public var description: String?
    public var dataSource: DataSourceType
    public var createdAt: Date
    public var updatedAt: Date

    // Data source metric key (e.g., "wpm", "accuracy", "rating")
    public var metricKey: String

    // Target and current values
    public var targetValue: Double
    public var currentValue: Double
    public var unit: String

    // Common properties
    public var deadline: Date?
    public var isArchived: Bool
    public var color: GoalColor

    // Per-task tracking (for .tasks data source)
    public var taskId: UUID?

    public init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        dataSource: DataSourceType,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        metricKey: String,
        targetValue: Double,
        currentValue: Double = 0,
        unit: String,
        deadline: Date? = nil,
        isArchived: Bool = false,
        color: GoalColor = .blue,
        taskId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.dataSource = dataSource
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metricKey = metricKey
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.unit = unit
        self.deadline = deadline
        self.isArchived = isArchived
        self.color = color
        self.taskId = taskId
    }

    /// Progress percentage (0.0 to 1.0)
    public var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(currentValue / targetValue, 1.0)
    }

    /// Returns true if the goal has been achieved
    public var isAchieved: Bool {
        progress >= 1.0
    }
}

// MARK: - Goal Collection Helpers

public extension Array where Element == Goal {
    /// Find active (non-archived) goal for a metric key
    func activeGoal(for metricKey: String) -> Goal? {
        first { $0.metricKey == metricKey && !$0.isArchived }
    }

    /// Get target value for an active goal with the given metric key
    func targetValue(for metricKey: String) -> Double? {
        activeGoal(for: metricKey)?.targetValue
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
