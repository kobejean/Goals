import SwiftUI

/// Minimalistic card component for insight overview
struct InsightCard: View {
    let title: String
    let systemImage: String
    let color: Color
    let summary: InsightSummary?
    let activityData: InsightActivityData?
    let mode: InsightDisplayMode
    let isLoading: Bool

    init(
        title: String,
        systemImage: String,
        color: Color,
        summary: InsightSummary?,
        activityData: InsightActivityData?,
        mode: InsightDisplayMode,
        isLoading: Bool = false
    ) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.summary = summary
        self.activityData = activityData
        self.mode = mode
        self.isLoading = isLoading
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: icon + title + trend (trend only in chart mode)
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if !isLoading, mode == .chart, let trend = summary?.trend {
                    TrendBadge(trend: trend)
                }
            }

            // Fixed height content area for consistent card size
            VStack(alignment: .leading, spacing: 8) {
                switch mode {
                case .chart:
                    if isLoading {
                        // Skeleton for chart during loading
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.quaternary)
                            .frame(height: 40)
                    } else if let summary {
                        SparklineChart(
                            dataPoints: summary.dataPoints,
                            color: summary.color,
                            goalValue: summary.goalValue
                        )
                        .frame(height: 40)
                    }

                    // Show "--" during loading, actual value when loaded
                    Text(isLoading ? "--" : (summary?.currentValueFormatted ?? "--"))
                        .font(.title2.bold())

                case .activity:
                    if isLoading {
                        // Skeleton for activity chart during loading
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.quaternary)
                            .frame(height: 76)
                    } else if let activityData {
                        ActivityChart(activityData: activityData)
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

/// Skeleton loading state for insight cards
struct InsightCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                    .frame(width: 20, height: 20)
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                    .frame(width: 60, height: 16)
                Spacer()
            }

            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
                .frame(height: 40)

            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
                .frame(width: 80, height: 28)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
