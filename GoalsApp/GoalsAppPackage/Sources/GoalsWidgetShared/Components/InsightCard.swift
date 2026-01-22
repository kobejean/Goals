import SwiftUI

/// Style for InsightCard background and corner rendering
public enum InsightCardStyle {
    /// Full styling: material background + rounded corners (for app)
    case card
    /// No background/corners (for widgets - container provides these)
    case plain
}

/// Minimalistic card component for insight overview (widget-compatible version)
public struct InsightCard: View {
    public let title: String
    public let systemImage: String
    public let color: Color
    public let summary: InsightSummary?
    public let activityData: InsightActivityData?
    public let mode: InsightDisplayMode
    public let style: InsightCardStyle

    public init(
        title: String,
        systemImage: String,
        color: Color,
        summary: InsightSummary?,
        activityData: InsightActivityData?,
        mode: InsightDisplayMode,
        style: InsightCardStyle = .card
    ) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.summary = summary
        self.activityData = activityData
        self.mode = mode
        self.style = style
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: icon + title + trend (trend only in chart mode)
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(summary?.color ?? color)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Fixed height content area for consistent card size
            contentView
                .frame(height: contentHeight, alignment: .topLeading)
        }
        .padding()
        .modifier(CardStyleModifier(style: style))
    }

    /// Content height
    private let contentHeight: CGFloat = 76

    /// Main content view that switches based on display mode
    @ViewBuilder
    private var contentView: some View {
        switch mode {
        case .chart:
            chartContent(height: 56, showValue: true, valueFont: .title2.bold())

        case .activity:
            activityContent

        case .both:
            HStack(alignment: .top, spacing: 12) {
                // Left: Chart with current value
                chartContent(height: 56, showValue: true, valueFont: .headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Right: Activity grid
                activityContent
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    /// Reusable chart content view
    @ViewBuilder
    private func chartContent(height: CGFloat, showValue: Bool, valueFont: Font) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let summary {
                chartView(for: summary)
                    .frame(height: height)
            } else {
                // Empty placeholder when no data
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                    .frame(height: height)
            }

            if showValue {
                Text(summary?.currentValueFormatted ?? "--")
                    .font(valueFont)
            }
        }
    }

    /// Renders the appropriate chart based on chart type
    @ViewBuilder
    private func chartView(for summary: InsightSummary) -> some View {
        switch summary.chartType {
        case .sparkline:
            SparklineChart(
                dataPoints: summary.dataPoints,
                color: summary.color,
                goalValue: summary.goalValue
            )
        case .durationRange:
            if let rangeData = summary.durationRangeData {
                DurationRangeChart(data: rangeData)
            }
        case .scatterWithMovingAverage:
            ScatterMovingAverageChart(
                scatterPoints: summary.dataPoints,
                movingAveragePoints: summary.movingAveragePoints ?? [],
                color: summary.color,
                goalValue: summary.goalValue
            )
        case .wpmAccuracy:
            if let wpmAccuracyData = summary.wpmAccuracyData {
                WPMAccuracyChart(data: wpmAccuracyData, style: .compact)
            }
        }
    }

    /// Reusable activity grid content view
    @ViewBuilder
    private var activityContent: some View {
        if let activityData {
            ActivityChart(activityData: activityData)
        } else {
            // Empty placeholder when no data
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
        }
    }
}

/// View modifier to apply card styling based on InsightCardStyle
struct CardStyleModifier: ViewModifier {
    let style: InsightCardStyle

    func body(content: Content) -> some View {
        switch style {
        case .card:
            content
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        case .plain:
            content
        }
    }
}
