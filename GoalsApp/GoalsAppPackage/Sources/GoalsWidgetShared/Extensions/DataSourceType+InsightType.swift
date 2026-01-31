import Foundation
import GoalsDomain

/// Extension providing bidirectional mapping between DataSourceType and InsightType.
/// This eliminates duplicated display properties by allowing type conversion.
extension DataSourceType {
    /// Returns the corresponding InsightType for this data source.
    /// Note: DataSourceType.healthKitSleep maps to InsightType.sleep
    public var insightType: InsightType {
        switch self {
        case .typeQuicker: return .typeQuicker
        case .atCoder: return .atCoder
        case .healthKitSleep: return .sleep
        case .tasks: return .tasks
        case .locations: return .locations
        case .anki: return .anki
        case .zotero: return .zotero
        case .nutrition: return .nutrition
        case .wiiFit: return .wiiFit
        case .tensorTonic: return .tensorTonic
        }
    }
}

extension InsightType {
    /// Returns the corresponding DataSourceType for this insight type.
    /// Note: InsightType.sleep maps to DataSourceType.healthKitSleep
    public var dataSourceType: DataSourceType {
        switch self {
        case .typeQuicker: return .typeQuicker
        case .atCoder: return .atCoder
        case .sleep: return .healthKitSleep
        case .tasks: return .tasks
        case .locations: return .locations
        case .anki: return .anki
        case .zotero: return .zotero
        case .nutrition: return .nutrition
        case .wiiFit: return .wiiFit
        case .tensorTonic: return .tensorTonic
        }
    }
}
