import SwiftUI

/// A radar chart displaying macro nutrient data (protein, carbs, fat) with current values
/// as a filled polygon and ideal/target values as a dashed outline.
public struct MacroRadarChart: View {
    let current: (protein: Double, carbs: Double, fat: Double)
    let ideal: (protein: Double, carbs: Double, fat: Double)

    public init(
        current: (protein: Double, carbs: Double, fat: Double),
        ideal: (protein: Double, carbs: Double, fat: Double)
    ) {
        self.current = current
        self.ideal = ideal
    }

    // MARK: - Constants

    private let axisCount = 3
    private let guideRingCount = 4
    private let labelOffset: CGFloat = 24

    // Colors
    private let currentColor = Color.teal
    private let idealColor = Color.red
    private let guideColor = Color.gray.opacity(0.3)
    private let axisColor = Color.gray.opacity(0.4)

    // MARK: - Computed Properties

    /// Maximum value across all data points for normalization
    private var maxValue: Double {
        max(
            current.protein, current.carbs, current.fat,
            ideal.protein, ideal.carbs, ideal.fat,
            1
        )
    }

    /// Angles for each axis (top, bottom-right, bottom-left)
    private var axisAngles: [Double] {
        // Start from top (-90°) and go clockwise
        [
            -Double.pi / 2,           // Protein (top)
            -Double.pi / 2 + 2 * Double.pi / 3,  // Carbs (bottom-right)
            -Double.pi / 2 + 4 * Double.pi / 3   // Fat (bottom-left)
        ]
    }

    /// Labels for each axis
    private var axisLabels: [(name: String, value: Double)] {
        [
            ("Protein", current.protein),
            ("Carbs", current.carbs),
            ("Fat", current.fat)
        ]
    }

    // MARK: - Body

    /// Target values formatted for legend display
    private var targetLabel: String {
        "\(Int(ideal.protein))/\(Int(ideal.carbs))/\(Int(ideal.fat))g"
    }

    public var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let radius = (size / 2) - labelOffset - 10

                Canvas { context, _ in
                    // Draw guide rings (concentric triangles)
                    drawGuideRings(context: context, center: center, radius: radius)

                    // Draw axis lines
                    drawAxisLines(context: context, center: center, radius: radius)

                    // Draw ideal polygon (red dashed)
                    drawPolygon(
                        context: context,
                        center: center,
                        radius: radius,
                        values: (ideal.protein, ideal.carbs, ideal.fat),
                        fillColor: nil,
                        strokeColor: idealColor,
                        isDashed: true
                    )

                    // Draw current polygon (filled teal)
                    drawPolygon(
                        context: context,
                        center: center,
                        radius: radius,
                        values: (current.protein, current.carbs, current.fat),
                        fillColor: currentColor.opacity(0.3),
                        strokeColor: currentColor,
                        isDashed: false
                    )
                }

                // Axis labels
                ForEach(0..<axisCount, id: \.self) { index in
                    let angle = axisAngles[index]
                    let labelInfo = axisLabels[index]
                    let labelRadius = radius + labelOffset

                    let x = center.x + labelRadius * CGFloat(cos(angle))
                    let y = center.y + labelRadius * CGFloat(sin(angle))

                    VStack(spacing: 2) {
                        Text(labelInfo.name)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("\(Int(labelInfo.value))g")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                    .position(x: x, y: y)
                }
            }

            // Legend with target values
            HStack(spacing: 12) {
                LegendItem(color: currentColor, label: "Current", isDashed: false)
                LegendItem(color: idealColor, label: "Target (\(targetLabel))", isDashed: true)
            }
            .font(.caption2)
        }
    }

    // MARK: - Drawing Methods

    private func drawGuideRings(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        for i in 1...guideRingCount {
            let ringRadius = radius * CGFloat(i) / CGFloat(guideRingCount)
            let path = createPolygonPath(center: center, radius: ringRadius, values: nil)

            context.stroke(
                path,
                with: .color(guideColor),
                lineWidth: 1
            )
        }
    }

    private func drawAxisLines(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        for angle in axisAngles {
            var path = Path()
            path.move(to: center)
            let endPoint = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
            path.addLine(to: endPoint)

            context.stroke(
                path,
                with: .color(axisColor),
                lineWidth: 1
            )
        }
    }

    private func drawPolygon(
        context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        values: (Double, Double, Double),
        fillColor: Color?,
        strokeColor: Color,
        isDashed: Bool
    ) {
        let path = createPolygonPath(center: center, radius: radius, values: values)

        // Fill if provided
        if let fill = fillColor {
            context.fill(path, with: .color(fill))
        }

        // Stroke
        let strokeStyle = isDashed
            ? StrokeStyle(lineWidth: 2, dash: [5, 3])
            : StrokeStyle(lineWidth: 2)

        context.stroke(path, with: .color(strokeColor), style: strokeStyle)
    }

    private func createPolygonPath(
        center: CGPoint,
        radius: CGFloat,
        values: (Double, Double, Double)?
    ) -> Path {
        var path = Path()

        for (index, angle) in axisAngles.enumerated() {
            let ratio: CGFloat
            if let vals = values {
                let value = index == 0 ? vals.0 : (index == 1 ? vals.1 : vals.2)
                ratio = CGFloat(value / maxValue)
            } else {
                ratio = 1.0
            }

            let pointRadius = radius * ratio
            let point = CGPoint(
                x: center.x + pointRadius * CGFloat(cos(angle)),
                y: center.y + pointRadius * CGFloat(sin(angle))
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Legend Item

private struct LegendItem: View {
    let color: Color
    let label: String
    let isDashed: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isDashed {
                // Dashed line representation
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(color)
                            .frame(width: 4, height: 2)
                    }
                }
                .frame(width: 16)
            } else {
                // Filled circle representation
                Circle()
                    .fill(color.opacity(0.3))
                    .stroke(color, lineWidth: 1.5)
                    .frame(width: 10, height: 10)
            }

            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 32) {
        MacroRadarChart(
            current: (protein: 120, carbs: 200, fat: 50),
            ideal: (protein: 150, carbs: 250, fat: 65)
        )
        .frame(height: 220)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.15)))

        MacroRadarChart(
            current: (protein: 180, carbs: 150, fat: 80),
            ideal: (protein: 150, carbs: 250, fat: 65)
        )
        .frame(height: 220)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.15)))
    }
    .padding()
}
