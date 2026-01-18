import SwiftUI
import Charts

/// Simple line chart for overview cards
struct SparklineChart: View {
    let dataPoints: [InsightDataPoint]
    let color: Color

    /// Whether any data points have custom colors
    private var hasPointColors: Bool {
        dataPoints.contains { $0.color != nil }
    }

    var body: some View {
        Chart(dataPoints) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value)
            )
            .foregroundStyle(color.gradient)
            .interpolationMethod(.catmullRom)

            // Show colored points when per-point colors are provided
            if hasPointColors {
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(point.color ?? color)
                .symbolSize(30)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}
