import Foundation

/// Categories of badges that can be earned
public enum BadgeCategory: String, Codable, Sendable, CaseIterable {
    case streak
    case totalGoals
    case firstGoal
    case perfectWeek
}

/// Tier levels for tiered badges
public enum BadgeTier: String, Codable, Sendable, CaseIterable, Comparable {
    case bronze
    case silver
    case gold

    public static func < (lhs: BadgeTier, rhs: BadgeTier) -> Bool {
        let order: [BadgeTier] = [.bronze, .silver, .gold]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }

    public var displayName: String {
        rawValue.capitalized
    }
}

/// Static metadata defining a badge type
public struct BadgeDefinition: Sendable, Equatable {
    public let category: BadgeCategory
    public let name: String
    public let symbolName: String
    public let tier: BadgeTier?
    public let threshold: Int?
    public let descriptionText: String

    public init(
        category: BadgeCategory,
        name: String,
        symbolName: String,
        tier: BadgeTier? = nil,
        threshold: Int? = nil,
        descriptionText: String
    ) {
        self.category = category
        self.name = name
        self.symbolName = symbolName
        self.tier = tier
        self.threshold = threshold
        self.descriptionText = descriptionText
    }
}

/// Registry containing all badge definitions
public enum BadgeRegistry {

    // MARK: - Streak Badges

    public static let streakBronze = BadgeDefinition(
        category: .streak,
        name: "Streak Starter",
        symbolName: "flame.fill",
        tier: .bronze,
        threshold: 7,
        descriptionText: "Maintain a 7-day streak"
    )

    public static let streakSilver = BadgeDefinition(
        category: .streak,
        name: "Streak Master",
        symbolName: "flame.fill",
        tier: .silver,
        threshold: 30,
        descriptionText: "Maintain a 30-day streak"
    )

    public static let streakGold = BadgeDefinition(
        category: .streak,
        name: "Streak Legend",
        symbolName: "flame.fill",
        tier: .gold,
        threshold: 100,
        descriptionText: "Maintain a 100-day streak"
    )

    // MARK: - Total Goals Badges

    public static let totalGoalsBronze = BadgeDefinition(
        category: .totalGoals,
        name: "Goal Achiever",
        symbolName: "checkmark.seal.fill",
        tier: .bronze,
        threshold: 10,
        descriptionText: "Complete 10 goals"
    )

    public static let totalGoalsSilver = BadgeDefinition(
        category: .totalGoals,
        name: "Goal Champion",
        symbolName: "checkmark.seal.fill",
        tier: .silver,
        threshold: 50,
        descriptionText: "Complete 50 goals"
    )

    public static let totalGoalsGold = BadgeDefinition(
        category: .totalGoals,
        name: "Goal Master",
        symbolName: "checkmark.seal.fill",
        tier: .gold,
        threshold: 100,
        descriptionText: "Complete 100 goals"
    )

    // MARK: - One-time Badges

    public static let firstGoal = BadgeDefinition(
        category: .firstGoal,
        name: "First Step",
        symbolName: "star.fill",
        tier: nil,
        threshold: 1,
        descriptionText: "Create your first goal"
    )

    // MARK: - Repeatable Badges

    public static let perfectWeek = BadgeDefinition(
        category: .perfectWeek,
        name: "Perfect Week",
        symbolName: "calendar.badge.checkmark",
        tier: nil,
        threshold: 7,
        descriptionText: "Complete goals 7 days in a row"
    )

    // MARK: - All Badges

    public static let allDefinitions: [BadgeDefinition] = [
        streakBronze, streakSilver, streakGold,
        totalGoalsBronze, totalGoalsSilver, totalGoalsGold,
        firstGoal,
        perfectWeek
    ]

    /// Returns the badge definition for a given category and tier
    public static func definition(for category: BadgeCategory, tier: BadgeTier?) -> BadgeDefinition? {
        allDefinitions.first { $0.category == category && $0.tier == tier }
    }

    /// Returns tiered definitions for a category (sorted by threshold)
    public static func tieredDefinitions(for category: BadgeCategory) -> [BadgeDefinition] {
        allDefinitions
            .filter { $0.category == category && $0.tier != nil }
            .sorted { ($0.threshold ?? 0) < ($1.threshold ?? 0) }
    }

    /// Returns the next tier definition for a category given current value
    public static func nextTier(for category: BadgeCategory, currentValue: Int) -> BadgeDefinition? {
        tieredDefinitions(for: category)
            .first { ($0.threshold ?? 0) > currentValue }
    }

    /// Returns the highest tier achieved for a category given current value
    public static func highestTierAchieved(for category: BadgeCategory, currentValue: Int) -> BadgeDefinition? {
        tieredDefinitions(for: category)
            .filter { ($0.threshold ?? 0) <= currentValue }
            .last
    }
}
