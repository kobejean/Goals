import SwiftUI
import WidgetKit
import GoalsWidgetShared

/// Main insight widget that can be configured to show any insight type
struct InsightWidget: Widget {
    let kind: String = "InsightWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectInsightIntent.self,
            provider: InsightWidgetProvider()
        ) { entry in
            InsightWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Goals Insight")
        .description("View your insight data at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Main entry view that adapts to widget size
struct InsightWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: InsightWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallInsightWidgetView(entry: entry)
        case .systemMedium:
            MediumInsightWidgetView(entry: entry)
        case .systemLarge:
            LargeInsightWidgetView(entry: entry)
        default:
            MediumInsightWidgetView(entry: entry)
        }
    }
}

// MARK: - Previews

#Preview("Small - TypeQuicker", as: .systemSmall) {
    InsightWidget()
} timeline: {
    InsightWidgetEntry.placeholder(for: .typeQuicker)
}

#Preview("Medium - Sleep", as: .systemMedium) {
    InsightWidget()
} timeline: {
    InsightWidgetEntry.placeholder(for: .sleep)
}

#Preview("Large - AtCoder", as: .systemLarge) {
    InsightWidget()
} timeline: {
    InsightWidgetEntry.placeholder(for: .atCoder, mode: .activity)
}
