import Foundation

/// TensorTonic problem-solving statistics (current snapshot)
public struct TensorTonicStats: Sendable, Equatable, Codable {
    public let date: Date

    // Regular problems
    public let easySolved: Int
    public let mediumSolved: Int
    public let hardSolved: Int
    public let totalSolved: Int

    // Total available problems
    public let totalEasyProblems: Int
    public let totalMediumProblems: Int
    public let totalHardProblems: Int

    // Research problems
    public let researchEasySolved: Int
    public let researchMediumSolved: Int
    public let researchHardSolved: Int
    public let researchTotalSolved: Int

    // Total available research problems
    public let totalResearchEasyProblems: Int
    public let totalResearchMediumProblems: Int
    public let totalResearchHardProblems: Int

    public init(
        date: Date,
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
        self.date = date
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

    /// Total problems available (regular + research)
    public var totalProblemsAvailable: Int {
        totalEasyProblems + totalMediumProblems + totalHardProblems +
        totalResearchEasyProblems + totalResearchMediumProblems + totalResearchHardProblems
    }

    /// Combined total solved (regular + research)
    public var combinedTotalSolved: Int {
        totalSolved + researchTotalSolved
    }

    /// Progress percentage for regular problems
    public var regularProgress: Double {
        let total = totalEasyProblems + totalMediumProblems + totalHardProblems
        guard total > 0 else { return 0 }
        return Double(totalSolved) / Double(total)
    }

    /// Progress percentage for research problems
    public var researchProgress: Double {
        let total = totalResearchEasyProblems + totalResearchMediumProblems + totalResearchHardProblems
        guard total > 0 else { return 0 }
        return Double(researchTotalSolved) / Double(total)
    }
}

// MARK: - CacheableRecord

extension TensorTonicStats: CacheableRecord {
    public static var dataSource: DataSourceType { .tensorTonic }
    public static var recordType: String { "stats" }

    public var cacheKey: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "tensortonic:stats:\(dateFormatter.string(from: date))"
    }

    public var recordDate: Date { date }
}

/// TensorTonic heatmap entry (activity by date)
public struct TensorTonicHeatmapEntry: Sendable, Equatable, Codable {
    public let date: Date
    public let count: Int

    public init(date: Date, count: Int) {
        self.date = date
        self.count = count
    }
}

// MARK: - CacheableRecord

extension TensorTonicHeatmapEntry: CacheableRecord {
    public static var dataSource: DataSourceType { .tensorTonic }
    public static var recordType: String { "heatmap" }

    public var cacheKey: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "tensortonic:heatmap:\(dateFormatter.string(from: date))"
    }

    public var recordDate: Date { date }
}
