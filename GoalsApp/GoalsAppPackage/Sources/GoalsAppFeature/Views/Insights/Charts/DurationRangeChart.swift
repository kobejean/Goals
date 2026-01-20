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
        .chartXScale(domain: xAxisDomain)
        .chartYScale(domain: yAxisDomain)
        .padding(.horizontal, 4)
        .transaction { $0.animation = nil }
    }

    /// Calculate X-axis domain from dateRange or fall back to data-derived domain
    private var xAxisDomain: ClosedRange<Date> {
        if let range = data.dateRange {
            return range.start...range.end
        }
        // Fall back to data-derived domain
        let dates = data.dataPoints.map { $0.date }
        guard let minDate = dates.min(),
              let maxDate = dates.max() else {
            let now = Date()
            return now...now
        }
        return minDate...maxDate
    }

    /// Calculate Y-axis domain from data points
    private var yAxisDomain: ClosedRange<Double> {
        let allSegments = data.dataPoints.flatMap { $0.segments }
        guard !allSegments.isEmpty else {
            // Default domain: 10 PM (-2) to 8 AM (8)
            return -2...8
        }

        let startValues = allSegments.map { $0.startChartValue }
        let endValues = allSegments.map { $0.endChartValue }
        let minStart = startValues.min() ?? -2.0
        let maxEnd = endValues.max() ?? 8.0

        // Add padding
        let padding = (maxEnd - minStart) * 0.1
        return (minStart - padding)...(maxEnd + padding)
    }
}
