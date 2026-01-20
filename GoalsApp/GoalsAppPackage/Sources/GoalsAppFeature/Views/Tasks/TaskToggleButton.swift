import SwiftUI
import GoalsDomain

/// A button for toggling a task's timer
struct TaskToggleButton: View {
    let task: TaskDefinition
    let isActive: Bool
    let todayDuration: TimeInterval
    let onToggle: () -> Void

    /// Timer tick for live updates
    let timerTick: Date

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: task.icon)
                        .font(.title2)
                        .foregroundStyle(isActive ? .white : task.color.swiftUIColor)

                    Spacer()

                    if isActive {
                        Image(systemName: "stop.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                Spacer()

                Text(task.name)
                    .font(.headline)
                    .foregroundStyle(isActive ? .white : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(formattedDuration)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(isActive ? .white.opacity(0.9) : .secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isActive ? task.color.swiftUIColor : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isActive ? Color.clear : task.color.swiftUIColor.opacity(0.3),
                        lineWidth: 2
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(task.name), \(formattedDuration) today")
        .accessibilityHint(isActive ? "Double tap to stop tracking" : "Double tap to start tracking")
    }

    private var formattedDuration: String {
        // Use timerTick to ensure view updates
        _ = timerTick
        let totalSeconds = Int(todayDuration)
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

#Preview {
    VStack {
        TaskToggleButton(
            task: TaskDefinition(name: "Reading", color: .blue, icon: "book"),
            isActive: false,
            todayDuration: 3665,
            onToggle: {},
            timerTick: Date()
        )
        .frame(width: 170)

        TaskToggleButton(
            task: TaskDefinition(name: "Piano Practice", color: .purple, icon: "pianokeys"),
            isActive: true,
            todayDuration: 1234,
            onToggle: {},
            timerTick: Date()
        )
        .frame(width: 170)
    }
    .padding()
}
