import SwiftUI
import GoalsDomain

/// Extension to convert GoalColor to SwiftUI Color
public extension GoalColor {
    var swiftUIColor: Color {
        switch self {
        case .blue:
            return .blue
        case .green:
            return .green
        case .orange:
            return .orange
        case .purple:
            return .purple
        case .red:
            return .red
        case .pink:
            return .pink
        case .yellow:
            return .yellow
        case .teal:
            return .teal
        }
    }
}
