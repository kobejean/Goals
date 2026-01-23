import SwiftUI
import WidgetKit
import GoalsDomain

/// Interactive widget for toggling tasks directly from the home screen
struct TaskControlPanelWidget: Widget {
    let kind: String = "TaskControlPanelWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: TaskControlPanelProvider()
        ) { entry in
            TaskControlPanelView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Task Control")
        .description("Toggle tasks directly from your home screen.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Previews

#Preview("Active Task", as: .systemMedium) {
    TaskControlPanelWidget()
} timeline: {
    TaskControlPanelEntry(
        date: Date(),
        tasks: [
            CachedTaskInfo(id: UUID(), name: "Work", colorRaw: "blue", icon: "briefcase", sortOrder: 0),
            CachedTaskInfo(id: UUID(), name: "Exercise", colorRaw: "green", icon: "figure.run", sortOrder: 1),
            CachedTaskInfo(id: UUID(), name: "Study", colorRaw: "purple", icon: "book", sortOrder: 2),
            CachedTaskInfo(id: UUID(), name: "Reading", colorRaw: "orange", icon: "book.pages", sortOrder: 3),
            CachedTaskInfo(id: UUID(), name: "Coding", colorRaw: "teal", icon: "chevron.left.forwardslash.chevron.right", sortOrder: 4),
        ],
        activeSession: CachedActiveSession(
            sessionId: UUID(),
            taskId: UUID(),
            taskName: "Work",
            taskColorRaw: "blue",
            startDate: Date().addingTimeInterval(-3600) // 1 hour ago
        )
    )
}

#Preview("No Active Task", as: .systemMedium) {
    TaskControlPanelWidget()
} timeline: {
    TaskControlPanelEntry(
        date: Date(),
        tasks: [
            CachedTaskInfo(id: UUID(), name: "Work", colorRaw: "blue", icon: "briefcase", sortOrder: 0),
            CachedTaskInfo(id: UUID(), name: "Exercise", colorRaw: "green", icon: "figure.run", sortOrder: 1),
            CachedTaskInfo(id: UUID(), name: "Study", colorRaw: "purple", icon: "book", sortOrder: 2),
        ],
        activeSession: nil
    )
}

#Preview("Empty State", as: .systemMedium) {
    TaskControlPanelWidget()
} timeline: {
    TaskControlPanelEntry(
        date: Date(),
        tasks: [],
        activeSession: nil
    )
}
