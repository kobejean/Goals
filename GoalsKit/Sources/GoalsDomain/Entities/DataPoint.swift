import Foundation
import GoalsCore

/// Represents a single data point of progress for a goal
public struct DataPoint: Sendable, Equatable, UUIDIdentifiable {
    public let id: UUID
    public let goalId: UUID
    public var value: Double
    public var timestamp: Date
    public var source: DataSourceType
    public var note: String?
    public var metadata: [String: String]?

    public init(
        id: UUID = UUID(),
        goalId: UUID,
        value: Double,
        timestamp: Date = Date(),
        source: DataSourceType,
        note: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.goalId = goalId
        self.value = value
        self.timestamp = timestamp
        self.source = source
        self.note = note
        self.metadata = metadata
    }
}
