import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for caching AtCoder submissions
@Model
public final class AtCoderSubmissionModel {
    /// Unique cache key for this record (e.g., "ac:sub:12345678")
    @Attribute(.unique)
    public var cacheKey: String = ""

    /// Date of the submission
    public var recordDate: Date = Date()

    /// When this record was fetched from the remote API
    public var fetchedAt: Date = Date()

    // MARK: - Submission Fields

    /// Submission ID
    public var submissionId: Int = 0

    /// Unix timestamp of submission
    public var epochSecond: Int = 0

    /// Problem ID (e.g., "abc123_a")
    public var problemId: String = ""

    /// Contest ID (e.g., "abc123")
    public var contestId: String = ""

    /// User ID who submitted
    public var userId: String = ""

    /// Programming language used
    public var language: String = ""

    /// Points awarded
    public var point: Double = 0

    /// Code length in bytes
    public var length: Int = 0

    /// Result (e.g., "AC", "WA", "TLE")
    public var result: String = ""

    /// Execution time in milliseconds (optional)
    public var executionTime: Int?

    public init(
        cacheKey: String,
        recordDate: Date,
        fetchedAt: Date = Date(),
        submissionId: Int,
        epochSecond: Int,
        problemId: String,
        contestId: String,
        userId: String,
        language: String,
        point: Double,
        length: Int,
        result: String,
        executionTime: Int? = nil
    ) {
        self.cacheKey = cacheKey
        self.recordDate = recordDate
        self.fetchedAt = fetchedAt
        self.submissionId = submissionId
        self.epochSecond = epochSecond
        self.problemId = problemId
        self.contestId = contestId
        self.userId = userId
        self.language = language
        self.point = point
        self.length = length
        self.result = result
        self.executionTime = executionTime
    }
}

// MARK: - Domain Conversion

public extension AtCoderSubmissionModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> AtCoderSubmission {
        AtCoderSubmission(
            id: submissionId,
            epochSecond: epochSecond,
            problemId: problemId,
            contestId: contestId,
            userId: userId,
            language: language,
            point: point,
            length: length,
            result: result,
            executionTime: executionTime
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ record: AtCoderSubmission, fetchedAt: Date = Date()) -> AtCoderSubmissionModel {
        AtCoderSubmissionModel(
            cacheKey: record.cacheKey,
            recordDate: record.recordDate,
            fetchedAt: fetchedAt,
            submissionId: record.id,
            epochSecond: record.epochSecond,
            problemId: record.problemId,
            contestId: record.contestId,
            userId: record.userId,
            language: record.language,
            point: record.point,
            length: record.length,
            result: record.result,
            executionTime: record.executionTime
        )
    }

    /// Updates model from domain entity
    func update(from record: AtCoderSubmission, fetchedAt: Date = Date()) {
        self.recordDate = record.recordDate
        self.fetchedAt = fetchedAt
        self.submissionId = record.id
        self.epochSecond = record.epochSecond
        self.problemId = record.problemId
        self.contestId = record.contestId
        self.userId = record.userId
        self.language = record.language
        self.point = record.point
        self.length = record.length
        self.result = record.result
        self.executionTime = record.executionTime
    }
}
