import SwiftUI
import GoalsDomain
import GoalsWidgetShared

/// Displays the currently active task
struct ActiveTaskStatusView: View {
    let activeSession: CachedActiveSession?

    var body: some View {
        HStack(spacing: 6) {
            if let session = activeSession {
                // Colored indicator dot
                Circle()
                    .fill(session.taskColor.swiftUIColor)
                    .frame(width: 8, height: 8)

                // Task name
                Text(session.taskName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            } else {
                // No active task indicator
                Circle()
                    .fill(.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)

                Text("No active task")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Helper Extension

private extension CachedActiveSession {
    var taskColor: TaskColor {
        TaskColor(rawValue: taskColorRaw) ?? .blue
    }
}
