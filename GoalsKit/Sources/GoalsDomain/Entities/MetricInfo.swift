import Foundation

/// Simple metadata about a trackable metric from a data source
public struct MetricInfo: Identifiable, Sendable, Equatable {
    public var id: String { key }

    /// Unique key identifying this metric (e.g., "wpm", "accuracy")
    public let key: String

    /// Human-readable name (e.g., "Words Per Minute")
    public let name: String

    /// Unit of measurement (e.g., "WPM", "%", "min")
    public let unit: String

    /// SF Symbol name for the icon
    public let icon: String

    public init(
        key: String,
        name: String,
        unit: String,
        icon: String
    ) {
        self.key = key
        self.name = name
        self.unit = unit
        self.icon = icon
    }
}
