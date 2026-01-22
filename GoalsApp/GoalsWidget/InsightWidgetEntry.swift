import SwiftUI
import WidgetKit
import GoalsWidgetShared

/// Timeline entry for insight widgets
struct InsightWidgetEntry: TimelineEntry {
    let date: Date
    let insightType: InsightType
    let displayMode: InsightDisplayMode
    let summary: InsightSummary?
    let activityData: InsightActivityData?

    /// Creates a placeholder entry for widget previews
    static func placeholder(for type: InsightType, mode: InsightDisplayMode = .chart) -> InsightWidgetEntry {
        InsightWidgetEntry(
            date: Date(),
            insightType: type,
            displayMode: mode,
            summary: nil,
            activityData: nil
        )
    }
}
