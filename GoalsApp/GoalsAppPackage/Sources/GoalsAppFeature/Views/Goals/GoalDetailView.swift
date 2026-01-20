import SwiftUI
import Charts
import GoalsDomain
import GoalsData

/// Detail view for a single goal showing progress
public struct GoalDetailView: View {
    @Environment(AppContainer.self) private var container
    @State private var goal: Goal
    @State private var linkedTaskName: String?

    public init(goal: Goal) {
        self._goal = State(initialValue: goal)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Progress header
                progressHeader

                // Goal details
                detailsSection
            }
            .padding()
        }
        .navigationTitle(goal.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        Task {
                            try? await container.goalRepository.archive(id: goal.id)
                        }
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await loadData()
        }
    }

    @ViewBuilder
    private var progressHeader: some View {
        VStack(spacing: 16) {
            ProgressRingView(
                progress: goal.progress,
                lineWidth: 16,
                size: 150,
                color: goal.color.swiftUIColor
            )

            Text("\(Int(goal.progress * 100))%")
                .font(.largeTitle)
                .fontWeight(.bold)

            if goal.targetValue > 0 {
                Text("\(formatValue(goal.currentValue)) / \(formatValue(goal.targetValue)) \(goal.unit)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Get the display name for the metric from the data source
    private var metricDisplayName: String {
        container.availableMetrics(for: goal.dataSource)
            .first { $0.key == goal.metricKey }?.name ?? goal.metricKey.capitalized
    }

    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            VStack(spacing: 8) {
                DetailRow(label: "Source", value: goal.dataSource.displayName, icon: goal.dataSource.iconName)
                DetailRow(label: "Metric", value: metricDisplayName, icon: "chart.line.uptrend.xyaxis")

                // Show linked task for task-based goals
                if goal.taskId != nil {
                    DetailRow(
                        label: "Task",
                        value: linkedTaskName ?? "Unknown Task",
                        icon: "checkmark.circle"
                    )
                }

                if let deadline = goal.deadline {
                    DetailRow(
                        label: "Deadline",
                        value: deadline.formatted(date: .abbreviated, time: .omitted),
                        icon: "calendar"
                    )
                }

                DetailRow(
                    label: "Created",
                    value: goal.createdAt.formatted(date: .abbreviated, time: .omitted),
                    icon: "clock"
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func formatValue(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func loadData() async {
        if let updatedGoal = try? await container.goalRepository.fetch(id: goal.id) {
            goal = updatedGoal
        }

        // Load linked task name if this is a per-task goal
        if let taskId = goal.taskId {
            if let task = try? await container.taskRepository.fetchTask(id: taskId) {
                linkedTaskName = task.name
            }
        }
    }
}

/// Detail row component
struct DetailRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
        }
    }
}

#Preview {
    NavigationStack {
        GoalDetailView(goal: Goal(
            title: "Reach 50 WPM",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 50,
            currentValue: 35,
            unit: "WPM"
        ))
    }
    .environment(try! AppContainer.preview())
}
