import SwiftUI

/// Configuration for an insight card in the overview
public struct InsightCardConfig: Identifiable {
    public let id = UUID()
    public let title: String
    public let systemImage: String
    public let color: Color
    public let summary: InsightSummary?
    public let activityData: InsightActivityData?
    public let makeDetailView: @MainActor () -> AnyView

    public init(
        title: String,
        systemImage: String,
        color: Color,
        summary: InsightSummary?,
        activityData: InsightActivityData?,
        makeDetailView: @escaping @MainActor () -> AnyView
    ) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.summary = summary
        self.activityData = activityData
        self.makeDetailView = makeDetailView
    }
}

/// Minimalistic card component for insight overview
public struct InsightCard: View {
    public let title: String
    public let systemImage: String
    public let color: Color
    public let summary: InsightSummary?
    public let activityData: InsightActivityData?
    public let mode: InsightDisplayMode

    public init(
        title: String,
        systemImage: String,
        color: Color,
        summary: InsightSummary?,
        activityData: InsightActivityData?,
        mode: InsightDisplayMode
    ) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.summary = summary
        self.activityData = activityData
        self.mode = mode
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: icon + title + trend (trend only in chart mode)
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if mode == .chart, let trend = summary?.trend {
                    TrendBadge(trend: trend)
                }
            }

            // Fixed height content area for consistent card size
            VStack(alignment: .leading, spacing: 8) {
                switch mode {
                case .chart:
                    if let summary {
                        switch summary.chartType {
                        case .sparkline:
                            SparklineChart(
                                dataPoints: summary.dataPoints,
                                color: summary.color,
                                goalValue: summary.goalValue
                            )
                            .frame(height: 40)
                        case .durationRange:
                            if let rangeData = summary.durationRangeData {
                                DurationRangeChart(data: rangeData)
                                    .frame(height: 40)
                            }
                        case .scatterWithMovingAverage:
                            ScatterMovingAverageChart(
                                scatterPoints: summary.dataPoints,
                                movingAveragePoints: summary.movingAveragePoints ?? [],
                                color: summary.color,
                                goalValue: summary.goalValue
                            )
                            .frame(height: 40)
                        }
                    } else {
                        // Empty placeholder when no data
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.quaternary)
                            .frame(height: 40)
                    }

                    // Show "--" when no data, actual value when available
                    Text(summary?.currentValueFormatted ?? "--")
                        .font(.title2.bold())

                case .activity:
                    if let activityData {
                        ActivityChart(activityData: activityData)
                    } else {
                        // Empty placeholder when no data
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.quaternary)
                            .frame(height: 76)
                    }
                }
            }
            .frame(height: 76, alignment: .topLeading)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
