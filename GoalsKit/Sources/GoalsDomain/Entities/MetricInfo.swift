import Foundation

/// Direction for goal progress tracking
public enum GoalDirection: String, Codable, Sendable, CaseIterable {
    /// Goal is achieved by increasing the value (e.g., WPM, rating, study time)
    case increase

    /// Goal is achieved by decreasing the value (e.g., weight, BMI, sugar intake)
    case decrease
}

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

    /// Default direction for this metric (increase or decrease toward target)
    public let direction: GoalDirection

    public init(
        key: String,
        name: String,
        unit: String,
        icon: String,
        direction: GoalDirection = .increase
    ) {
        self.key = key
        self.name = name
        self.unit = unit
        self.icon = icon
        self.direction = direction
    }
}
