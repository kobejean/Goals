import SwiftUI
import AppIntents

/// Display mode for insight cards
public enum InsightDisplayMode: String, CaseIterable, Sendable {
    case chart
    case activity
    case both

    public var systemImage: String {
        switch self {
        case .chart: return "chart.line.uptrend.xyaxis"
        case .activity: return "square.grid.3x3"
        case .both: return "rectangle.split.2x1"
        }
    }
}

// MARK: - AppEnum for Widget Configuration

extension InsightDisplayMode: AppEnum {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Display Mode")
    }

    public static var caseDisplayRepresentations: [InsightDisplayMode: DisplayRepresentation] {
        [
            .chart: DisplayRepresentation(title: "Chart"),
            .activity: DisplayRepresentation(title: "Activity Grid"),
            .both: DisplayRepresentation(title: "Both")
        ]
    }
}
