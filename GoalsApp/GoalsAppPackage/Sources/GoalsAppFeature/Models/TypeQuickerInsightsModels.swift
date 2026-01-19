import Foundation

/// Metric options for TypeQuicker charts
public enum TypeQuickerMetric: String, CaseIterable, Sendable {
    case wpm
    case accuracy
    case time

    public var displayName: String {
        switch self {
        case .wpm: return "WPM"
        case .accuracy: return "Accuracy"
        case .time: return "Time"
        }
    }

    public var yAxisLabel: String {
        switch self {
        case .wpm: return "WPM"
        case .accuracy: return "%"
        case .time: return "min"
        }
    }
}

/// Data point for charting mode-specific TypeQuicker stats over time
public struct TypeQuickerModeDataPoint: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let mode: String
    public let wpm: Double
    public let accuracy: Double
    public let timeMinutes: Int

    public init(date: Date, mode: String, wpm: Double, accuracy: Double, timeMinutes: Int) {
        self.date = date
        self.mode = mode
        self.wpm = wpm
        self.accuracy = accuracy
        self.timeMinutes = timeMinutes
    }

    public func value(for metric: TypeQuickerMetric) -> Double {
        switch metric {
        case .wpm: return wpm
        case .accuracy: return accuracy
        case .time: return Double(timeMinutes)
        }
    }
}
