import Foundation

extension AtCoderStats: CacheableRecord {
    public static var dataSource: DataSourceType { .atCoder }
    public static var recordType: String { "contest_history" }

    public var cacheKey: String {
        // Contest screen name is the unique identifier for contest results
        // Only contest results should be cached - stats snapshots should not be stored
        guard let contestScreenName = contestScreenName else {
            fatalError("AtCoderStats.cacheKey called on non-contest entry. Only contest results should be cached.")
        }
        return "ac:contest:\(contestScreenName)"
    }

    public var recordDate: Date { date }
}
