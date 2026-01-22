import SwiftUI
import WidgetKit
import GoalsWidgetShared

/// Small widget view - reuses InsightCard with plain style
struct SmallInsightWidgetView: View {
    let entry: InsightWidgetEntry

    var body: some View {
        InsightCard(
            title: entry.insightType.displayTitle,
            systemImage: entry.insightType.systemImage,
            color: entry.insightType.color,
            summary: entry.summary,
            activityData: entry.activityData,
            mode: entry.displayMode,
            style: .plain
        )
    }
}
