import SwiftUI
import WidgetKit
import GoalsWidgetShared

/// Timeline provider for insight widgets using App Intents configuration
struct InsightWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = InsightWidgetEntry
    typealias Intent = SelectInsightIntent

    func placeholder(in context: Context) -> InsightWidgetEntry {
        InsightWidgetEntry.placeholder(for: .typeQuicker)
    }

    func snapshot(for configuration: SelectInsightIntent, in context: Context) async -> InsightWidgetEntry {
        // For preview/gallery, show a placeholder
        let type = configuration.insightType ?? .typeQuicker
        let mode = configuration.displayMode ?? .chart
        return InsightWidgetEntry.placeholder(for: type, mode: mode)
    }

    func timeline(for configuration: SelectInsightIntent, in context: Context) async -> Timeline<InsightWidgetEntry> {
        let type = configuration.insightType ?? .typeQuicker
        let mode = configuration.displayMode ?? .chart

        // Fetch data from shared cache
        let (summary, activityData) = type.fetchInsight()

        let entry = InsightWidgetEntry(
            date: Date(),
            insightType: type,
            displayMode: mode,
            summary: summary,
            activityData: activityData
        )

        // Refresh every 15 minutes (minimum allowed by WidgetKit)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}
