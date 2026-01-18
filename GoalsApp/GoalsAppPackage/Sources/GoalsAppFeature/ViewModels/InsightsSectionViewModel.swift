import SwiftUI

/// Protocol for insights section ViewModels
/// Each ViewModel knows how to load its data and create its section view
@MainActor
public protocol InsightsSectionViewModel: AnyObject, Observable, Sendable {
    /// Whether the section is currently loading data
    var isLoading: Bool { get }

    /// Load data for the given time range
    func loadData(timeRange: TimeRange) async

    /// Create the section view for this ViewModel
    func makeSection(timeRange: TimeRange) -> AnyView
}
