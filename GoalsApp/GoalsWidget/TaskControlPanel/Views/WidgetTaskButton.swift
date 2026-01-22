import SwiftUI
import AppIntents
import GoalsDomain
import GoalsWidgetShared

/// A button representing a task in the widget grid
struct WidgetTaskButton: View {
    let task: CachedTaskInfo
    let isActive: Bool

    var body: some View {
        Button(intent: ToggleTaskIntent(taskId: task.id.uuidString)) {
            VStack(spacing: 4) {
                ZStack {
                    // Background circle
                    Circle()
                        .fill(isActive ? task.taskColor.swiftUIColor : task.taskColor.swiftUIColor.opacity(0.2))
                        .frame(width: 36, height: 36)

                    // Icon
                    Image(systemName: task.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isActive ? .white : task.taskColor.swiftUIColor)
                }

                // Task name
                Text(task.name)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(isActive ? task.taskColor.swiftUIColor : .primary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
