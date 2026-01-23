import Foundation

/// Represents the different data sources that can provide progress data for goals
public enum DataSourceType: String, Codable, Sendable, CaseIterable {
    /// TypeQuicker typing practice statistics
    case typeQuicker

    /// AtCoder competitive programming statistics
    case atCoder

    /// HealthKit sleep data
    case healthKitSleep

    /// Manual task time tracking
    case tasks

    /// Anki spaced repetition learning statistics
    case anki

    /// Zotero reference management and reading progress
    case zotero

    /// Photo-based nutrition tracking with AI analysis
    case nutrition

    /// Display name for the data source
    public var displayName: String {
        switch self {
        case .typeQuicker:
            return "TypeQuicker"
        case .atCoder:
            return "AtCoder"
        case .healthKitSleep:
            return "Sleep"
        case .tasks:
            return "Tasks"
        case .anki:
            return "Anki"
        case .zotero:
            return "Zotero"
        case .nutrition:
            return "Nutrition"
        }
    }

    /// SF Symbol name for the data source icon
    public var iconName: String {
        switch self {
        case .typeQuicker:
            return "keyboard"
        case .atCoder:
            return "chevron.left.forwardslash.chevron.right"
        case .healthKitSleep:
            return "bed.double.fill"
        case .tasks:
            return "timer"
        case .anki:
            return "rectangle.stack"
        case .zotero:
            return "books.vertical"
        case .nutrition:
            return "fork.knife"
        }
    }

    /// Description of what this data source tracks
    public var description: String {
        switch self {
        case .typeQuicker:
            return "Typing speed, accuracy, and practice time from TypeQuicker"
        case .atCoder:
            return "Competitive programming rating, contests, and problems solved"
        case .healthKitSleep:
            return "Sleep duration, stages, and quality from HealthKit"
        case .tasks:
            return "Manual time tracking for tasks and activities"
        case .anki:
            return "Reviews, study time, retention, and streak from Anki"
        case .zotero:
            return "Reading progress and annotations from Zotero"
        case .nutrition:
            return "Photo-based nutrition tracking with AI analysis"
        }
    }
}
