import Foundation
import GoalsDomain

/// Configuration key mapping from UserDefaults key to internal settings key
public struct ConfigKeyMapping: Sendable {
    /// The UserDefaults key to read from
    public let userDefaultsKey: String
    /// The key to use in DataSourceSettings (credentials/options)
    public let settingsKey: String

    public init(_ userDefaultsKey: String, as settingsKey: String) {
        self.userDefaultsKey = userDefaultsKey
        self.settingsKey = settingsKey
    }

    /// Convenience for when both keys are the same
    public init(_ key: String) {
        self.userDefaultsKey = key
        self.settingsKey = key
    }
}

/// Protocol for data sources that can be configured from UserDefaults.
/// Provides a default implementation to load settings from UserDefaults
/// based on declared credential and option key mappings.
public protocol DataSourceConfigurable {
    /// The data source type this configuration is for
    static var dataSourceType: DataSourceType { get }

    /// Mappings for required credentials (UserDefaults key -> settings key)
    /// Settings will only be created if ALL credential keys have non-empty values.
    static var credentialMappings: [ConfigKeyMapping] { get }

    /// Mappings for optional options (UserDefaults key -> settings key)
    /// Empty strings are allowed for options.
    static var optionMappings: [ConfigKeyMapping] { get }
}

public extension DataSourceConfigurable {
    /// Default implementation: no credential mappings
    static var credentialMappings: [ConfigKeyMapping] { [] }

    /// Default implementation: no option mappings
    static var optionMappings: [ConfigKeyMapping] { [] }

    /// Loads DataSourceSettings from UserDefaults based on declared key mappings.
    /// Returns nil if any required credential is missing or empty.
    static func loadSettingsFromUserDefaults() -> DataSourceSettings? {
        var credentials: [String: String] = [:]
        for mapping in credentialMappings {
            guard let value = UserDefaults.standard.string(forKey: mapping.userDefaultsKey), !value.isEmpty else {
                return nil
            }
            credentials[mapping.settingsKey] = value
        }

        var options: [String: String] = [:]
        for mapping in optionMappings {
            options[mapping.settingsKey] = UserDefaults.standard.string(forKey: mapping.userDefaultsKey) ?? ""
        }

        return DataSourceSettings(
            dataSourceType: dataSourceType,
            credentials: credentials,
            options: options
        )
    }
}
