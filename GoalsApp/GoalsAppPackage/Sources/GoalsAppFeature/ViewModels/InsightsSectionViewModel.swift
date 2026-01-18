import SwiftUI

/// Protocol for insights section ViewModels
/// Each ViewModel knows how to load its data and create its section view
@MainActor
public protocol InsightsSectionViewModel: AnyObject, Observable, Sendable {
    /// Whether the section is currently loading data
    var isLoading: Bool { get }

    /// Summary data for the overview card
    var summary: InsightSummary? { get }

    /// Activity data for GitHub-style contribution chart
    var activityData: InsightActivityData? { get }

    /// Load all data (always loads full range for overview)
    func loadData() async

    /// Create the detail view for this ViewModel (full charts)
    func makeDetailView() -> AnyView
}
