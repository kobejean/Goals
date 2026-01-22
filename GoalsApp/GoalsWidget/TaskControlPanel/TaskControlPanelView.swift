import SwiftUI
import WidgetKit
import GoalsDomain

/// Main view for the Task Control Panel widget
struct TaskControlPanelView: View {
    let entry: TaskControlPanelEntry

    var body: some View {
        VStack(spacing: 12) {
            // Top section: Active task status
            ActiveTaskStatusView(activeSession: entry.activeSession)

            // Bottom section: Task button grid
            if entry.tasks.isEmpty {
                emptyStateView
            } else {
                TaskButtonGrid(
                    tasks: entry.tasks,
                    activeTaskId: entry.activeSession?.taskId
                )
            }
        }
        .padding(12)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.title)
                .foregroundStyle(.secondary)

            Text("No tasks")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Add tasks in the app")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
