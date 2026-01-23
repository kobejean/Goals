import SwiftUI

/// Represents the main navigation tabs in the app
public enum AppTab: String, CaseIterable, Identifiable {
    case insights
    case daily
    case goals
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .goals:
            return "Goals"
        case .insights:
            return "Insights"
        case .daily:
            return "Daily"
        case .settings:
            return "Settings"
        }
    }

    public var iconName: String {
        switch self {
        case .goals:
            return "target"
        case .insights:
            return "chart.line.uptrend.xyaxis"
        case .daily:
            return "calendar"
        case .settings:
            return "gearshape"
        }
    }

    @ViewBuilder
    public var label: some View {
        Label(title, systemImage: iconName)
    }
}
