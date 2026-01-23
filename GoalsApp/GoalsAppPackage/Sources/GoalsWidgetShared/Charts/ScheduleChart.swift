import SwiftUI
import Charts

/// Style for ScheduleChart display
public enum ScheduleChartStyle {
    /// Full size with axes, labels, and optional legends/goal lines (for detail views)
    case full
    /// Compact size without axes or annotations (for insight cards)
    case compact
}

/// A horizontal goal line for the schedule chart (used in full mode)
public struct ScheduleGoalLine: Sendable {
    public let value: Double  // Y-axis value (chart coordinates)
    public let label: String
    public let color: Color

    public init(value: Double, label: String, color: Color) {
        self.value = value
        self.label = label
        self.color = color
    }
}

/// A legend item for the schedule chart (used in full mode)
public struct ScheduleLegendItem: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let color: Color

    public init(name: String, color: Color) {
        self.name = name
        self.color = color
    }
}

/// Configuration for full-mode ScheduleChart display
public struct ScheduleChartConfiguration: Sendable {
    public let goalLines: [ScheduleGoalLine]
    public let legendItems: [ScheduleLegendItem]
    public let chartHeight: CGFloat

    public init(
        goalLines: [ScheduleGoalLine] = [],
        legendItems: [ScheduleLegendItem] = [],
        chartHeight: CGFloat = 200
    ) {
        self.goalLines = goalLines
        self.legendItems = legendItems
        self.chartHeight = chartHeight
    }

    /// Default configuration for full mode
    public static let `default` = ScheduleChartConfiguration()
}

/// A unified chart for displaying schedule data (tasks, sleep) with compact and full modes
public struct ScheduleChart: View {
    let data: InsightDurationRangeData
    let style: ScheduleChartStyle
    let configuration: ScheduleChartConfiguration

    public init(
        data: InsightDurationRangeData,
        style: ScheduleChartStyle = .compact,
        configuration: ScheduleChartConfiguration = .default
    ) {
        self.data = data
        self.style = style
        self.configuration = configuration
    }

    public var body: some View {
        switch style {
        case .compact:
            compactChart
        case .full:
            fullChart
        }
    }

    // MARK: - Compact Mode (Widget/Card)

    private var compactChart: some View {
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

    // MARK: - Full Mode (Detail View)

    private var fullChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                ForEach(data.dataPoints) { point in
                    ForEach(point.segments) { segment in
                        RectangleMark(
                            x: .value("Date", point.date, unit: .day),
                            yStart: .value("Start", yValue(for: segment, isStart: true)),
                            yEnd: .value("End", yValue(for: segment, isStart: false)),
                            width: .ratio(0.6)
                        )
                        .foregroundStyle(segment.color.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                // Goal lines
                ForEach(Array(configuration.goalLines.enumerated()), id: \.offset) { _, goalLine in
                    RuleMark(y: .value(goalLine.label, goalLine.value))
                        .foregroundStyle(goalLine.color.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXScale(domain: xAxisDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYScale(domain: yAxisDomain)
            .chartYAxis {
                AxisMarks(values: yAxisValues) { value in
                    if let hour = value.as(Double.self) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            Text(formatHour(hour))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: configuration.chartHeight)

            // Legend
            if !configuration.legendItems.isEmpty {
                legendView
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var legendView: some View {
        FlexibleFlowLayout(spacing: 8) {
            ForEach(configuration.legendItems) { item in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(item.color.gradient)
                        .frame(width: 12, height: 12)
                    Text(item.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

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
        // Add padding for proper bar positioning in full mode
        if style == .full {
            let calendar = Calendar.current
            let paddedStart = calendar.date(byAdding: .hour, value: -12, to: minDate) ?? minDate
            let paddedEnd = calendar.date(byAdding: .hour, value: 18, to: maxDate) ?? maxDate
            return paddedStart...paddedEnd
        }
        return minDate...maxDate
    }

    /// Calculate Y-axis domain from data points
    private var yAxisDomain: ClosedRange<Double> {
        let allSegments = data.dataPoints.flatMap { $0.segments }

        // Get all values (both start and end) to find true min/max
        var allValues: [Double]
        if data.useSimpleHours {
            allValues = allSegments.flatMap { [$0.startHour, $0.endHour] }
        } else {
            allValues = allSegments.flatMap { [$0.startChartValue, $0.endChartValue] }
        }

        // Include goal line values in domain calculation
        for goalLine in configuration.goalLines {
            allValues.append(goalLine.value)
        }

        guard !allValues.isEmpty else {
            // Default domain based on coordinate system
            return data.useSimpleHours ? 6...18 : -2...8
        }

        let minValue = allValues.min() ?? (data.useSimpleHours ? 6.0 : -2.0)
        let maxValue = allValues.max() ?? (data.useSimpleHours ? 18.0 : 8.0)

        if style == .full {
            // Add padding and round to nice values for full mode
            let paddedMin = max(data.useSimpleHours ? 0 : -12, floor(minValue) - 1)
            let paddedMax = min(data.useSimpleHours ? 24 : 14, ceil(maxValue) + 1)
            return paddedMin...paddedMax
        } else {
            // Add small padding for compact mode (minimum 0.5 to avoid zero-height domain)
            let padding = max((maxValue - minValue) * 0.1, 0.5)
            return (minValue - padding)...(maxValue + padding)
        }
    }

    /// Y-axis tick values for full mode
    private var yAxisValues: [Double] {
        let domain = yAxisDomain
        var values: [Double] = []
        var current = ceil(domain.lowerBound / 2) * 2
        while current <= domain.upperBound {
            values.append(current)
            current += 2
        }
        return values
    }

    /// Format hour value for display in axis labels
    private func formatHour(_ hour: Double) -> String {
        var h = Int(hour)
        if h < 0 {
            h += 24
        }
        h = h % 24
        let period = h >= 12 ? "PM" : "AM"
        let displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return "\(displayHour) \(period)"
    }
}

// MARK: - Flow Layout for Legend

/// A simple flow layout that wraps views to new rows when needed
private struct FlexibleFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return (CGSize(width: totalWidth, height: currentY + lineHeight), positions)
    }
}

// MARK: - Previews

#Preview("Compact - Tasks") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    // Sample task data (simple hours)
    let sampleData = (0..<7).map { daysAgo -> DurationRangeDataPoint in
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
        let segments = [
            DurationSegment(
                startTime: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date)!,
                endTime: calendar.date(bySettingHour: 12, minute: 30, second: 0, of: date)!,
                color: .orange
            ),
            DurationSegment(
                startTime: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: date)!,
                endTime: calendar.date(bySettingHour: 17, minute: 0, second: 0, of: date)!,
                color: .blue
            )
        ]
        return DurationRangeDataPoint(date: date, segments: segments)
    }

    return ScheduleChart(
        data: InsightDurationRangeData(
            dataPoints: sampleData.reversed(),
            defaultColor: .orange,
            useSimpleHours: true
        ),
        style: .compact
    )
    .frame(height: 40)
    .padding()
}

#Preview("Full - Tasks") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    let sampleData = (0..<7).map { daysAgo -> DurationRangeDataPoint in
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
        let segments = [
            DurationSegment(
                startTime: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date)!,
                endTime: calendar.date(bySettingHour: 12, minute: 30, second: 0, of: date)!,
                color: .orange,
                label: "Work"
            ),
            DurationSegment(
                startTime: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: date)!,
                endTime: calendar.date(bySettingHour: 17, minute: 0, second: 0, of: date)!,
                color: .blue,
                label: "Study"
            )
        ]
        return DurationRangeDataPoint(date: date, segments: segments)
    }

    return ScheduleChart(
        data: InsightDurationRangeData(
            dataPoints: sampleData.reversed(),
            defaultColor: .orange,
            useSimpleHours: true
        ),
        style: .full,
        configuration: ScheduleChartConfiguration(
            legendItems: [
                ScheduleLegendItem(name: "Work", color: .orange),
                ScheduleLegendItem(name: "Study", color: .blue)
            ],
            chartHeight: 220
        )
    )
    .padding()
}

#Preview("Full - Sleep") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    let sampleData = (0..<7).map { daysAgo -> DurationRangeDataPoint in
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
        let bedtimeHour = 22 + Int.random(in: 0...2)
        let wakeHour = 6 + Int.random(in: 0...2)

        let bedtime = calendar.date(bySettingHour: bedtimeHour, minute: Int.random(in: 0...59), second: 0, of: calendar.date(byAdding: .day, value: -1, to: date)!)!
        let wakeTime = calendar.date(bySettingHour: wakeHour, minute: Int.random(in: 0...59), second: 0, of: date)!

        let segment = DurationSegment(
            startTime: bedtime,
            endTime: wakeTime,
            color: .indigo
        )
        return DurationRangeDataPoint(date: date, segments: [segment])
    }

    // Convert goal times to chart values (PM hours become negative)
    let goalBedtimeValue = 22.0 - 24.0  // 10 PM = -2
    let goalWakeTimeValue = 7.0          // 7 AM = 7

    return ScheduleChart(
        data: InsightDurationRangeData(
            dataPoints: sampleData.reversed(),
            defaultColor: .indigo,
            useSimpleHours: false  // Use overnight scale
        ),
        style: .full,
        configuration: ScheduleChartConfiguration(
            goalLines: [
                ScheduleGoalLine(value: goalBedtimeValue, label: "Bedtime", color: .red),
                ScheduleGoalLine(value: goalWakeTimeValue, label: "Wake", color: .orange)
            ],
            chartHeight: 200
        )
    )
    .padding()
}
