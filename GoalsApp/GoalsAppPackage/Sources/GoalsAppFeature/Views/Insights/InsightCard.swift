import SwiftUI
import GoalsWidgetShared

// InsightType and InsightCard are now defined in GoalsWidgetShared
// This file contains only the app-specific InsightCardConfig

/// Configuration for an insight card in the overview (app-specific, includes navigation)
public struct InsightCardConfig: Identifiable {
    public var id: InsightType { type }
    public let type: InsightType
    public let title: String
    public let systemImage: String
    public let color: Color
    public let summary: InsightSummary?
    public let activityData: InsightActivityData?
    public let fetchStatus: InsightFetchStatus
    public let makeDetailView: @MainActor () -> AnyView

    public init(
        type: InsightType,
        title: String,
        systemImage: String,
        color: Color,
        summary: InsightSummary?,
        activityData: InsightActivityData?,
        fetchStatus: InsightFetchStatus,
        makeDetailView: @escaping @MainActor () -> AnyView
    ) {
        self.type = type
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.summary = summary
        self.activityData = activityData
        self.fetchStatus = fetchStatus
        self.makeDetailView = makeDetailView
    }
}
