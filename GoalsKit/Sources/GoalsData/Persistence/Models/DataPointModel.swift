import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for persisting DataPoint entities
@Model
public final class DataPointModel {
    @Attribute(.unique) public var id: UUID
    public var goalId: UUID
    public var value: Double
    public var timestamp: Date
    public var sourceRawValue: String
    public var note: String?
    public var metadataJSON: Data?

    // Relationship
    public var goal: GoalModel?

    public init(
        id: UUID = UUID(),
        goalId: UUID,
        value: Double,
        timestamp: Date = Date(),
        sourceRawValue: String,
        note: String? = nil,
        metadataJSON: Data? = nil
    ) {
        self.id = id
        self.goalId = goalId
        self.value = value
        self.timestamp = timestamp
        self.sourceRawValue = sourceRawValue
        self.note = note
        self.metadataJSON = metadataJSON
    }
}

// MARK: - Domain Conversion

public extension DataPointModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> DataPoint {
        var metadata: [String: String]?
        if let data = metadataJSON {
            metadata = try? JSONDecoder().decode([String: String].self, from: data)
        }

        return DataPoint(
            id: id,
            goalId: goalId,
            value: value,
            timestamp: timestamp,
            source: DataSourceType(rawValue: sourceRawValue) ?? .manual,
            note: note,
            metadata: metadata
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ dataPoint: DataPoint) -> DataPointModel {
        var metadataJSON: Data?
        if let metadata = dataPoint.metadata {
            metadataJSON = try? JSONEncoder().encode(metadata)
        }

        return DataPointModel(
            id: dataPoint.id,
            goalId: dataPoint.goalId,
            value: dataPoint.value,
            timestamp: dataPoint.timestamp,
            sourceRawValue: dataPoint.source.rawValue,
            note: dataPoint.note,
            metadataJSON: metadataJSON
        )
    }

    /// Updates model from domain entity
    func update(from dataPoint: DataPoint) {
        value = dataPoint.value
        timestamp = dataPoint.timestamp
        sourceRawValue = dataPoint.source.rawValue
        note = dataPoint.note
        if let metadata = dataPoint.metadata {
            metadataJSON = try? JSONEncoder().encode(metadata)
        } else {
            metadataJSON = nil
        }
    }
}
