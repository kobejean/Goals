import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for persisting EarnedBadge entities
@Model
public final class EarnedBadgeModel {
    @Attribute(.unique) public var id: UUID
    public var categoryRawValue: String
    public var tierRawValue: String?
    public var earnCount: Int
    public var currentValue: Int
    public var earnedAt: Date
    public var lastEarnedAt: Date
    public var relatedGoalId: UUID?

    public init(
        id: UUID = UUID(),
        categoryRawValue: String,
        tierRawValue: String? = nil,
        earnCount: Int = 1,
        currentValue: Int = 0,
        earnedAt: Date = Date(),
        lastEarnedAt: Date = Date(),
        relatedGoalId: UUID? = nil
    ) {
        self.id = id
        self.categoryRawValue = categoryRawValue
        self.tierRawValue = tierRawValue
        self.earnCount = earnCount
        self.currentValue = currentValue
        self.earnedAt = earnedAt
        self.lastEarnedAt = lastEarnedAt
        self.relatedGoalId = relatedGoalId
    }
}

// MARK: - Domain Conversion

public extension EarnedBadgeModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> EarnedBadge {
        EarnedBadge(
            id: id,
            category: BadgeCategory(rawValue: categoryRawValue) ?? .firstGoal,
            tier: tierRawValue.flatMap { BadgeTier(rawValue: $0) },
            earnCount: earnCount,
            currentValue: currentValue,
            earnedAt: earnedAt,
            lastEarnedAt: lastEarnedAt,
            relatedGoalId: relatedGoalId
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ badge: EarnedBadge) -> EarnedBadgeModel {
        EarnedBadgeModel(
            id: badge.id,
            categoryRawValue: badge.category.rawValue,
            tierRawValue: badge.tier?.rawValue,
            earnCount: badge.earnCount,
            currentValue: badge.currentValue,
            earnedAt: badge.earnedAt,
            lastEarnedAt: badge.lastEarnedAt,
            relatedGoalId: badge.relatedGoalId
        )
    }

    /// Updates model from domain entity
    func update(from badge: EarnedBadge) {
        categoryRawValue = badge.category.rawValue
        tierRawValue = badge.tier?.rawValue
        earnCount = badge.earnCount
        currentValue = badge.currentValue
        lastEarnedAt = badge.lastEarnedAt
        relatedGoalId = badge.relatedGoalId
    }
}
