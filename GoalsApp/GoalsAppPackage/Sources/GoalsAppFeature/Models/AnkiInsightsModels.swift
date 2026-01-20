import Foundation

/// Metric options for Anki charts
public enum AnkiMetric: String, CaseIterable, Sendable {
    case reviews
    case studyTime
    case retention
    case newCards

    public var displayName: String {
        switch self {
        case .reviews: return "Reviews"
        case .studyTime: return "Study Time"
        case .retention: return "Retention"
        case .newCards: return "New Cards"
        }
    }

    public var yAxisLabel: String {
        switch self {
        case .reviews: return "cards"
        case .studyTime: return "min"
        case .retention: return "%"
        case .newCards: return "cards"
        }
    }

    /// Key used for goal metric lookup
    public var metricKey: String {
        switch self {
        case .reviews: return "reviews"
        case .studyTime: return "studyTime"
        case .retention: return "retention"
        case .newCards: return "newCards"
        }
    }
}

/// Data point for charting Anki stats over time
public struct AnkiChartDataPoint: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let reviews: Int
    public let studyTimeMinutes: Double
    public let retention: Double
    public let newCards: Int

    public init(date: Date, reviews: Int, studyTimeMinutes: Double, retention: Double, newCards: Int) {
        self.date = date
        self.reviews = reviews
        self.studyTimeMinutes = studyTimeMinutes
        self.retention = retention
        self.newCards = newCards
    }

    public func value(for metric: AnkiMetric) -> Double {
        switch metric {
        case .reviews: return Double(reviews)
        case .studyTime: return studyTimeMinutes
        case .retention: return retention
        case .newCards: return Double(newCards)
        }
    }
}
