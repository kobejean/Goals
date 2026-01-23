import Foundation

/// Utility for writing widget cache data to shared UserDefaults
public enum WidgetCacheWriter {
    /// App Group identifier for sharing data between app and widgets
    private static let appGroupIdentifier = "group.com.kobejean.goals"

    /// Key for cached task definitions in widget storage
    private static let widgetTasksKey = "widget.tasks"

    /// Key for cached active session in widget storage
    private static let widgetActiveSessionKey = "widget.activeSession"

    /// Write task and session data to shared UserDefaults for widget access
    /// - Parameters:
    ///   - tasks: Array of cached task info
    ///   - activeSession: Currently active session, if any
    public static func write(tasks: [CachedTaskInfo], activeSession: CachedActiveSession?) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

        let encoder = JSONEncoder()

        // Store tasks
        if let tasksData = try? encoder.encode(tasks) {
            defaults.set(tasksData, forKey: widgetTasksKey)
        }

        // Store active session (or remove if nil)
        if let session = activeSession,
           let sessionData = try? encoder.encode(session) {
            defaults.set(sessionData, forKey: widgetActiveSessionKey)
        } else {
            defaults.removeObject(forKey: widgetActiveSessionKey)
        }
    }
}
