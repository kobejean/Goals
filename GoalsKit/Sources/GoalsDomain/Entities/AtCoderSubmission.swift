import Foundation

/// AtCoder submission record
public struct AtCoderSubmission: Sendable, Equatable, Codable, Identifiable {
    public let id: Int
    public let epochSecond: Int
    public let problemId: String
    public let contestId: String
    public let userId: String
    public let language: String
    public let point: Double
    public let length: Int
    public let result: String
    public let executionTime: Int?

    public init(
        id: Int,
        epochSecond: Int,
        problemId: String,
        contestId: String,
        userId: String,
        language: String,
        point: Double,
        length: Int,
        result: String,
        executionTime: Int?
    ) {
        self.id = id
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

    /// Date of the submission
    public var date: Date {
        Date(timeIntervalSince1970: TimeInterval(epochSecond))
    }

    /// Whether the submission was accepted
    public var isAccepted: Bool {
        result == "AC"
    }
}

// MARK: - CacheableRecord

extension AtCoderSubmission: CacheableRecord {
    public static var dataSource: DataSourceType { .atCoder }
    public static var recordType: String { "submission" }

    public var cacheKey: String {
        "ac:sub:\(id)"
    }

    public var recordDate: Date { date }
}
