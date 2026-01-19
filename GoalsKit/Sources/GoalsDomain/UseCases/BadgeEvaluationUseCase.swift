import Foundation

/// Result of badge evaluation containing newly earned and upgraded badges
public struct BadgeEvaluationResult: Sendable, Equatable {
    public let newlyEarned: [EarnedBadge]
    public let upgraded: [EarnedBadge]

    public init(newlyEarned: [EarnedBadge] = [], upgraded: [EarnedBadge] = []) {
        self.newlyEarned = newlyEarned
        self.upgraded = upgraded
    }

    public var isEmpty: Bool {
        newlyEarned.isEmpty && upgraded.isEmpty
    }

    public var allBadges: [EarnedBadge] {
        newlyEarned + upgraded
    }
}

/// Use case for evaluating and awarding badges
public struct BadgeEvaluationUseCase: Sendable {
    private let goalRepository: GoalRepositoryProtocol
    private let badgeRepository: BadgeRepositoryProtocol

    public init(
        goalRepository: GoalRepositoryProtocol,
        badgeRepository: BadgeRepositoryProtocol
    ) {
        self.goalRepository = goalRepository
        self.badgeRepository = badgeRepository
    }

    /// Evaluates all badge criteria and awards any earned badges
    public func evaluateAll() async throws -> BadgeEvaluationResult {
        var newlyEarned: [EarnedBadge] = []
        var upgraded: [EarnedBadge] = []

        // Fetch current data
        let allGoals = try await goalRepository.fetchAll()
        let achievedGoals = allGoals.filter { $0.isAchieved }

        // Evaluate First Goal badge
        if let result = try await evaluateFirstGoal(goals: allGoals) {
            newlyEarned.append(result)
        }

        // Evaluate Total Goals badges
        if let result = try await evaluateTotalGoals(achievedCount: achievedGoals.count) {
            switch result.1 {
            case .new:
                newlyEarned.append(result.0)
            case .upgraded:
                upgraded.append(result.0)
            }
        }

        return BadgeEvaluationResult(newlyEarned: newlyEarned, upgraded: upgraded)
    }

    /// Evaluates the First Goal badge
    private func evaluateFirstGoal(goals: [Goal]) async throws -> EarnedBadge? {
        guard !goals.isEmpty else { return nil }

        let existingBadge = try await badgeRepository.fetch(category: .firstGoal)
        if existingBadge != nil {
            return nil // Already earned
        }

        let badge = EarnedBadge(
            category: .firstGoal,
            tier: nil,
            earnCount: 1,
            currentValue: 1,
            relatedGoalId: goals.first?.id
        )

        try await badgeRepository.upsert(badge)
        return badge
    }

    /// Result type for badge evaluation
    private enum BadgeChange {
        case new
        case upgraded
    }

    /// Evaluates Total Goals tiered badges
    private func evaluateTotalGoals(achievedCount: Int) async throws -> (EarnedBadge, BadgeChange)? {
        guard achievedCount > 0 else { return nil }

        let existingBadge = try await badgeRepository.fetch(category: .totalGoals)
        let currentTier = existingBadge?.tier

        // Find the highest tier achieved
        guard let highestDefinition = BadgeRegistry.highestTierAchieved(for: .totalGoals, currentValue: achievedCount),
              let newTier = highestDefinition.tier else {
            return nil
        }

        // Check if this is new or an upgrade
        if let existing = existingBadge {
            if let currentTier, newTier > currentTier {
                // Upgrade existing badge
                var upgradedBadge = existing
                upgradedBadge.tier = newTier
                upgradedBadge.currentValue = achievedCount
                upgradedBadge.lastEarnedAt = Date()
                try await badgeRepository.upsert(upgradedBadge)
                return (upgradedBadge, .upgraded)
            }
            // Already have this tier or higher
            return nil
        } else {
            // New badge
            let badge = EarnedBadge(
                category: .totalGoals,
                tier: newTier,
                earnCount: 1,
                currentValue: achievedCount
            )
            try await badgeRepository.upsert(badge)
            return (badge, .new)
        }
    }
}
