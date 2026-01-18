import SwiftUI

/// Represents the main navigation tabs in the app
public enum AppTab: String, CaseIterable, Identifiable {
    case today
    case goals
    case insights
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .today:
            return "Today"
        case .goals:
            return "Goals"
        case .insights:
            return "Insights"
        case .settings:
            return "Settings"
        }
    }

    public var iconName: String {
        switch self {
        case .today:
            return "sun.max.fill"
        case .goals:
            return "target"
        case .insights:
            return "chart.line.uptrend.xyaxis"
        case .settings:
            return "gearshape"
        }
    }

    @ViewBuilder
    public var label: some View {
        Label(title, systemImage: iconName)
    }
}
