import Foundation

/// Represents the different data sources that can provide progress data for goals
public enum DataSourceType: String, Codable, Sendable, CaseIterable {
    /// TypeQuicker typing practice statistics
    case typeQuicker

    /// AtCoder competitive programming statistics
    case atCoder

    /// Display name for the data source
    public var displayName: String {
        switch self {
        case .typeQuicker:
            return "TypeQuicker"
        case .atCoder:
            return "AtCoder"
        }
    }

    /// SF Symbol name for the data source icon
    public var iconName: String {
        switch self {
        case .typeQuicker:
            return "keyboard"
        case .atCoder:
            return "chevron.left.forwardslash.chevron.right"
        }
    }

    /// Description of what this data source tracks
    public var description: String {
        switch self {
        case .typeQuicker:
            return "Typing speed, accuracy, and practice time from TypeQuicker"
        case .atCoder:
            return "Competitive programming rating, contests, and problems solved"
        }
    }
}
