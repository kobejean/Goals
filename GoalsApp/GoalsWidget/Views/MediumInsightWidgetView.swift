import SwiftUI
import WidgetKit
import GoalsWidgetShared

/// Medium widget view - reuses the InsightCard component
struct MediumInsightWidgetView: View {
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
