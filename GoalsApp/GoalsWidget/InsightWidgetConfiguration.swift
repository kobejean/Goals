import AppIntents
import WidgetKit
import GoalsWidgetShared

/// App Intent for selecting which insight to display in the widget
struct SelectInsightIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Insight"
    static var description = IntentDescription("Choose which insight to display")

    @Parameter(title: "Insight Type", default: .typeQuicker)
    var insightType: InsightType?

    @Parameter(title: "Display Mode", default: .chart)
    var displayMode: InsightDisplayMode?

    init() {}

    init(insightType: InsightType, displayMode: InsightDisplayMode = .chart) {
        self.insightType = insightType
        self.displayMode = displayMode
    }
}
