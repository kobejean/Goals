import SwiftUI

/// Display mode for insight cards
public enum InsightDisplayMode: String, CaseIterable, Sendable {
    case chart
    case activity

    public var systemImage: String {
        switch self {
        case .chart: return "chart.line.uptrend.xyaxis"
        case .activity: return "square.grid.3x3"
        }
    }
}
