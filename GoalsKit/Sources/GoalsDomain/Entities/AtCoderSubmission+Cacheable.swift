import Foundation

extension AtCoderSubmission: CacheableRecord {
    public static var dataSource: DataSourceType { .atCoder }
    public static var recordType: String { "submission" }

    public var cacheKey: String {
        "ac:sub:\(id)"
    }

    public var recordDate: Date { date }
}
