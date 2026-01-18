import Foundation

/// Represents the different data sources that can provide progress data for goals
public enum DataSourceType: String, Codable, Sendable, CaseIterable {
    /// Manual user entry
    case manual

    /// TypeQuicker typing practice statistics
    case typeQuicker

    /// AtCoder competitive programming statistics
    case atCoder

    /// Financial data (income, expenses, savings)
    case finance

    /// GPS/Location tracking data
    case location

    /// Display name for the data source
    public var displayName: String {
        switch self {
        case .manual:
            return "Manual Entry"
        case .typeQuicker:
            return "TypeQuicker"
        case .atCoder:
            return "AtCoder"
        case .finance:
            return "Finance"
        case .location:
            return "Location"
        }
    }

    /// SF Symbol name for the data source icon
    public var iconName: String {
        switch self {
        case .manual:
            return "pencil.circle"
        case .typeQuicker:
            return "keyboard"
        case .atCoder:
            return "chevron.left.forwardslash.chevron.right"
        case .finance:
            return "dollarsign.circle"
        case .location:
            return "location.circle"
        }
    }

    /// Description of what this data source tracks
    public var description: String {
        switch self {
        case .manual:
            return "Manually entered progress data"
        case .typeQuicker:
            return "Typing speed, accuracy, and practice time from TypeQuicker"
        case .atCoder:
            return "Competitive programming rating, contests, and problems solved"
        case .finance:
            return "Financial metrics including income, expenses, and savings"
        case .location:
            return "GPS-based tracking for distance, places visited, and travel patterns"
        }
    }
}
