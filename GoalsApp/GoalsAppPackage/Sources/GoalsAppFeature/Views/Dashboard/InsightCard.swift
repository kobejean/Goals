import SwiftUI

/// Minimalistic card component for insight overview
struct InsightCard: View {
    let summary: InsightSummary
    let activityData: InsightActivityData?
    let mode: InsightDisplayMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: icon + title + trend (trend only in chart mode)
            HStack {
                Image(systemName: summary.systemImage)
                    .foregroundStyle(summary.color)
                Text(summary.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if mode == .chart, let trend = summary.trend {
                    TrendBadge(trend: trend)
                }
            }

            // Fixed height content area for consistent card size
            VStack(alignment: .leading, spacing: 8) {
                switch mode {
                case .chart:
                    SparklineChart(dataPoints: summary.dataPoints, color: summary.color)
                        .frame(height: 40)

                    Text(summary.currentValueFormatted)
                        .font(.title2.bold())
                case .activity:
                    if let activityData {
                        ActivityChart(activityData: activityData)
                    } else {
                        SparklineChart(dataPoints: summary.dataPoints, color: summary.color)
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
