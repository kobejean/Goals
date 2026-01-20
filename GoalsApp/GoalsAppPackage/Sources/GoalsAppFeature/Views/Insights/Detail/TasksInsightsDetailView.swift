import SwiftUI
import Charts
import GoalsDomain

/// Tasks insights detail view with charts and breakdown
struct TasksInsightsDetailView: View {
    @Bindable var viewModel: TasksInsightsViewModel
    @State private var timeRange: TimeRange = .month

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Unable to Load", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                } else if viewModel.sessions.isEmpty {
                    emptyStateView
                } else if filteredSummaries.isEmpty {
                    noDataInRangeView
                } else {
                    scheduleChartSection
                    taskDistributionSection
                }
            }
            .padding()
        }
        .navigationTitle("Tasks")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.sessions.isEmpty {
                ToolbarItem(placement: .principal) {
                    Picker("Time Range", selection: $timeRange) {
                        ForEach([TimeRange.week, .month, .quarter, .year, .all], id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
            }
        }
        .task {
            await viewModel.loadData()
            viewModel.startLiveUpdates()
        }
        .onDisappear {
            viewModel.stopLiveUpdates()
        }
    }

    // MARK: - Filtered Data

    private var filteredSummaries: [TaskDailySummary] {
        viewModel.filteredDailySummaries(for: timeRange)
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Task Data")
                .font(.headline)

            Text("Start tracking tasks to see your insights here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var noDataInRangeView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No task data in this range")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let lastDate = viewModel.dailySummaries.last?.date {
                Text("Last tracked: \(lastDate, format: .dateTime.month().day().year())")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Button {
                timeRange = .all
            } label: {
                Text("Show All Data")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var scheduleChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Schedule")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TaskScheduleChart(
                summaries: filteredSummaries,
                tasks: viewModel.tasks,
                referenceDate: viewModel.referenceDate
            )
        }
    }

    private var taskDistributionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time Distribution (\(timeRange.displayName))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TaskDistributionChart(
                summaries: filteredSummaries,
                tasks: viewModel.tasks,
                formatDuration: viewModel.formatDuration
            )
        }
    }
}

// MARK: - Task Schedule Chart (Time of Day)

/// A session segment for the schedule chart
private struct ScheduleSegment: Identifiable {
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

private struct TaskScheduleChart: View {
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
                AxisMarks(values: .stride(by: .day, count: 1)) { value in
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

// MARK: - Flow Layout for Legend

private struct FlowLayout: Layout {
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

// MARK: - Task Distribution Chart (Pie Chart)

private struct TaskDistributionChart: View {
    let summaries: [TaskDailySummary]
    let tasks: [TaskDefinition]
    let formatDuration: (TimeInterval) -> String

    private var taskTotals: [(task: TaskDefinition, duration: TimeInterval)] {
        var totals: [UUID: TimeInterval] = [:]

        for summary in summaries {
            for (taskId, sessions) in summary.sessionsByTask {
                totals[taskId, default: 0] += sessions.totalDuration
            }
        }

        return tasks.compactMap { task in
            guard let duration = totals[task.id], duration > 0 else { return nil }
            return (task: task, duration: duration)
        }.sorted { $0.duration > $1.duration }
    }

    private var totalDuration: TimeInterval {
        taskTotals.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        VStack(spacing: 16) {
            if taskTotals.isEmpty {
                Text("No task data in selected range")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                HStack(alignment: .center, spacing: 24) {
                    // Pie chart
                    Chart(taskTotals, id: \.task.id) { item in
                        SectorMark(
                            angle: .value("Duration", item.duration),
                            innerRadius: .ratio(0.5),
                            angularInset: 1.5
                        )
                        .foregroundStyle(item.task.color.swiftUIColor.gradient)
                        .cornerRadius(4)
                    }
                    .frame(width: 140, height: 140)

                    // Legend with stats
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(taskTotals, id: \.task.id) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.task.color.swiftUIColor.gradient)
                                    .frame(width: 10, height: 10)

                                Text(item.task.name)
                                    .font(.caption)
                                    .lineLimit(1)

                                Spacer()

                                Text(formatDuration(item.duration))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()
                            .padding(.vertical, 4)

                        HStack {
                            Text("Total")
                                .font(.caption.bold())
                            Spacer()
                            Text(formatDuration(totalDuration))
                                .font(.caption.bold().monospacedDigit())
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TasksInsightsDetailView(
            viewModel: TasksInsightsViewModel(
                taskRepository: PreviewTaskRepository(),
                goalRepository: PreviewGoalRepository()
            )
        )
    }
}

// MARK: - Preview Repository

private struct PreviewTaskRepository: TaskRepositoryProtocol {
    func fetchAllTasks() async throws -> [TaskDefinition] { [] }
    func fetchActiveTasks() async throws -> [TaskDefinition] { [] }
    func fetchTask(id: UUID) async throws -> TaskDefinition? { nil }
    func createTask(_ task: TaskDefinition) async throws -> TaskDefinition { task }
    func updateTask(_ task: TaskDefinition) async throws -> TaskDefinition { task }
    func deleteTask(id: UUID) async throws {}
    func fetchActiveSession() async throws -> TaskSession? { nil }
    func startSession(taskId: UUID) async throws -> TaskSession { TaskSession(taskId: taskId) }
    func stopSession(id: UUID) async throws -> TaskSession { TaskSession(taskId: UUID()) }
    func fetchSessions(from: Date, to: Date) async throws -> [TaskSession] { [] }
    func fetchSessions(taskId: UUID) async throws -> [TaskSession] { [] }
    func deleteSession(id: UUID) async throws {}
}
