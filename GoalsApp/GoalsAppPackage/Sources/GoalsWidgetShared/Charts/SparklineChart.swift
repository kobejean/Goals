import SwiftUI
import Charts

/// Simple line chart for overview cards
public struct SparklineChart: View {
    let dataPoints: [InsightDataPoint]
    let color: Color
    let goalValue: Double?

    public init(dataPoints: [InsightDataPoint], color: Color, goalValue: Double? = nil) {
        self.dataPoints = dataPoints
        self.color = color
        self.goalValue = goalValue
    }

    /// Whether any data points have custom colors
    private var hasPointColors: Bool {
        dataPoints.contains { $0.color != nil }
    }

    public var body: some View {
        Chart {
            ForEach(dataPoints) { point in
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

            // Goal line
            if let goal = goalValue {
                RuleMark(y: .value("Goal", goal))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: yAxisDomain)
        .transaction { $0.animation = nil }  // Disable animation to preserve interpolation
    }

    /// Y-axis domain including goal value if present
    private var yAxisDomain: ClosedRange<Double> {
        let values = dataPoints.map(\.value)
        var minVal = values.min() ?? 0
        var maxVal = values.max() ?? 100

        if let goal = goalValue {
            minVal = min(minVal, goal)
            maxVal = max(maxVal, goal)
        }

        // Add some padding
        let padding = (maxVal - minVal) * 0.1
        return (minVal - padding)...(maxVal + padding)
    }
}
