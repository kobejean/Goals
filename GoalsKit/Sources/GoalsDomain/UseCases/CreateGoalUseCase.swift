import Foundation

/// Use case for creating new goals
public struct CreateGoalUseCase: Sendable {
    private let goalRepository: GoalRepositoryProtocol

    public init(goalRepository: GoalRepositoryProtocol) {
        self.goalRepository = goalRepository
    }

    /// Creates a new data source goal with a specific metric
    public func createGoal(
        title: String,
        description: String? = nil,
        dataSource: DataSourceType,
        metricKey: String,
        targetValue: Double,
        unit: String,
        deadline: Date? = nil,
        color: GoalColor = .blue,
        direction: GoalDirection = .increase,
        taskId: UUID? = nil
    ) async throws -> Goal {
        let goal = Goal(
            title: title,
            description: description,
            dataSource: dataSource,
            metricKey: metricKey,
            targetValue: targetValue,
            currentValue: 0,
            unit: unit,
            deadline: deadline,
            color: color,
            direction: direction,
            taskId: taskId
        )
        return try await goalRepository.create(goal)
    }
}
