import SwiftUI
import Charts

/// Compact duration range chart for insight cards (40pt height, no axes)
struct DurationRangeChart: View {
    let data: InsightDurationRangeData

    var body: some View {
        Chart {
            ForEach(data.dataPoints) { point in
                ForEach(point.segments) { segment in
                    RectangleMark(
                        x: .value("Date", point.date, unit: .day),
                        yStart: .value("Start", segment.startChartValue),
                        yEnd: .value("End", segment.endChartValue)
                    )
                    .foregroundStyle(segment.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: yAxisDomain)
        .transaction { $0.animation = nil }
    }

    /// Calculate Y-axis domain from data points
    private var yAxisDomain: ClosedRange<Double> {
        let allSegments = data.dataPoints.flatMap(\.segments)
        guard !allSegments.isEmpty else {
            // Default domain: 10 PM (-2) to 8 AM (8)
            return -2...8
        }

        let minStart = allSegments.map(\.startChartValue).min() ?? -2
        let maxEnd = allSegments.map(\.endChartValue).max() ?? 8

        // Add padding
        let padding = (maxEnd - minStart) * 0.1
        return (minStart - padding)...(maxEnd + padding)
    }
}
