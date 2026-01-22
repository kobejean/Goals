import WidgetKit
import GoalsDomain

/// Timeline entry for the Task Control Panel widget
struct TaskControlPanelEntry: TimelineEntry {
    let date: Date
    let tasks: [CachedTaskInfo]
    let activeSession: CachedActiveSession?

    /// Creates a placeholder entry for widget previews
    static func placeholder() -> TaskControlPanelEntry {
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
}
