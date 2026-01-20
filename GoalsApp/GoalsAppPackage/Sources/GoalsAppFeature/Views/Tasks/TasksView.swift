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
                    // Active task banner
                    if let activeTask = viewModel.activeTask,
                       let activeSession = viewModel.activeSession {
                        ActiveTaskBanner(
                            task: activeTask,
                            session: activeSession,
                            timerTick: viewModel.timerTick,
                            onStop: {
                                Task {
                                    await viewModel.toggleTask(activeTask)
                                }
                            }
                        )
                    }

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

/// Banner showing the currently active task with live timer
private struct ActiveTaskBanner: View {
    let task: TaskDefinition
    let session: TaskSession
    let timerTick: Date
    let onStop: () -> Void

    var body: some View {
        HStack {
            Image(systemName: task.icon)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.headline)
                Text("Tracking...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formattedDuration)
                .font(.title2.monospacedDigit().bold())

            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Circle().fill(Color.red))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(task.color.swiftUIColor.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(task.color.swiftUIColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var formattedDuration: String {
        _ = timerTick
        let totalSeconds = Int(session.duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
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
