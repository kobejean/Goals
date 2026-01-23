import SwiftUI
import AppIntents
import GoalsDomain
import GoalsWidgetShared

/// A button representing a task in the widget grid
struct WidgetTaskButton: View {
    let task: CachedTaskInfo
    let isActive: Bool

    private let buttonSize: CGFloat = 48

    var body: some View {
        Button(intent: ToggleTaskIntent(taskId: task.id.uuidString)) {
            ZStack {
                // Background circle
                Circle()
                    .fill(task.taskColor.swiftUIColor.opacity(isActive ? 1.0 : 0.15))
                    .frame(width: buttonSize, height: buttonSize)

                // Active ring indicator
                if isActive {
                    Circle()
                        .strokeBorder(task.taskColor.swiftUIColor, lineWidth: 3)
                        .frame(width: buttonSize + 8, height: buttonSize + 8)
                }

                // Icon
                Image(systemName: task.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isActive ? .white : task.taskColor.swiftUIColor)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
