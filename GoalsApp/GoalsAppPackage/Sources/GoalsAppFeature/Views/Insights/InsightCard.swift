import SwiftUI

/// Minimalistic card component for insight overview
struct InsightCard: View {
    let title: String
    let systemImage: String
    let color: Color
    let summary: InsightSummary?
    let activityData: InsightActivityData?
    let mode: InsightDisplayMode

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
                if mode == .chart, let trend = summary?.trend {
                    TrendBadge(trend: trend)
                }
            }

            // Fixed height content area for consistent card size
            VStack(alignment: .leading, spacing: 8) {
                switch mode {
                case .chart:
                    if let summary {
                        SparklineChart(
                            dataPoints: summary.dataPoints,
                            color: summary.color,
                            goalValue: summary.goalValue
                        )
                        .frame(height: 40)
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
