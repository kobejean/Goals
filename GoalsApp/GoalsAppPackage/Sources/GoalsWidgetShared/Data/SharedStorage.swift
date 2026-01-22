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

    /// URL for the shared SwiftData cache store
    public static var sharedCacheStoreURL: URL? {
        sharedContainerURL?.appendingPathComponent("Library/Application Support/CacheStore.sqlite")
    }
}
