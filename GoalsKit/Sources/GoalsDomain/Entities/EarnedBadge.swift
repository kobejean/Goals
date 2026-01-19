import Foundation
import GoalsCore

/// Represents a badge that has been earned by the user
public struct EarnedBadge: Sendable, Equatable, UUIDIdentifiable {
    public let id: UUID
    public var category: BadgeCategory
    public var tier: BadgeTier?
    public var earnCount: Int
    public var currentValue: Int
    public var earnedAt: Date
    public var lastEarnedAt: Date
    public var relatedGoalId: UUID?

    public init(
        id: UUID = UUID(),
        category: BadgeCategory,
        tier: BadgeTier? = nil,
        earnCount: Int = 1,
        currentValue: Int = 0,
        earnedAt: Date = Date(),
        lastEarnedAt: Date = Date(),
        relatedGoalId: UUID? = nil
    ) {
        self.id = id
        self.category = category
        self.tier = tier
        self.earnCount = earnCount
        self.currentValue = currentValue
        self.earnedAt = earnedAt
        self.lastEarnedAt = lastEarnedAt
        self.relatedGoalId = relatedGoalId
    }

    /// Returns the badge definition for this earned badge
    public var definition: BadgeDefinition? {
        BadgeRegistry.definition(for: category, tier: tier)
    }

    /// Display name of the badge
    public var displayName: String {
        definition?.name ?? category.rawValue.capitalized
    }

    /// SF Symbol name for the badge
    public var symbolName: String {
        definition?.symbolName ?? "questionmark.circle"
    }

    /// Description of the badge
    public var descriptionText: String {
        definition?.descriptionText ?? ""
    }
}
