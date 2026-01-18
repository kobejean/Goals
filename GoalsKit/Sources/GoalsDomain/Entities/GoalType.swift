import Foundation

/// Represents the different types of goals users can create
public enum GoalType: String, Codable, Sendable, CaseIterable {
    /// Track progress towards a target number (e.g., "Save $10,000", "Type at 100 WPM")
    case numeric

    /// Daily/weekly streaks and habits (e.g., "Exercise 5x/week", "Practice typing daily")
    case habit

    /// Binary achievements (e.g., "Complete marathon", "Reach AtCoder rating 1600")
    case milestone

    /// Multiple sub-goals combined (e.g., "Improve coding skills" with sub-goals)
    case compound

    /// Display name for the goal type
    public var displayName: String {
        switch self {
        case .numeric:
            return "Numeric"
        case .habit:
            return "Habit"
        case .milestone:
            return "Milestone"
        case .compound:
            return "Compound"
        }
    }

    /// SF Symbol name for the goal type icon
    public var iconName: String {
        switch self {
        case .numeric:
            return "number.circle"
        case .habit:
            return "repeat.circle"
        case .milestone:
            return "flag.circle"
        case .compound:
            return "square.stack.3d.up"
        }
    }

    /// Description of the goal type
    public var description: String {
        switch self {
        case .numeric:
            return "Track progress towards a specific number"
        case .habit:
            return "Build consistent habits with streaks"
        case .milestone:
            return "Achieve a one-time goal"
        case .compound:
            return "Combine multiple sub-goals"
        }
    }
}

/// Frequency for habit goals
public enum HabitFrequency: String, Codable, Sendable, CaseIterable {
    case daily
    case weekly
    case monthly

    public var displayName: String {
        switch self {
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        }
    }
}
