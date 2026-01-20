import SwiftUI
import GoalsDomain

/// Main view for the Tasks tab showing task toggle panel and today's totals
public struct TasksView: View {
    @Environment(AppContainer.self) private var container
    @State private var showingSettings = false

    private var viewModel: TasksViewModel {
        container.tasksViewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Task toggle panel
                    if viewModel.tasks.isEmpty {
                        EmptyTasksView {
                            showingSettings = true
                        }
                    } else {
                        TaskTogglePanel(
                            tasks: viewModel.tasks,
                            activeTaskId: viewModel.activeSession?.taskId,
                            todayDurationForTask: { taskId in
                                viewModel.todayDuration(for: taskId)
                            },
                            timerTick: viewModel.timerTick,
                            onToggle: { task in
                                Task {
                                    await viewModel.toggleTask(task)
                                }
                            }
                        )
                    }

                    // Today's summary
                    if !viewModel.tasks.isEmpty {
                        TodaySummarySection(
                            tasks: viewModel.tasks,
                            todayDurationForTask: { taskId in
                                viewModel.todayDuration(for: taskId)
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                TaskSettingsView(
                    tasks: viewModel.tasks,
                    onCreateTask: { task in
                        Task {
                            await viewModel.createTask(task)
                        }
                    },
                    onUpdateTask: { task in
                        Task {
                            await viewModel.updateTask(task)
                        }
                    },
                    onDeleteTask: { task in
                        Task {
                            await viewModel.deleteTask(task)
                        }
                    }
                )
            }
            .task {
                await viewModel.loadData()
            }
        }
    }

    public init() {}
}

/// Empty state view when no tasks exist
private struct EmptyTasksView: View {
    let onAddTask: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Tasks Yet")
                .font(.headline)

            Text("Create tasks to start tracking your time")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                onAddTask()
            } label: {
                Label("Add Task", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 40)
    }
}

/// Section showing today's summary per task
private struct TodaySummarySection: View {
    let tasks: [TaskDefinition]
    let todayDurationForTask: (UUID) -> TimeInterval

    private var totalDuration: TimeInterval {
        tasks.reduce(0) { $0 + todayDurationForTask($1.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Summary")
                    .font(.headline)

                Spacer()

                Text(formatDuration(totalDuration))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ForEach(tasks) { task in
                let duration = todayDurationForTask(task.id)
                if duration > 0 {
                    HStack {
                        Image(systemName: task.icon)
                            .foregroundStyle(task.color.swiftUIColor)
                            .frame(width: 24)

                        Text(task.name)
                            .font(.subheadline)

                        Spacer()

                        Text(formatDuration(duration))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if totalDuration == 0 {
                Text("No time tracked today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "0m"
        }
    }
}

#Preview {
    TasksView()
        .environment(try! AppContainer.preview())
}
