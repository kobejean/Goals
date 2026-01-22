import SwiftUI
import Charts
import GoalsDomain

/// Donut chart showing time distribution across tasks
struct TaskDistributionChart: View {
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

#Preview {
    TaskDistributionChart(
        summaries: [],
        tasks: [],
        formatDuration: { "\(Int($0 / 60))m" }
    )
    .padding()
}
