import SwiftUI
import GoalsWidgetShared

/// Insight data tuple containing summary and activity data
public typealias InsightData = (summary: InsightSummary?, activityData: InsightActivityData?)

/// Protocol for insights section ViewModels
/// Defines common interface for insight data providers
@MainActor
public protocol InsightsSectionViewModel: AnyObject, Observable, Sendable {
    /// Static display title (available before loading)
    var title: String { get }

    /// Static system image name (available before loading)
    var systemImage: String { get }

    /// Static color for the insight (available before loading)
    var color: Color { get }

    /// Insight data containing summary and activity data
    var insight: InsightData { get }

    /// Current fetch status for the insight data
    var fetchStatus: InsightFetchStatus { get }

    /// Whether this data source requires throttling (e.g., network-based sources)
    /// Local data sources (SwiftData, etc.) can return false to always load fresh data
    var requiresThrottle: Bool { get }

    /// Load cached data only (for instant display when throttled)
    func loadCachedData() async

    /// Load all data (cached first, then fetch fresh)
    func loadData() async
}
