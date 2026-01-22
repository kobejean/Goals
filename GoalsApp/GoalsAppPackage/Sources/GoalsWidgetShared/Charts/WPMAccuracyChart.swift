import SwiftUI
import Charts

/// Style for WPMAccuracyChart display
public enum WPMAccuracyChartStyle {
    /// Full size with axes, labels, and annotations (for detail views)
    case full
    /// Compact size without axes or annotations (for insight cards)
    case compact
}

/// A 2D scatter/line chart plotting WPM (x-axis) vs Accuracy (y-axis)
/// with temporal fading and goal lines
public struct WPMAccuracyChart: View {
    let data: InsightWPMAccuracyData
    let style: WPMAccuracyChartStyle

    private let movingAverageWindow = 5

    // Style-dependent sizes
    private var defaultSymbolSize: CGFloat {
        style == .compact ? 4 : 6
    }
    private var lastSymbolSize: CGFloat {
        style == .compact ? 7 : 10
    }
    private var lineWidth: CGFloat {
        style == .compact ? 2 : 2.5
    }
    private var openCircleLineWidth: CGFloat {
        style == .compact ? 1.5 : 2
    }
    private var goalLineWidth: CGFloat {
        style == .compact ? 1 : 2
    }
    private var goalLineDash: [CGFloat] {
        style == .compact ? [3, 3] : [5, 5]
    }
    private var goalLineOpacity: Double {
        style == .compact ? 0.6 : 0.8
    }

    public init(data: InsightWPMAccuracyData, style: WPMAccuracyChartStyle = .full) {
        self.data = data
        self.style = style
    }

    public var body: some View {
        Chart {
            // Scatter points with temporal alpha
            ForEach(data.uniqueModes, id: \.self) { mode in
                let points = sortedPoints(for: mode)
                let color = data.color(for: mode)
                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    let isLast = index == points.count - 1
                    let pointAlpha = alpha(for: index, total: points.count)
                    PointMark(
                        x: .value("WPM", point.wpm),
                        y: .value("Accuracy", point.accuracy)
                    )
                    .symbol {
                        if isLast {
                            Circle()
                                .strokeBorder(color, lineWidth: openCircleLineWidth)
                                .frame(width: lastSymbolSize, height: lastSymbolSize)
                        } else {
                            Circle()
                                .fill(color.opacity(pointAlpha))
                                .frame(width: defaultSymbolSize, height: defaultSymbolSize)
                        }
                    }
                }
            }

            // WPM goal line (vertical)
            if let wpmGoal = data.wpmGoal {
                if style == .compact {
                    RuleMark(x: .value("WPM Goal", wpmGoal))
                        .foregroundStyle(.red.opacity(goalLineOpacity))
                        .lineStyle(StrokeStyle(lineWidth: goalLineWidth, dash: goalLineDash))
                } else {
                    RuleMark(x: .value("WPM Goal", wpmGoal))
                        .foregroundStyle(.red.opacity(goalLineOpacity))
                        .lineStyle(StrokeStyle(lineWidth: goalLineWidth, dash: goalLineDash))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("WPM Goal")
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 4)
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                }
            }

            // Accuracy goal line (horizontal)
            if let accuracyGoal = data.accuracyGoal {
                if style == .compact {
                    RuleMark(y: .value("Accuracy Goal", accuracyGoal))
                        .foregroundStyle(.orange.opacity(goalLineOpacity))
                        .lineStyle(StrokeStyle(lineWidth: goalLineWidth, dash: goalLineDash))
                } else {
                    RuleMark(y: .value("Accuracy Goal", accuracyGoal))
                        .foregroundStyle(.orange.opacity(goalLineOpacity))
                        .lineStyle(StrokeStyle(lineWidth: goalLineWidth, dash: goalLineDash))
                        .annotation(position: .trailing, alignment: .top) {
                            Text("Accuracy Goal")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 4)
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                }
            }
        }
        .modifier(ChartStyleModifier(style: style, xAxisRange: xAxisRange, yAxisRange: yAxisRange))
        .chartLegend(.hidden)
        .chartBackground { chart in
            GeometryReader { geometry in
                if let plotFrame = chart.plotFrame {
                    let frame = geometry[plotFrame]

                    ForEach(data.uniqueModes, id: \.self) { mode in
                        MovingAverageLine(
                            points: movingAverage(for: mode),
                            color: data.color(for: mode),
                            chart: chart,
                            plotOrigin: frame.origin,
                            lineWidth: lineWidth
                        )
                    }
                }
            }
        }
    }

    // MARK: - Data Helpers

    private func sortedPoints(for mode: String) -> [InsightWPMAccuracyPoint] {
        data.dataPoints.filter { $0.mode == mode }.sorted { $0.date < $1.date }
    }

    private func alpha(for index: Int, total: Int) -> Double {
        guard total > 1 else { return 1.0 }
        return 0.20 + (0.8 * Double(index) / Double(total - 1))
    }

    private func movingAverage(for mode: String) -> [(wpm: Double, accuracy: Double)] {
        let points = sortedPoints(for: mode)
        guard points.count >= 2 else {
            return points.map { (wpm: $0.wpm, accuracy: $0.accuracy) }
        }

        var result: [(wpm: Double, accuracy: Double)] = []
        for i in 0..<points.count {
            let windowStart = max(0, i - movingAverageWindow + 1)
            let window = points[windowStart...i]
            let avgWpm = window.reduce(0.0) { $0 + $1.wpm } / Double(window.count)
            let avgAcc = window.reduce(0.0) { $0 + $1.accuracy } / Double(window.count)
            result.append((wpm: avgWpm, accuracy: avgAcc))
        }
        return result
    }

    // MARK: - Axis Ranges

    private var xAxisRange: ClosedRange<Double> {
        var values = data.dataPoints.map(\.wpm)
        if let wpmGoal = data.wpmGoal { values.append(wpmGoal) }

        guard let minVal = values.min(), let maxVal = values.max() else {
            return 0...100
        }

        let range = maxVal - minVal
        let padding = max(range * 0.15, 5)
        return max(0, minVal - padding)...(maxVal + padding)
    }

    private var yAxisRange: ClosedRange<Double> {
        var values = data.dataPoints.map(\.accuracy)
        if let accuracyGoal = data.accuracyGoal { values.append(accuracyGoal) }

        guard let minVal = values.min(), let maxVal = values.max() else {
            return 0...100
        }

        let range = maxVal - minVal
        let padding = max(range * 0.15, 1)
        return max(0, minVal - padding)...min(100, maxVal + padding)
    }
}

// MARK: - Chart Style Modifier

private struct ChartStyleModifier: ViewModifier {
    let style: WPMAccuracyChartStyle
    let xAxisRange: ClosedRange<Double>
    let yAxisRange: ClosedRange<Double>

    func body(content: Content) -> some View {
        switch style {
        case .full:
            content
                .frame(height: 200)
                .chartXScale(domain: xAxisRange)
                .chartYScale(domain: yAxisRange)
                .chartXAxisLabel("WPM")
                .chartYAxisLabel("Accuracy (%)")
        case .compact:
            content
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartXScale(domain: xAxisRange)
                .chartYScale(domain: yAxisRange)
        }
    }
}

// MARK: - Moving Average Line

private struct MovingAverageLine: View {
    let points: [(wpm: Double, accuracy: Double)]
    let color: Color
    let chart: ChartProxy
    let plotOrigin: CGPoint
    let lineWidth: CGFloat

    var body: some View {
        Canvas { context, _ in
            guard points.count >= 2 else { return }

            let cgPoints = points.compactMap { point -> CGPoint? in
                guard let x = chart.position(forX: point.wpm),
                      let y = chart.position(forY: point.accuracy) else {
                    return nil
                }
                // Offset by plot origin to align with chart coordinate system
                return CGPoint(x: plotOrigin.x + x, y: plotOrigin.y + y)
            }

            guard cgPoints.count >= 2 else { return }

            let path = createCatmullRomPath(from: cgPoints)

            // Create gradient from first to last point
            let gradient = Gradient(colors: [color.opacity(0.15), color.opacity(1.0)])
            let shading = GraphicsContext.Shading.linearGradient(
                gradient,
                startPoint: cgPoints.first!,
                endPoint: cgPoints.last!
            )

            context.stroke(
                path,
                with: shading,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func createCatmullRomPath(from cgPoints: [CGPoint]) -> Path {
        var path = Path()

        if cgPoints.count == 2 {
            path.move(to: cgPoints[0])
            path.addLine(to: cgPoints[1])
            return path
        }

        // Add phantom points at start and end for Catmull-Rom
        let points = [cgPoints[0]] + cgPoints + [cgPoints[cgPoints.count - 1]]

        path.move(to: points[1])

        for i in 1..<(points.count - 2) {
            let p0 = points[i - 1]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[i + 2]

            let segments = 20
            for t in 1...segments {
                let t = CGFloat(t) / CGFloat(segments)
                let point = catmullRomPoint(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
                path.addLine(to: point)
            }
        }

        return path
    }

    private func catmullRomPoint(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: CGFloat) -> CGPoint {
        let t2 = t * t
        let t3 = t2 * t

        let x = 0.5 * ((2 * p1.x) +
                       (-p0.x + p2.x) * t +
                       (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 +
                       (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3)

        let y = 0.5 * ((2 * p1.y) +
                       (-p0.y + p2.y) * t +
                       (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 +
                       (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)

        return CGPoint(x: x, y: y)
    }
}
