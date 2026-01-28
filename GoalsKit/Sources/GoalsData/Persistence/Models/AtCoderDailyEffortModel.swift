import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for caching AtCoder daily submission effort
@Model
public final class AtCoderDailyEffortModel {
    /// Unique cache key for this record (e.g., "ac:effort:2025-01-15")
    @Attribute(.unique)
    public var cacheKey: String = ""

    /// Date for this effort record
    public var recordDate: Date = Date()

    /// When this record was fetched from the remote API
    public var fetchedAt: Date = Date()

    // MARK: - Effort Fields

    /// JSON-encoded dictionary of submissions by difficulty color
    /// Format: { "gray": 5, "brown": 3, "green": 2, ... }
    @Attribute(.externalStorage)
    public var submissionsByDifficultyData: Data = Data()

    public init(
        cacheKey: String,
        recordDate: Date,
        fetchedAt: Date = Date(),
        submissionsByDifficultyData: Data
    ) {
        self.cacheKey = cacheKey
        self.recordDate = recordDate
        self.fetchedAt = fetchedAt
        self.submissionsByDifficultyData = submissionsByDifficultyData
    }
}

// MARK: - Domain Conversion

public extension AtCoderDailyEffortModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> AtCoderDailyEffort {
        let decoder = JSONDecoder()
        var submissionsByDifficulty: [AtCoderRankColor: Int] = [:]

        if let stringDict = try? decoder.decode([String: Int].self, from: submissionsByDifficultyData) {
            for (key, value) in stringDict {
                if let color = AtCoderRankColor(rawValue: key) {
                    submissionsByDifficulty[color] = value
                }
            }
        }

        return AtCoderDailyEffort(
            date: recordDate,
            submissionsByDifficulty: submissionsByDifficulty
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ record: AtCoderDailyEffort, fetchedAt: Date = Date()) -> AtCoderDailyEffortModel {
        let encoder = JSONEncoder()
        var stringDict: [String: Int] = [:]
        for (color, count) in record.submissionsByDifficulty {
            stringDict[color.rawValue] = count
        }
        let data = (try? encoder.encode(stringDict)) ?? Data()

        return AtCoderDailyEffortModel(
            cacheKey: record.cacheKey,
            recordDate: record.recordDate,
            fetchedAt: fetchedAt,
            submissionsByDifficultyData: data
        )
    }

    /// Updates model from domain entity
    func update(from record: AtCoderDailyEffort, fetchedAt: Date = Date()) {
        self.recordDate = record.recordDate
        self.fetchedAt = fetchedAt

        let encoder = JSONEncoder()
        var stringDict: [String: Int] = [:]
        for (color, count) in record.submissionsByDifficulty {
            stringDict[color.rawValue] = count
        }
        self.submissionsByDifficultyData = (try? encoder.encode(stringDict)) ?? Data()
    }
}
