import Foundation

/// Protocol defining the contract for DataPoint persistence operations
public protocol DataPointRepositoryProtocol: Sendable {
    /// Fetches all data points for a goal
    func fetchAll(goalId: UUID) async throws -> [DataPoint]

    /// Fetches data points for a goal within a date range
    func fetch(goalId: UUID, from startDate: Date, to endDate: Date) async throws -> [DataPoint]

    /// Fetches the most recent data point for a goal
    func fetchLatest(goalId: UUID) async throws -> DataPoint?

    /// Fetches a data point by its ID
    func fetch(id: UUID) async throws -> DataPoint?

    /// Creates a new data point
    @discardableResult
    func create(_ dataPoint: DataPoint) async throws -> DataPoint

    /// Creates multiple data points
    @discardableResult
    func createBatch(_ dataPoints: [DataPoint]) async throws -> [DataPoint]

    /// Updates an existing data point
    @discardableResult
    func update(_ dataPoint: DataPoint) async throws -> DataPoint

    /// Deletes a data point by its ID
    func delete(id: UUID) async throws

    /// Deletes all data points for a goal
    func deleteAll(goalId: UUID) async throws

    /// Calculates the sum of values for a goal within a date range
    func sum(goalId: UUID, from startDate: Date, to endDate: Date) async throws -> Double

    /// Calculates the average of values for a goal within a date range
    func average(goalId: UUID, from startDate: Date, to endDate: Date) async throws -> Double

    /// Gets the count of data points for a goal within a date range
    func count(goalId: UUID, from startDate: Date, to endDate: Date) async throws -> Int
}
