import SwiftUI
import Charts

/// Chart showing scatter points with a moving average line
public struct ScatterMovingAverageChart: View {
    let scatterPoints: [InsightDataPoint]
    let movingAveragePoints: [InsightDataPoint]
    let color: Color
    let goalValue: Double?

    public init(
        scatterPoints: [InsightDataPoint],
        movingAveragePoints: [InsightDataPoint],
        color: Color,
        goalValue: Double? = nil
    ) {
        self.scatterPoints = scatterPoints
        self.movingAveragePoints = movingAveragePoints
        self.color = color
        self.goalValue = goalValue
    }

    public var body: some View {
        Chart {
            // Scatter plot of raw data points
            ForEach(scatterPoints) { point in
                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color.opacity(0.4))
                .symbolSize(20)
            }

            // Moving average line
            ForEach(movingAveragePoints) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Moving Avg", point.value)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2))
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
        .transaction { $0.animation = nil }
    }

    /// Y-axis domain including all data and goal value
    private var yAxisDomain: ClosedRange<Double> {
        var values = scatterPoints.map(\.value) + movingAveragePoints.map(\.value)

        if let goal = goalValue {
            values.append(goal)
        }

        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 100

        // Add some padding
        let padding = (maxVal - minVal) * 0.1
        return Swift.max(0, minVal - padding)...(maxVal + padding)
    }
}
