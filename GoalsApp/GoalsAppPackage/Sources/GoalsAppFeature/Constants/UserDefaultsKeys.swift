import Foundation
import GoalsWidgetShared

/// Centralized UserDefaults keys to avoid magic strings
public enum UserDefaultsKeys {
    public static let typeQuickerUsername = "typeQuickerUsername"
    public static let atCoderUsername = "atCoderUsername"
    public static let ankiHost = "ankiHost"
    public static let ankiPort = "ankiPort"
    public static let ankiDecks = "ankiDecks"

    // Gemini settings
    public static let geminiAPIKey = "geminiAPIKey"

    // Zotero settings
    public static let zoteroAPIKey = "zoteroAPIKey"
    public static let zoteroUserID = "zoteroUserID"
    public static let zoteroToReadCollection = "zoteroToReadCollection"
    public static let zoteroInProgressCollection = "zoteroInProgressCollection"
    public static let zoteroReadCollection = "zoteroReadCollection"

    // Insights card order
    public static let insightsCardOrder = "insightsCardOrder"

    // Insights fetch throttling
    public static let insightsLastLoadedAt = "insightsLastLoadedAt"

    // Insights time range keys (per detail view)
    public static let typeQuickerInsightsTimeRange = "typeQuickerInsightsTimeRange"
    public static let sleepInsightsTimeRange = "sleepInsightsTimeRange"
    public static let tasksInsightsTimeRange = "tasksInsightsTimeRange"
    public static let locationsInsightsTimeRange = "locationsInsightsTimeRange"
    public static let ankiInsightsTimeRange = "ankiInsightsTimeRange"
    public static let atCoderInsightsTimeRange = "atCoderInsightsTimeRange"
    public static let zoteroInsightsTimeRange = "zoteroInsightsTimeRange"
    public static let wiiFitInsightsTimeRange = "wiiFitInsightsTimeRange"
    public static let tensorTonicInsightsTimeRange = "tensorTonicInsightsTimeRange"

    // Wii Fit settings
    public static let wiiFitIPAddress = "wiiFitIPAddress"
    public static let wiiFitSelectedProfile = "wiiFitSelectedProfile"

    // TensorTonic settings
    public static let tensorTonicUserId = "tensorTonicUserId"
    public static let tensorTonicSessionToken = "tensorTonicSessionToken"

    /// Returns the shared UserDefaults if available, otherwise standard
    public static var shared: UserDefaults {
        SharedStorage.sharedDefaults ?? .standard
    }
}

// MARK: - UserDefaults Convenience Extensions

public extension UserDefaults {
    /// Access the shared UserDefaults suite for app group
    static var shared: UserDefaults {
        SharedStorage.sharedDefaults ?? .standard
    }

    var typeQuickerUsername: String? {
        get { string(forKey: UserDefaultsKeys.typeQuickerUsername) }
        set {
            set(newValue, forKey: UserDefaultsKeys.typeQuickerUsername)
            // Also write to shared defaults for widget access
            UserDefaults.shared.set(newValue, forKey: UserDefaultsKeys.typeQuickerUsername)
        }
    }

    var atCoderUsername: String? {
        get { string(forKey: UserDefaultsKeys.atCoderUsername) }
        set {
            set(newValue, forKey: UserDefaultsKeys.atCoderUsername)
            UserDefaults.shared.set(newValue, forKey: UserDefaultsKeys.atCoderUsername)
        }
    }

    var ankiHost: String? {
        get { string(forKey: UserDefaultsKeys.ankiHost) }
        set {
            set(newValue, forKey: UserDefaultsKeys.ankiHost)
            UserDefaults.shared.set(newValue, forKey: UserDefaultsKeys.ankiHost)
        }
    }

    var ankiPort: String? {
        get { string(forKey: UserDefaultsKeys.ankiPort) }
        set {
            set(newValue, forKey: UserDefaultsKeys.ankiPort)
            UserDefaults.shared.set(newValue, forKey: UserDefaultsKeys.ankiPort)
        }
    }

    var ankiDecks: String? {
        get { string(forKey: UserDefaultsKeys.ankiDecks) }
        set {
            set(newValue, forKey: UserDefaultsKeys.ankiDecks)
            UserDefaults.shared.set(newValue, forKey: UserDefaultsKeys.ankiDecks)
        }
    }

    var zoteroAPIKey: String? {
        get { string(forKey: UserDefaultsKeys.zoteroAPIKey) }
        set {
            set(newValue, forKey: UserDefaultsKeys.zoteroAPIKey)
            UserDefaults.shared.set(newValue, forKey: UserDefaultsKeys.zoteroAPIKey)
        }
    }

    var zoteroUserID: String? {
        get { string(forKey: UserDefaultsKeys.zoteroUserID) }
        set {
            set(newValue, forKey: UserDefaultsKeys.zoteroUserID)
            UserDefaults.shared.set(newValue, forKey: UserDefaultsKeys.zoteroUserID)
        }
    }

    var zoteroToReadCollection: String? {
        get { string(forKey: UserDefaultsKeys.zoteroToReadCollection) }
        set {
            set(newValue, forKey: UserDefaultsKeys.zoteroToReadCollection)
            UserDefaults.shared.set(newValue, forKey: UserDefaultsKeys.zoteroToReadCollection)
        }
    }

    var zoteroInProgressCollection: String? {
        get { string(forKey: UserDefaultsKeys.zoteroInProgressCollection) }
        set {
            set(newValue, forKey: UserDefaultsKeys.zoteroInProgressCollection)
            UserDefaults.shared.set(newValue, forKey: UserDefaultsKeys.zoteroInProgressCollection)
        }
    }

    var zoteroReadCollection: String? {
        get { string(forKey: UserDefaultsKeys.zoteroReadCollection) }
        set {
            set(newValue, forKey: UserDefaultsKeys.zoteroReadCollection)
            UserDefaults.shared.set(newValue, forKey: UserDefaultsKeys.zoteroReadCollection)
        }
    }

    var geminiAPIKey: String? {
        get { string(forKey: UserDefaultsKeys.geminiAPIKey) }
        set {
            set(newValue, forKey: UserDefaultsKeys.geminiAPIKey)
            UserDefaults.shared.set(newValue, forKey: UserDefaultsKeys.geminiAPIKey)
        }
    }

    var wiiFitIPAddress: String? {
        get { string(forKey: UserDefaultsKeys.wiiFitIPAddress) }
        set {
            set(newValue, forKey: UserDefaultsKeys.wiiFitIPAddress)
            UserDefaults.shared.set(newValue, forKey: UserDefaultsKeys.wiiFitIPAddress)
        }
    }

    var wiiFitSelectedProfile: String? {
        get { string(forKey: UserDefaultsKeys.wiiFitSelectedProfile) }
        set {
            set(newValue, forKey: UserDefaultsKeys.wiiFitSelectedProfile)
            UserDefaults.shared.set(newValue, forKey: UserDefaultsKeys.wiiFitSelectedProfile)
        }
    }

    var tensorTonicUserId: String? {
        get { string(forKey: UserDefaultsKeys.tensorTonicUserId) }
        set {
            set(newValue, forKey: UserDefaultsKeys.tensorTonicUserId)
            UserDefaults.shared.set(newValue, forKey: UserDefaultsKeys.tensorTonicUserId)
        }
    }

    var tensorTonicSessionToken: String? {
        get { string(forKey: UserDefaultsKeys.tensorTonicSessionToken) }
        set {
            set(newValue, forKey: UserDefaultsKeys.tensorTonicSessionToken)
            UserDefaults.shared.set(newValue, forKey: UserDefaultsKeys.tensorTonicSessionToken)
        }
    }
}
