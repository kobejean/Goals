import Foundation

/// Metric options for Zotero charts
public enum ZoteroMetric: String, CaseIterable, Sendable {
    case annotations
    case notes
    case readingProgress
    case totalActivity

    public var displayName: String {
        switch self {
        case .annotations: return "Annotations"
        case .notes: return "Notes"
        case .totalActivity: return "Activity"
        case .readingProgress: return "Reading"
        }
    }

    public var yAxisLabel: String {
        switch self {
        case .annotations: return "items"
        case .notes: return "items"
        case .totalActivity: return "pts"
        case .readingProgress: return "score"
        }
    }

    /// Key used for goal metric lookup
    public var metricKey: String {
        switch self {
        case .annotations: return "annotations"
        case .notes: return "notes"
        case .totalActivity: return "dailyAnnotations"
        case .readingProgress: return "readingProgress"
        }
    }

}

/// Data point for charting Zotero stats over time
public struct ZoteroChartDataPoint: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let annotations: Int
    public let notes: Int
    public let readingProgressScore: Double

    public init(date: Date, annotations: Int, notes: Int, readingProgressScore: Double = 0) {
        self.date = date
        self.annotations = annotations
        self.notes = notes
        self.readingProgressScore = readingProgressScore
    }

    /// Weighted points: 0.1 * min(10, annotations) + 0.2 * min(5, notes) + readingProgress
    public var weightedPoints: Double {
        0.1 * Double(min(10, annotations)) +
        0.2 * Double(min(5, notes)) +
        readingProgressScore
    }

    public func value(for metric: ZoteroMetric) -> Double {
        switch metric {
        case .annotations: return Double(annotations)
        case .notes: return Double(notes)
        case .totalActivity: return weightedPoints
        case .readingProgress: return readingProgressScore
        }
    }
}
