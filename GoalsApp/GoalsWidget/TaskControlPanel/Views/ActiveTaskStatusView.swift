import SwiftUI
import GoalsDomain
import GoalsWidgetShared

/// Displays the currently active task with elapsed time
struct ActiveTaskStatusView: View {
    let activeSession: CachedActiveSession?

    var body: some View {
        HStack(spacing: 8) {
            if let session = activeSession {
                // Colored indicator dot
                Circle()
                    .fill(session.taskColor.swiftUIColor)
                    .frame(width: 10, height: 10)

                // Task name
                Text(session.taskName)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                // Live elapsed time - counts up from start date
                // Uses .timer style which auto-updates in widgets
                Text(session.startDate, style: .timer)
                    .multilineTextAlignment(.trailing) // Fix for widget alignment bug
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                // No active task indicator
                Circle()
                    .fill(.secondary.opacity(0.3))
                    .frame(width: 10, height: 10)

                Text("No active task")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Helper Extension

private extension CachedActiveSession {
    var taskColor: TaskColor {
        TaskColor(rawValue: taskColorRaw) ?? .blue
    }
}
