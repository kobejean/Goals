import SwiftUI
import Charts

/// A 2D scatter/line chart plotting WPM (x-axis) vs Accuracy (y-axis)
/// with temporal fading and goal lines
struct WPMAccuracyChart: View {
    let dataPoints: [TypeQuickerModeDataPoint]
    let wpmGoal: Double?
    let accuracyGoal: Double?
    let colorForMode: (String) -> Color

    var body: some View {
        Chart {
            // Goal lines only - curved lines drawn as overlay
            // WPM goal line (vertical)
            if let wpmGoal {
                RuleMark(x: .value("WPM Goal", wpmGoal))
                    .foregroundStyle(.red.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("WPM Goal")
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
            }

            // Accuracy goal line (horizontal)
            if let accuracyGoal {
                RuleMark(y: .value("Accuracy Goal", accuracyGoal))
                    .foregroundStyle(.orange.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
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
        .frame(height: 200)
        .chartXScale(domain: xAxisRange)
        .chartYScale(domain: yAxisRange)
        .chartXAxisLabel("WPM")
        .chartYAxisLabel("Accuracy (%)")
        .chartLegend(.hidden)
        .chartBackground { proxy in
            // Draw curved gradient lines for each mode
            ForEach(uniqueModes, id: \.self) { mode in
                CurvedGradientLine(
                    points: sortedPoints(for: mode),
                    color: colorForMode(mode),
                    proxy: proxy
                )
            }
        }
    }

    // MARK: - Data Helpers

    private var uniqueModes: [String] {
        Array(Set(dataPoints.map(\.mode))).sorted()
    }

    private func sortedPoints(for mode: String) -> [TypeQuickerModeDataPoint] {
        dataPoints.filter { $0.mode == mode }.sorted { $0.date < $1.date }
    }

    // MARK: - Axis Ranges

    private var xAxisRange: ClosedRange<Double> {
        var values = dataPoints.map(\.wpm)
        if let wpmGoal { values.append(wpmGoal) }

        guard let minVal = values.min(), let maxVal = values.max() else {
            return 0...100
        }

        let range = maxVal - minVal
        let padding = max(range * 0.15, 5)
        return max(0, minVal - padding)...(maxVal + padding)
    }

    private var yAxisRange: ClosedRange<Double> {
        var values = dataPoints.map(\.accuracy)
        if let accuracyGoal { values.append(accuracyGoal) }

        guard let minVal = values.min(), let maxVal = values.max() else {
            return 0...100
        }

        let range = maxVal - minVal
        let padding = max(range * 0.15, 1)
        return max(0, minVal - padding)...min(100, maxVal + padding)
    }
}

// MARK: - Curved Gradient Line

private struct CurvedGradientLine: View {
    let points: [TypeQuickerModeDataPoint]
    let color: Color
    let proxy: ChartProxy

    var body: some View {
        if points.count >= 2 {
            CatmullRomPath(cgPoints: convertedPoints)
                .stroke(
                    LinearGradient(
                        colors: [color.opacity(0.15), color.opacity(1.0)],
                        startPoint: startPoint,
                        endPoint: endPoint
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
        }
    }

    private var convertedPoints: [CGPoint] {
        points.compactMap { point in
            guard let x = proxy.position(forX: point.wpm),
                  let y = proxy.position(forY: point.accuracy) else {
                return nil
            }
            return CGPoint(x: x, y: y)
        }
    }

    private var startPoint: UnitPoint {
        guard let first = convertedPoints.first else { return .leading }
        let plotArea = proxy.plotSize
        return UnitPoint(x: first.x / plotArea.width, y: first.y / plotArea.height)
    }

    private var endPoint: UnitPoint {
        guard let last = convertedPoints.last else { return .trailing }
        let plotArea = proxy.plotSize
        return UnitPoint(x: last.x / plotArea.width, y: last.y / plotArea.height)
    }
}

// MARK: - Catmull-Rom Spline Path

private struct CatmullRomPath: Shape {
    let cgPoints: [CGPoint]

    func path(in rect: CGRect) -> Path {
        guard cgPoints.count >= 2 else { return Path() }

        var path = Path()

        if cgPoints.count == 2 {
            // Just draw a line for 2 points
            path.move(to: cgPoints[0])
            path.addLine(to: cgPoints[1])
            return path
        }

        // For Catmull-Rom, we need to handle endpoints specially
        // Add phantom points at start and end
        let points = [cgPoints[0]] + cgPoints + [cgPoints[cgPoints.count - 1]]

        path.move(to: points[1])

        for i in 1..<(points.count - 2) {
            let p0 = points[i - 1]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[i + 2]

            // Generate curve segments
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

// MARK: - Preview

#Preview {
    let sampleData = [
        TypeQuickerModeDataPoint(date: Date().addingTimeInterval(-86400 * 7), mode: "code", wpm: 45, accuracy: 92, timeMinutes: 15),
        TypeQuickerModeDataPoint(date: Date().addingTimeInterval(-86400 * 6), mode: "code", wpm: 48, accuracy: 93, timeMinutes: 20),
        TypeQuickerModeDataPoint(date: Date().addingTimeInterval(-86400 * 5), mode: "code", wpm: 50, accuracy: 91, timeMinutes: 18),
        TypeQuickerModeDataPoint(date: Date().addingTimeInterval(-86400 * 4), mode: "code", wpm: 52, accuracy: 94, timeMinutes: 25),
        TypeQuickerModeDataPoint(date: Date().addingTimeInterval(-86400 * 3), mode: "text", wpm: 60, accuracy: 95, timeMinutes: 10),
        TypeQuickerModeDataPoint(date: Date().addingTimeInterval(-86400 * 2), mode: "text", wpm: 62, accuracy: 96, timeMinutes: 12),
        TypeQuickerModeDataPoint(date: Date().addingTimeInterval(-86400 * 1), mode: "code", wpm: 55, accuracy: 95, timeMinutes: 22),
        TypeQuickerModeDataPoint(date: Date(), mode: "text", wpm: 65, accuracy: 97, timeMinutes: 15),
    ]

    return WPMAccuracyChart(
        dataPoints: sampleData,
        wpmGoal: 60,
        accuracyGoal: 95,
        colorForMode: { mode in
            switch mode.lowercased() {
            case "text": return .gray
            case "code": return .accentColor
            default: return .accentColor
            }
        }
    )
    .padding()
}
