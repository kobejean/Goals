import Foundation

/// Metric options for Wii Fit charts
public enum WiiFitMetric: String, CaseIterable, Sendable {
    case weight
    case bmi
    case balance

    public var displayName: String {
        switch self {
        case .weight: return "Weight"
        case .bmi: return "BMI"
        case .balance: return "Balance"
        }
    }

    public var yAxisLabel: String {
        switch self {
        case .weight: return "kg"
        case .bmi: return ""
        case .balance: return "%"
        }
    }

    /// Key used for goal metric lookup
    public var metricKey: String {
        switch self {
        case .weight: return "weight"
        case .bmi: return "bmi"
        case .balance: return "balance"
        }
    }
}

/// Data point for charting Wii Fit measurements over time
public struct WiiFitChartDataPoint: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let weight: Double
    public let bmi: Double
    public let balance: Double

    public init(date: Date, weight: Double, bmi: Double, balance: Double) {
        self.date = date
        self.weight = weight
        self.bmi = bmi
        self.balance = balance
    }

    public func value(for metric: WiiFitMetric) -> Double {
        switch metric {
        case .weight: return weight
        case .bmi: return bmi
        case .balance: return balance
        }
    }
}
