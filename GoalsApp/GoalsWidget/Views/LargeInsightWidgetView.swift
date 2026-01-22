import SwiftUI
import WidgetKit
import GoalsWidgetShared

/// Large widget view - InsightCard with full activity chart below
struct LargeInsightWidgetView: View {
    let entry: InsightWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top section: reuse InsightCard for chart display
            InsightCard(
                title: entry.insightType.displayTitle,
                systemImage: entry.insightType.systemImage,
                color: entry.insightType.color,
                summary: entry.summary,
                activityData: entry.activityData,
                mode: .chart,
                style: .plain
            )

            Divider()
                .padding(.horizontal)

            // Activity section
            VStack(alignment: .leading, spacing: 4) {
                Text("Activity")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let activityData = entry.activityData {
                    ActivityChart(activityData: activityData)
                        .frame(maxHeight: .infinity)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(maxHeight: .infinity)
                }
            }
            .padding()
        }
    }
}
