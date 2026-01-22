import SwiftUI
import GoalsDomain

/// Extension to convert AtCoderRankColor to SwiftUI Color
public extension AtCoderRankColor {
    var swiftUIColor: Color {
        switch self {
        case .gray: return .gray
        case .brown: return .brown
        case .green: return .green
        case .cyan: return .cyan
        case .blue: return .blue
        case .yellow: return .yellow
        case .orange: return .orange
        case .red: return .red
        }
    }
}
