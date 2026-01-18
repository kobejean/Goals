import Foundation

/// Use case for tracking goal progress
public struct TrackProgressUseCase: Sendable {
    private let goalRepository: GoalRepositoryProtocol
    private let dataPointRepository: DataPointRepositoryProtocol

    public init(
        goalRepository: GoalRepositoryProtocol,
        dataPointRepository: DataPointRepositoryProtocol
    ) {
        self.goalRepository = goalRepository
        self.dataPointRepository = dataPointRepository
    }

    /// Records progress for a numeric goal
    public func recordNumericProgress(
        goalId: UUID,
        value: Double,
        note: String? = nil
    ) async throws {
        // Create data point
        let dataPoint = DataPoint(
            goalId: goalId,
            value: value,
            source: .manual,
            note: note
        )
        try await dataPointRepository.create(dataPoint)

        // Update goal's current value
        try await goalRepository.updateProgress(goalId: goalId, currentValue: value)
    }

    /// Records incremental progress for a numeric goal
    public func recordIncrementalProgress(
        goalId: UUID,
        increment: Double,
        note: String? = nil
    ) async throws {
        guard let goal = try await goalRepository.fetch(id: goalId) else {
            throw TrackProgressError.goalNotFound
        }

        let newValue = (goal.currentValue ?? 0) + increment

        let dataPoint = DataPoint(
            goalId: goalId,
            value: increment,
            source: .manual,
            note: note
        )
        try await dataPointRepository.create(dataPoint)

        try await goalRepository.updateProgress(goalId: goalId, currentValue: newValue)
    }

    /// Checks in for a habit goal (increments streak)
    public func checkInHabit(goalId: UUID, note: String? = nil) async throws {
        let dataPoint = DataPoint(
            goalId: goalId,
            value: 1,
            source: .manual,
            note: note
        )
        try await dataPointRepository.create(dataPoint)
        try await goalRepository.incrementStreak(goalId: goalId)
    }

    /// Resets the streak for a habit goal (missed day)
    public func resetHabitStreak(goalId: UUID) async throws {
        try await goalRepository.resetStreak(goalId: goalId)
    }

    /// Marks a milestone goal as completed
    public func completeMilestone(goalId: UUID, note: String? = nil) async throws {
        let dataPoint = DataPoint(
            goalId: goalId,
            value: 1,
            source: .manual,
            note: note
        )
        try await dataPointRepository.create(dataPoint)
        try await goalRepository.markCompleted(goalId: goalId)
    }

    /// Marks a milestone goal as incomplete
    public func uncompleteMilestone(goalId: UUID) async throws {
        try await goalRepository.markIncomplete(goalId: goalId)
    }

    /// Gets progress history for a goal
    public func getProgressHistory(
        goalId: UUID,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [DataPoint] {
        try await dataPointRepository.fetch(goalId: goalId, from: startDate, to: endDate)
    }

    /// Gets progress summary for a goal
    public func getProgressSummary(
        goalId: UUID,
        from startDate: Date,
        to endDate: Date
    ) async throws -> ProgressSummary {
        let dataPoints = try await dataPointRepository.fetch(
            goalId: goalId,
            from: startDate,
            to: endDate
        )
        let sum = try await dataPointRepository.sum(
            goalId: goalId,
            from: startDate,
            to: endDate
        )
        let average = try await dataPointRepository.average(
            goalId: goalId,
            from: startDate,
            to: endDate
        )
        let count = try await dataPointRepository.count(
            goalId: goalId,
            from: startDate,
            to: endDate
        )

        return ProgressSummary(
            dataPoints: dataPoints,
            sum: sum,
            average: average,
            count: count,
            startDate: startDate,
            endDate: endDate
        )
    }
}

/// Errors that can occur during progress tracking
public enum TrackProgressError: Error, Sendable {
    case goalNotFound
    case invalidGoalType
    case invalidValue
}

/// Summary of progress for a goal over a period
public struct ProgressSummary: Sendable, Equatable {
    public let dataPoints: [DataPoint]
    public let sum: Double
    public let average: Double
    public let count: Int
    public let startDate: Date
    public let endDate: Date

    public init(
        dataPoints: [DataPoint],
        sum: Double,
        average: Double,
        count: Int,
        startDate: Date,
        endDate: Date
    ) {
        self.dataPoints = dataPoints
        self.sum = sum
        self.average = average
        self.count = count
        self.startDate = startDate
        self.endDate = endDate
    }
}
