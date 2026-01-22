import Foundation

/// Centralized UserDefaults keys to avoid magic strings
public enum UserDefaultsKeys {
    public static let typeQuickerUsername = "typeQuickerUsername"
    public static let atCoderUsername = "atCoderUsername"
    public static let ankiHost = "ankiHost"
    public static let ankiPort = "ankiPort"
    public static let ankiDecks = "ankiDecks"

    // Insights card order
    public static let insightsCardOrder = "insightsCardOrder"

    // Insights time range keys (per detail view)
    public static let typeQuickerInsightsTimeRange = "typeQuickerInsightsTimeRange"
    public static let sleepInsightsTimeRange = "sleepInsightsTimeRange"
    public static let tasksInsightsTimeRange = "tasksInsightsTimeRange"
    public static let ankiInsightsTimeRange = "ankiInsightsTimeRange"
    public static let atCoderInsightsTimeRange = "atCoderInsightsTimeRange"
}

// MARK: - UserDefaults Convenience Extensions

public extension UserDefaults {
    var typeQuickerUsername: String? {
        get { string(forKey: UserDefaultsKeys.typeQuickerUsername) }
        set { set(newValue, forKey: UserDefaultsKeys.typeQuickerUsername) }
    }

    var atCoderUsername: String? {
        get { string(forKey: UserDefaultsKeys.atCoderUsername) }
        set { set(newValue, forKey: UserDefaultsKeys.atCoderUsername) }
    }

    var ankiHost: String? {
        get { string(forKey: UserDefaultsKeys.ankiHost) }
        set { set(newValue, forKey: UserDefaultsKeys.ankiHost) }
    }

    var ankiPort: String? {
        get { string(forKey: UserDefaultsKeys.ankiPort) }
        set { set(newValue, forKey: UserDefaultsKeys.ankiPort) }
    }

    var ankiDecks: String? {
        get { string(forKey: UserDefaultsKeys.ankiDecks) }
        set { set(newValue, forKey: UserDefaultsKeys.ankiDecks) }
    }
}
