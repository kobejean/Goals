import WidgetKit
import GoalsDomain
import GoalsWidgetShared

/// Timeline provider for the Task Control Panel widget
struct TaskControlPanelProvider: TimelineProvider {
    typealias Entry = TaskControlPanelEntry

    func placeholder(in context: Context) -> TaskControlPanelEntry {
        TaskControlPanelEntry.placeholder()
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskControlPanelEntry) -> Void) {
        let (tasks, activeSession) = loadData()
        let entry = TaskControlPanelEntry(date: Date(), tasks: tasks, activeSession: activeSession)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskControlPanelEntry>) -> Void) {
        let (tasks, activeSession) = loadData()
        let now = Date()

        let entry = TaskControlPanelEntry(date: now, tasks: tasks, activeSession: activeSession)

        // Periodic refresh to check if active session has changed
        let refreshInterval: Int = activeSession != nil ? 5 : 15 // minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: refreshInterval, to: now) ?? now

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadData() -> (tasks: [CachedTaskInfo], activeSession: CachedActiveSession?) {
        guard let defaults = SharedStorage.sharedDefaults else {
            return ([], nil)
        }

        let decoder = JSONDecoder()

        // Load cached tasks
        var tasks: [CachedTaskInfo] = []
        if let tasksData = defaults.data(forKey: SharedStorage.widgetTasksKey),
           let cachedTasks = try? decoder.decode([CachedTaskInfo].self, from: tasksData) {
            tasks = cachedTasks.sorted { $0.sortOrder < $1.sortOrder }
        }

        // Load active session
        var activeSession: CachedActiveSession?
        if let sessionData = defaults.data(forKey: SharedStorage.widgetActiveSessionKey),
           let session = try? decoder.decode(CachedActiveSession.self, from: sessionData) {
            activeSession = session
        }

        return (tasks, activeSession)
    }
}
