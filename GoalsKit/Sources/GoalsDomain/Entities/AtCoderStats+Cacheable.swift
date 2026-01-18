import Foundation

extension AtCoderStats: CacheableRecord {
    public static var dataSource: DataSourceType { .atCoder }
    public static var recordType: String { "contest_history" }

    public var cacheKey: String {
        // Use contest screen name as unique identifier
        // This ensures we only store actual contest results, not stats snapshots
        if let contestScreenName = contestScreenName {
            return "ac:contest:\(contestScreenName)"
        }
        // Fallback for legacy data without contest ID (will be overwritten)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return "ac:stats:\(formatter.string(from: date))"
    }

    public var recordDate: Date { date }
}
