import Foundation

/// Use case for creating new goals
public struct CreateGoalUseCase: Sendable {
    private let goalRepository: GoalRepositoryProtocol

    public init(goalRepository: GoalRepositoryProtocol) {
        self.goalRepository = goalRepository
    }

    /// Creates a new numeric goal
    public func createNumericGoal(
        title: String,
        description: String? = nil,
        targetValue: Double,
        unit: String,
        dataSource: DataSourceType = .manual,
        deadline: Date? = nil,
        color: GoalColor = .blue
    ) async throws -> Goal {
        let goal = Goal(
            title: title,
            description: description,
            type: .numeric,
            dataSource: dataSource,
            targetValue: targetValue,
            currentValue: 0,
            unit: unit,
            deadline: deadline,
            color: color
        )
        return try await goalRepository.create(goal)
    }

    /// Creates a new habit goal
    public func createHabitGoal(
        title: String,
        description: String? = nil,
        frequency: HabitFrequency,
        targetCount: Int,
        dataSource: DataSourceType = .manual,
        color: GoalColor = .green
    ) async throws -> Goal {
        let goal = Goal(
            title: title,
            description: description,
            type: .habit,
            dataSource: dataSource,
            frequency: frequency,
            targetCount: targetCount,
            currentStreak: 0,
            longestStreak: 0,
            color: color
        )
        return try await goalRepository.create(goal)
    }

    /// Creates a new milestone goal
    public func createMilestoneGoal(
        title: String,
        description: String? = nil,
        dataSource: DataSourceType = .manual,
        deadline: Date? = nil,
        color: GoalColor = .purple
    ) async throws -> Goal {
        let goal = Goal(
            title: title,
            description: description,
            type: .milestone,
            dataSource: dataSource,
            deadline: deadline,
            color: color
        )
        return try await goalRepository.create(goal)
    }

    /// Creates a new compound goal with sub-goals
    public func createCompoundGoal(
        title: String,
        description: String? = nil,
        subGoalIds: [UUID],
        deadline: Date? = nil,
        color: GoalColor = .orange
    ) async throws -> Goal {
        let goal = Goal(
            title: title,
            description: description,
            type: .compound,
            dataSource: .manual,
            subGoalIds: subGoalIds,
            deadline: deadline,
            color: color
        )
        return try await goalRepository.create(goal)
    }
}
