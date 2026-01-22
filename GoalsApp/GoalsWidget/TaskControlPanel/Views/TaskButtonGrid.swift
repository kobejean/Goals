import SwiftUI
import GoalsDomain

/// Grid of task buttons for the widget
struct TaskButtonGrid: View {
    let tasks: [CachedTaskInfo]
    let activeTaskId: UUID?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(displayTasks) { task in
                WidgetTaskButton(
                    task: task,
                    isActive: task.id == activeTaskId
                )
            }
        }
    }

    /// Limit to max 6 tasks, sorted by sortOrder
    private var displayTasks: [CachedTaskInfo] {
        Array(tasks.sorted { $0.sortOrder < $1.sortOrder }.prefix(6))
    }
}
