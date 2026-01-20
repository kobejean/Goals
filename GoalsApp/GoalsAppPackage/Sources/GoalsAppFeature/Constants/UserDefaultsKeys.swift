import Foundation

/// Centralized UserDefaults keys to avoid magic strings
public enum UserDefaultsKeys {
    public static let typeQuickerUsername = "typeQuickerUsername"
    public static let atCoderUsername = "atCoderUsername"
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
}
