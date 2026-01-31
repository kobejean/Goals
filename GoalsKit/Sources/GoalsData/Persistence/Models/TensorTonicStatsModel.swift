import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for caching TensorTonic problem-solving statistics
@Model
public final class TensorTonicStatsModel {
    /// Unique cache key for this record
    @Attribute(.unique)
    public var cacheKey: String = ""

    /// Date for this stats record
    public var recordDate: Date = Date()

    /// When this record was fetched from the remote API
    public var fetchedAt: Date = Date()

    // MARK: - Regular Problems

    public var easySolved: Int = 0
    public var mediumSolved: Int = 0
    public var hardSolved: Int = 0
    public var totalSolved: Int = 0

    public var totalEasyProblems: Int = 0
    public var totalMediumProblems: Int = 0
    public var totalHardProblems: Int = 0

    // MARK: - Research Problems

    public var researchEasySolved: Int = 0
    public var researchMediumSolved: Int = 0
    public var researchHardSolved: Int = 0
    public var researchTotalSolved: Int = 0

    public var totalResearchEasyProblems: Int = 0
    public var totalResearchMediumProblems: Int = 0
    public var totalResearchHardProblems: Int = 0

    public init(
        cacheKey: String,
        recordDate: Date,
        fetchedAt: Date = Date(),
        easySolved: Int,
        mediumSolved: Int,
        hardSolved: Int,
        totalSolved: Int,
        totalEasyProblems: Int,
        totalMediumProblems: Int,
        totalHardProblems: Int,
        researchEasySolved: Int,
        researchMediumSolved: Int,
        researchHardSolved: Int,
        researchTotalSolved: Int,
        totalResearchEasyProblems: Int,
        totalResearchMediumProblems: Int,
        totalResearchHardProblems: Int
    ) {
        self.cacheKey = cacheKey
        self.recordDate = recordDate
        self.fetchedAt = fetchedAt
        self.easySolved = easySolved
        self.mediumSolved = mediumSolved
        self.hardSolved = hardSolved
        self.totalSolved = totalSolved
        self.totalEasyProblems = totalEasyProblems
        self.totalMediumProblems = totalMediumProblems
        self.totalHardProblems = totalHardProblems
        self.researchEasySolved = researchEasySolved
        self.researchMediumSolved = researchMediumSolved
        self.researchHardSolved = researchHardSolved
        self.researchTotalSolved = researchTotalSolved
        self.totalResearchEasyProblems = totalResearchEasyProblems
        self.totalResearchMediumProblems = totalResearchMediumProblems
        self.totalResearchHardProblems = totalResearchHardProblems
    }
}

// MARK: - CacheableModel Conformance

extension TensorTonicStatsModel: CacheableModel {
    public typealias DomainType = TensorTonicStats
}

// MARK: - Domain Conversion

public extension TensorTonicStatsModel {
    func toDomain() -> TensorTonicStats {
        TensorTonicStats(
            date: recordDate,
            easySolved: easySolved,
            mediumSolved: mediumSolved,
            hardSolved: hardSolved,
            totalSolved: totalSolved,
            totalEasyProblems: totalEasyProblems,
            totalMediumProblems: totalMediumProblems,
            totalHardProblems: totalHardProblems,
            researchEasySolved: researchEasySolved,
            researchMediumSolved: researchMediumSolved,
            researchHardSolved: researchHardSolved,
            researchTotalSolved: researchTotalSolved,
            totalResearchEasyProblems: totalResearchEasyProblems,
            totalResearchMediumProblems: totalResearchMediumProblems,
            totalResearchHardProblems: totalResearchHardProblems
        )
    }

    static func from(_ record: TensorTonicStats, fetchedAt: Date = Date()) -> TensorTonicStatsModel {
        TensorTonicStatsModel(
            cacheKey: record.cacheKey,
            recordDate: record.recordDate,
            fetchedAt: fetchedAt,
            easySolved: record.easySolved,
            mediumSolved: record.mediumSolved,
            hardSolved: record.hardSolved,
            totalSolved: record.totalSolved,
            totalEasyProblems: record.totalEasyProblems,
            totalMediumProblems: record.totalMediumProblems,
            totalHardProblems: record.totalHardProblems,
            researchEasySolved: record.researchEasySolved,
            researchMediumSolved: record.researchMediumSolved,
            researchHardSolved: record.researchHardSolved,
            researchTotalSolved: record.researchTotalSolved,
            totalResearchEasyProblems: record.totalResearchEasyProblems,
            totalResearchMediumProblems: record.totalResearchMediumProblems,
            totalResearchHardProblems: record.totalResearchHardProblems
        )
    }

    func update(from record: TensorTonicStats, fetchedAt: Date = Date()) {
        self.recordDate = record.recordDate
        self.fetchedAt = fetchedAt
        self.easySolved = record.easySolved
        self.mediumSolved = record.mediumSolved
        self.hardSolved = record.hardSolved
        self.totalSolved = record.totalSolved
        self.totalEasyProblems = record.totalEasyProblems
        self.totalMediumProblems = record.totalMediumProblems
        self.totalHardProblems = record.totalHardProblems
        self.researchEasySolved = record.researchEasySolved
        self.researchMediumSolved = record.researchMediumSolved
        self.researchHardSolved = record.researchHardSolved
        self.researchTotalSolved = record.researchTotalSolved
        self.totalResearchEasyProblems = record.totalResearchEasyProblems
        self.totalResearchMediumProblems = record.totalResearchMediumProblems
        self.totalResearchHardProblems = record.totalResearchHardProblems
    }
}
