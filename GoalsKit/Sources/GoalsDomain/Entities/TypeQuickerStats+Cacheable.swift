import Foundation

extension TypeQuickerStats: CacheableRecord {
    public static var dataSource: DataSourceType { .typeQuicker }
    public static var recordType: String { "stats" }

    public var cacheKey: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "tq:stats:\(dateFormatter.string(from: date))"
    }

    public var recordDate: Date { date }
}
