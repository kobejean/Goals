import SwiftUI
import GoalsWidgetShared

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

    /// Summary data for the overview card
    var summary: InsightSummary? { get }

    /// Activity data for GitHub-style contribution chart
    var activityData: InsightActivityData? { get }

    /// Current fetch status for the insight data
    var fetchStatus: InsightFetchStatus { get }

    /// Load all data (always loads full range for overview)
    func loadData() async
}
