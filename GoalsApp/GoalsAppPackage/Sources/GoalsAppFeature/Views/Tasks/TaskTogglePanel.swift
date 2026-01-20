import SwiftUI
import GoalsDomain

/// A 2-column grid of task toggle buttons
struct TaskTogglePanel: View {
    let tasks: [TaskDefinition]
    let activeTaskId: UUID?
    let todayDurationForTask: (UUID) -> TimeInterval
    let timerTick: Date
    let onToggle: (TaskDefinition) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(tasks) { task in
                TaskToggleButton(
                    task: task,
                    isActive: task.id == activeTaskId,
                    todayDuration: todayDurationForTask(task.id),
                    onToggle: { onToggle(task) },
                    timerTick: timerTick
                )
            }
        }
    }
}

#Preview {
    TaskTogglePanel(
        tasks: [
            TaskDefinition(name: "Reading", color: .blue, icon: "book"),
            TaskDefinition(name: "Piano", color: .purple, icon: "pianokeys"),
            TaskDefinition(name: "Exercise", color: .green, icon: "figure.run"),
            TaskDefinition(name: "Meditation", color: .teal, icon: "brain.head.profile")
        ],
        activeTaskId: nil,
        todayDurationForTask: { _ in 1234 },
        timerTick: Date(),
        onToggle: { _ in }
    )
    .padding()
}
