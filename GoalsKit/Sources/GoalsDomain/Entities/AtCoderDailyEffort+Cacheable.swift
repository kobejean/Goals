import Foundation

/// Add Codable conformance to AtCoderDailyEffort for caching
extension AtCoderDailyEffort: Codable {
    enum CodingKeys: String, CodingKey {
        case date
        case submissionsByDifficulty
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let date = try container.decode(Date.self, forKey: .date)

        // Decode the dictionary with String keys and convert to AtCoderRankColor
        let stringDict = try container.decode([String: Int].self, forKey: .submissionsByDifficulty)
        var colorDict: [AtCoderRankColor: Int] = [:]
        for (key, value) in stringDict {
            if let color = AtCoderRankColor(rawValue: key) {
                colorDict[color] = value
            }
        }

        self.init(date: date, submissionsByDifficulty: colorDict)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)

        // Encode the dictionary with String keys
        var stringDict: [String: Int] = [:]
        for (color, count) in submissionsByDifficulty {
            stringDict[color.rawValue] = count
        }
        try container.encode(stringDict, forKey: .submissionsByDifficulty)
    }
}

extension AtCoderDailyEffort: CacheableRecord {
    public static var dataSource: DataSourceType { .atCoder }
    public static var recordType: String { "effort" }

    public var cacheKey: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "ac:effort:\(dateFormatter.string(from: date))"
    }

    public var recordDate: Date { date }
}
