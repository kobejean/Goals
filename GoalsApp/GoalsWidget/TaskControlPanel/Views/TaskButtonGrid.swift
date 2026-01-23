import SwiftUI
import GoalsDomain

/// Grid of task buttons for the widget
struct TaskButtonGrid: View {
    let tasks: [CachedTaskInfo]
    let activeTaskId: UUID?

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(displayTasks) { task in
                WidgetTaskButton(
                    task: task,
                    isActive: task.id == activeTaskId
                )
            }
        }
    }

    /// Limit to max 8 tasks (2 rows of 4), sorted by sortOrder
    private var displayTasks: [CachedTaskInfo] {
        Array(tasks.sorted { $0.sortOrder < $1.sortOrder }.prefix(8))
    }
}
