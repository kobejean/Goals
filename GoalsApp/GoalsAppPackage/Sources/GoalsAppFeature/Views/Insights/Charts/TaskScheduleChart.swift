import SwiftUI
import Charts
import GoalsDomain

/// A session segment for the schedule chart
struct ScheduleSegment: Identifiable {
    let id: String
    let date: Date
    let startHour: Double  // Hour of day (0-24)
    let endHour: Double    // Hour of day (0-24)
    let taskId: UUID
    let taskName: String
    let color: Color

    init(date: Date, startHour: Double, endHour: Double, taskId: UUID, taskName: String, color: Color) {
        self.id = "\(date.timeIntervalSince1970)-\(taskId.uuidString)-\(startHour)"
        self.date = date
        self.startHour = startHour
        self.endHour = endHour
        self.taskId = taskId
        self.taskName = taskName
        self.color = color
    }
}

/// Horizontal bar chart showing task sessions by time of day
struct TaskScheduleChart: View {
    let summaries: [TaskDailySummary]
    let tasks: [TaskDefinition]
    let referenceDate: Date

    /// Convert sessions to schedule segments with time of day
    private var segments: [ScheduleSegment] {
        var result: [ScheduleSegment] = []
        let calendar = Calendar.current

        for summary in summaries {
            for session in summary.sessions {
                // Use referenceDate for active sessions
                let endDate = session.endDate ?? referenceDate

                // Skip if session started after reference date
                guard session.startDate <= referenceDate else { continue }

                let task = tasks.first { $0.id == session.taskId }
                let color = task?.color.swiftUIColor ?? .orange
                let name = task?.name ?? "Unknown"

                // Get hour of day as decimal (e.g., 14.5 for 2:30 PM)
                let startComponents = calendar.dateComponents([.hour, .minute], from: session.startDate)
                let endComponents = calendar.dateComponents([.hour, .minute], from: endDate)

                let startHour = Double(startComponents.hour ?? 0) + Double(startComponents.minute ?? 0) / 60.0
                var endHour = Double(endComponents.hour ?? 0) + Double(endComponents.minute ?? 0) / 60.0

                // Handle sessions that cross midnight (end hour would be less than start)
                if endHour < startHour {
                    endHour = 24.0  // Cap at midnight for this day's view
                }

                result.append(ScheduleSegment(
                    date: summary.date,
                    startHour: startHour,
                    endHour: endHour,
                    taskId: session.taskId,
                    taskName: name,
                    color: color
                ))
            }
        }

        return result
    }

    /// Unique tasks that have data for the legend
    private var tasksWithData: [TaskDefinition] {
        let taskIds = Set(segments.map(\.taskId))
        return tasks.filter { taskIds.contains($0.id) }
    }

    /// Calculate Y-axis domain based on actual data
    private var yAxisDomain: ClosedRange<Double> {
        guard !segments.isEmpty else { return 6...22 }

        let minHour = segments.map(\.startHour).min() ?? 6
        let maxHour = segments.map(\.endHour).max() ?? 22

        // Add padding and round to nice values
        let paddedMin = max(0, floor(minHour) - 1)
        let paddedMax = min(24, ceil(maxHour) + 1)

        return paddedMin...paddedMax
    }

    /// Date range for 7 days (with padding for proper bar positioning)
    private var chartDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -6, to: today)!
        // Add padding so bars don't collide with axis labels
        let paddedStart = calendar.date(byAdding: .hour, value: -12, to: startDate)!
        let paddedEnd = calendar.date(byAdding: .hour, value: 18, to: today)!
        return paddedStart...paddedEnd
    }

    /// Segments filtered to last 7 days
    private var recentSegments: [ScheduleSegment] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return segments.filter { $0.date >= cutoff }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Schedule chart with time of day on Y-axis
            Chart {
                ForEach(recentSegments) { segment in
                    RectangleMark(
                        x: .value("Date", segment.date, unit: .day),
                        yStart: .value("Start", segment.startHour),
                        yEnd: .value("End", segment.endHour),
                        width: .ratio(0.6)
                    )
                    .foregroundStyle(segment.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .chartXScale(domain: chartDateRange)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYScale(domain: yAxisDomain)
            .chartYAxis {
                AxisMarks(values: .stride(by: 2)) { value in
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
            .frame(height: 220)

            // Task legend
            if !tasksWithData.isEmpty {
                taskLegend
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatHour(_ hour: Double) -> String {
        let h = Int(hour) % 24
        let period = h >= 12 ? "PM" : "AM"
        let displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return "\(displayHour) \(period)"
    }

    private var taskLegend: some View {
        FlowLayout(spacing: 8) {
            ForEach(tasksWithData) { task in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(task.color.swiftUIColor.gradient)
                        .frame(width: 12, height: 12)
                    Text(task.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    TaskScheduleChart(
        summaries: [],
        tasks: [],
        referenceDate: Date()
    )
    .padding()
}
