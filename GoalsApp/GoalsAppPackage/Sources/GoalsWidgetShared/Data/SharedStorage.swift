import Foundation

/// Provides access to shared storage between the main app and widgets
public enum SharedStorage {
    /// App Group identifier for sharing data between app and widgets
    public static let appGroupIdentifier = "group.com.kobejean.goals"

    /// Shared UserDefaults for app group
    public static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    /// Shared container URL for app group
    public static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    /// URL for the shared SwiftData store (unified schema)
    public static var sharedMainStoreURL: URL? {
        sharedContainerURL?.appendingPathComponent("Library/Application Support/default.store")
    }

    // MARK: - Task Control Panel Widget Cache Keys

    /// Key for cached task definitions in widget storage
    public static let widgetTasksKey = "widget.tasks"

    /// Key for cached active session in widget storage
    public static let widgetActiveSessionKey = "widget.activeSession"
}
