import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for caching TensorTonic heatmap (activity) data
@Model
public final class TensorTonicHeatmapModel {
    /// Unique cache key for this record
    @Attribute(.unique)
    public var cacheKey: String = ""

    /// Date for this heatmap entry
    public var recordDate: Date = Date()

    /// When this record was fetched from the remote API
    public var fetchedAt: Date = Date()

    /// Activity count for this day
    public var count: Int = 0

    public init(
        cacheKey: String,
        recordDate: Date,
        fetchedAt: Date = Date(),
        count: Int
    ) {
        self.cacheKey = cacheKey
        self.recordDate = recordDate
        self.fetchedAt = fetchedAt
        self.count = count
    }
}

// MARK: - CacheableModel Conformance

extension TensorTonicHeatmapModel: CacheableModel {
    public typealias DomainType = TensorTonicHeatmapEntry
}

// MARK: - Domain Conversion

public extension TensorTonicHeatmapModel {
    func toDomain() -> TensorTonicHeatmapEntry {
        TensorTonicHeatmapEntry(
            date: recordDate,
            count: count
        )
    }

    static func from(_ record: TensorTonicHeatmapEntry, fetchedAt: Date = Date()) -> TensorTonicHeatmapModel {
        TensorTonicHeatmapModel(
            cacheKey: record.cacheKey,
            recordDate: record.recordDate,
            fetchedAt: fetchedAt,
            count: record.count
        )
    }

    func update(from record: TensorTonicHeatmapEntry, fetchedAt: Date = Date()) {
        self.recordDate = record.recordDate
        self.fetchedAt = fetchedAt
        self.count = record.count
    }
}
