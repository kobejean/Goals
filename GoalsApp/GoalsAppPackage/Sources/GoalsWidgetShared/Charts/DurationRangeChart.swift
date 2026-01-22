import SwiftUI
import Charts

/// Compact duration range chart for insight cards (40pt height, no axes)
public struct DurationRangeChart: View {
    let data: InsightDurationRangeData

    public init(data: InsightDurationRangeData) {
        self.data = data
    }

    public var body: some View {
        Chart {
            ForEach(data.dataPoints) { point in
                ForEach(point.segments) { segment in
                    RectangleMark(
                        x: .value("Date", point.date, unit: .day),
                        yStart: .value("Start", yValue(for: segment, isStart: true)),
                        yEnd: .value("End", yValue(for: segment, isStart: false))
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

    /// Get Y value for a segment using appropriate coordinate system
    private func yValue(for segment: DurationSegment, isStart: Bool) -> Double {
        if data.useSimpleHours {
            return isStart ? segment.startHour : segment.endHour
        } else {
            return isStart ? segment.startChartValue : segment.endChartValue
        }
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
            // Default domain based on coordinate system
            return data.useSimpleHours ? 6...18 : -2...8
        }

        // Use all values (both start and end) to find true min/max
        let allValues: [Double]
        if data.useSimpleHours {
            allValues = allSegments.flatMap { [$0.startHour, $0.endHour] }
        } else {
            allValues = allSegments.flatMap { [$0.startChartValue, $0.endChartValue] }
        }

        let minValue = allValues.min() ?? (data.useSimpleHours ? 6.0 : -2.0)
        let maxValue = allValues.max() ?? (data.useSimpleHours ? 18.0 : 8.0)

        // Add padding (minimum 0.5 to avoid zero-height domain)
        let padding = max((maxValue - minValue) * 0.1, 0.5)
        return (minValue - padding)...(maxValue + padding)
    }
}
