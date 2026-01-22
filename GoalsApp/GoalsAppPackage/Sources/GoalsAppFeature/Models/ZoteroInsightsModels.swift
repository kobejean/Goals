import Foundation

/// Metric options for Zotero charts
public enum ZoteroMetric: String, CaseIterable, Sendable {
    case annotations
    case notes
    case totalActivity

    public var displayName: String {
        switch self {
        case .annotations: return "Annotations"
        case .notes: return "Notes"
        case .totalActivity: return "Total Activity"
        }
    }

    public var yAxisLabel: String {
        switch self {
        case .annotations: return "items"
        case .notes: return "items"
        case .totalActivity: return "items"
        }
    }

    /// Key used for goal metric lookup
    public var metricKey: String {
        switch self {
        case .annotations: return "annotations"
        case .notes: return "notes"
        case .totalActivity: return "dailyAnnotations"
        }
    }
}

/// Data point for charting Zotero stats over time
public struct ZoteroChartDataPoint: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let annotations: Int
    public let notes: Int
    public let totalActivity: Int

    public init(date: Date, annotations: Int, notes: Int) {
        self.date = date
        self.annotations = annotations
        self.notes = notes
        self.totalActivity = annotations + notes
    }

    public func value(for metric: ZoteroMetric) -> Double {
        switch metric {
        case .annotations: return Double(annotations)
        case .notes: return Double(notes)
        case .totalActivity: return Double(totalActivity)
        }
    }
}
