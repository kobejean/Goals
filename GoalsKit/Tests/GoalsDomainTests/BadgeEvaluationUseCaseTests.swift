import Testing
import Foundation
@testable import GoalsDomain

@Suite("BadgeEvaluationUseCase Tests")
struct BadgeEvaluationUseCaseTests {

    // MARK: - evaluateAll Tests

    @Test("evaluateAll returns empty when no goals exist")
    func evaluateAllReturnsEmptyWhenNoGoals() async throws {
        let goalRepo = MockGoalRepository(goals: [])
        let badgeRepo = MockBadgeRepository(badges: [])
        let useCase = BadgeEvaluationUseCase(
            goalRepository: goalRepo,
            badgeRepository: badgeRepo
        )

        let result = try await useCase.evaluateAll()

        #expect(result.isEmpty)
        #expect(result.newlyEarned.isEmpty)
        #expect(result.upgraded.isEmpty)
    }

    @Test("evaluateAll combines newly earned and upgraded badges")
    func evaluateAllCombinesBadges() async throws {
        // Create 50 achieved goals for silver upgrade, plus initial goal for firstGoal badge
        let achievedGoals = (0..<50).map { i in
            Goal(
                title: "Goal \(i)",
                dataSource: .typeQuicker,
                metricKey: "wpm",
                targetValue: 100,
                currentValue: 100,
                unit: "WPM"
            )
        }

        // Pre-existing bronze badge to be upgraded
        let bronzeBadge = EarnedBadge(
            category: .totalGoals,
            tier: .bronze,
            currentValue: 10,
            earnedAt: Date().addingTimeInterval(-86400) // 1 day ago
        )

        let goalRepo = MockGoalRepository(goals: achievedGoals)
        let badgeRepo = MockBadgeRepository(badges: [bronzeBadge])
        let useCase = BadgeEvaluationUseCase(
            goalRepository: goalRepo,
            badgeRepository: badgeRepo
        )

        let result = try await useCase.evaluateAll()

        // Should have firstGoal newly earned and totalGoals upgraded
        #expect(result.newlyEarned.count == 1)
        #expect(result.upgraded.count == 1)
        #expect(result.newlyEarned.first?.category == .firstGoal)
        #expect(result.upgraded.first?.category == .totalGoals)
        #expect(result.upgraded.first?.tier == .silver)
    }

    // MARK: - First Goal Badge Tests

    @Test("evaluateFirstGoal awards badge on first goal creation")
    func evaluateFirstGoalAwardsBadge() async throws {
        let goal = Goal(
            title: "My First Goal",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM"
        )

        let goalRepo = MockGoalRepository(goals: [goal])
        let badgeRepo = MockBadgeRepository(badges: [])
        let useCase = BadgeEvaluationUseCase(
            goalRepository: goalRepo,
            badgeRepository: badgeRepo
        )

        let result = try await useCase.evaluateAll()

        #expect(result.newlyEarned.count == 1)
        let badge = result.newlyEarned.first
        #expect(badge?.category == .firstGoal)
        #expect(badge?.tier == nil)
        #expect(badge?.currentValue == 1)
    }

    @Test("evaluateFirstGoal does not duplicate if already earned")
    func evaluateFirstGoalNoDuplicate() async throws {
        let goal = Goal(
            title: "Test Goal",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM"
        )

        let existingBadge = EarnedBadge(
            category: .firstGoal,
            tier: nil,
            currentValue: 1
        )

        let goalRepo = MockGoalRepository(goals: [goal])
        let badgeRepo = MockBadgeRepository(badges: [existingBadge])
        let useCase = BadgeEvaluationUseCase(
            goalRepository: goalRepo,
            badgeRepository: badgeRepo
        )

        let result = try await useCase.evaluateAll()

        // FirstGoal badge should not be awarded again
        let firstGoalBadges = result.newlyEarned.filter { $0.category == .firstGoal }
        #expect(firstGoalBadges.isEmpty)
    }

    @Test("relatedGoalId is set correctly for firstGoal badge")
    func relatedGoalIdSetForFirstGoal() async throws {
        let goalId = UUID()
        let goal = Goal(
            id: goalId,
            title: "My First Goal",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM"
        )

        let goalRepo = MockGoalRepository(goals: [goal])
        let badgeRepo = MockBadgeRepository(badges: [])
        let useCase = BadgeEvaluationUseCase(
            goalRepository: goalRepo,
            badgeRepository: badgeRepo
        )

        let result = try await useCase.evaluateAll()

        let badge = result.newlyEarned.first { $0.category == .firstGoal }
        #expect(badge?.relatedGoalId == goalId)
    }

    // MARK: - Total Goals Badge Tests

    @Test("evaluateTotalGoals awards bronze at 10 achieved goals")
    func evaluateTotalGoalsAwardsBronzeAt10() async throws {
        // Create 10 achieved goals
        let achievedGoals = (0..<10).map { i in
            Goal(
                title: "Goal \(i)",
                dataSource: .typeQuicker,
                metricKey: "wpm",
                targetValue: 100,
                currentValue: 100, // Achieved
                unit: "WPM"
            )
        }

        let goalRepo = MockGoalRepository(goals: achievedGoals)
        let badgeRepo = MockBadgeRepository(badges: [])
        let useCase = BadgeEvaluationUseCase(
            goalRepository: goalRepo,
            badgeRepository: badgeRepo
        )

        let result = try await useCase.evaluateAll()

        let totalGoalsBadge = result.newlyEarned.first { $0.category == .totalGoals }
        #expect(totalGoalsBadge != nil)
        #expect(totalGoalsBadge?.tier == .bronze)
        #expect(totalGoalsBadge?.currentValue == 10)
    }

    @Test("evaluateTotalGoals upgrades bronze to silver at 50 goals")
    func evaluateTotalGoalsUpgradesToSilver() async throws {
        // Create 50 achieved goals
        let achievedGoals = (0..<50).map { i in
            Goal(
                title: "Goal \(i)",
                dataSource: .typeQuicker,
                metricKey: "wpm",
                targetValue: 100,
                currentValue: 100,
                unit: "WPM"
            )
        }

        let bronzeBadge = EarnedBadge(
            category: .totalGoals,
            tier: .bronze,
            currentValue: 10
        )

        let goalRepo = MockGoalRepository(goals: achievedGoals)
        let badgeRepo = MockBadgeRepository(badges: [bronzeBadge])
        let useCase = BadgeEvaluationUseCase(
            goalRepository: goalRepo,
            badgeRepository: badgeRepo
        )

        let result = try await useCase.evaluateAll()

        let upgradedBadge = result.upgraded.first { $0.category == .totalGoals }
        #expect(upgradedBadge != nil)
        #expect(upgradedBadge?.tier == .silver)
        #expect(upgradedBadge?.currentValue == 50)
    }

    @Test("evaluateTotalGoals upgrades silver to gold at 100 goals")
    func evaluateTotalGoalsUpgradesToGold() async throws {
        // Create 100 achieved goals
        let achievedGoals = (0..<100).map { i in
            Goal(
                title: "Goal \(i)",
                dataSource: .typeQuicker,
                metricKey: "wpm",
                targetValue: 100,
                currentValue: 100,
                unit: "WPM"
            )
        }

        let silverBadge = EarnedBadge(
            category: .totalGoals,
            tier: .silver,
            currentValue: 50
        )

        let goalRepo = MockGoalRepository(goals: achievedGoals)
        let badgeRepo = MockBadgeRepository(badges: [silverBadge])
        let useCase = BadgeEvaluationUseCase(
            goalRepository: goalRepo,
            badgeRepository: badgeRepo
        )

        let result = try await useCase.evaluateAll()

        let upgradedBadge = result.upgraded.first { $0.category == .totalGoals }
        #expect(upgradedBadge != nil)
        #expect(upgradedBadge?.tier == .gold)
        #expect(upgradedBadge?.currentValue == 100)
    }

    @Test("evaluateTotalGoals does not downgrade tier")
    func evaluateTotalGoalsNoDowngrade() async throws {
        // Only 5 achieved goals (below bronze threshold)
        let achievedGoals = (0..<5).map { i in
            Goal(
                title: "Goal \(i)",
                dataSource: .typeQuicker,
                metricKey: "wpm",
                targetValue: 100,
                currentValue: 100,
                unit: "WPM"
            )
        }

        // Has bronze badge with higher value from past
        let bronzeBadge = EarnedBadge(
            category: .totalGoals,
            tier: .bronze,
            currentValue: 10
        )

        let goalRepo = MockGoalRepository(goals: achievedGoals)
        let badgeRepo = MockBadgeRepository(badges: [bronzeBadge])
        let useCase = BadgeEvaluationUseCase(
            goalRepository: goalRepo,
            badgeRepository: badgeRepo
        )

        let result = try await useCase.evaluateAll()

        // Should not have any totalGoals in newly earned or upgraded
        let totalGoalsNew = result.newlyEarned.filter { $0.category == .totalGoals }
        let totalGoalsUpgraded = result.upgraded.filter { $0.category == .totalGoals }
        #expect(totalGoalsNew.isEmpty)
        #expect(totalGoalsUpgraded.isEmpty)

        // Original badge should be unchanged
        let badgeInRepo = badgeRepo.badges.first { $0.category == .totalGoals }
        #expect(badgeInRepo?.tier == .bronze)
    }

    @Test("evaluateTotalGoals returns nil for zero achieved goals")
    func evaluateTotalGoalsReturnsNilForZeroAchieved() async throws {
        // Goals with 0 progress (not achieved)
        let unachievedGoals = (0..<5).map { i in
            Goal(
                title: "Goal \(i)",
                dataSource: .typeQuicker,
                metricKey: "wpm",
                targetValue: 100,
                currentValue: 0, // Not achieved
                unit: "WPM"
            )
        }

        let goalRepo = MockGoalRepository(goals: unachievedGoals)
        let badgeRepo = MockBadgeRepository(badges: [])
        let useCase = BadgeEvaluationUseCase(
            goalRepository: goalRepo,
            badgeRepository: badgeRepo
        )

        let result = try await useCase.evaluateAll()

        let totalGoalsBadge = result.newlyEarned.filter { $0.category == .totalGoals }
        #expect(totalGoalsBadge.isEmpty)
    }

    @Test("Badge upgrade preserves original earnedAt date")
    func badgeUpgradePreservesEarnedAt() async throws {
        let originalEarnedAt = Date().addingTimeInterval(-86400 * 30) // 30 days ago

        // Create 50 achieved goals for silver upgrade
        let achievedGoals = (0..<50).map { i in
            Goal(
                title: "Goal \(i)",
                dataSource: .typeQuicker,
                metricKey: "wpm",
                targetValue: 100,
                currentValue: 100,
                unit: "WPM"
            )
        }

        let bronzeBadge = EarnedBadge(
            category: .totalGoals,
            tier: .bronze,
            currentValue: 10,
            earnedAt: originalEarnedAt,
            lastEarnedAt: originalEarnedAt
        )

        let goalRepo = MockGoalRepository(goals: achievedGoals)
        let badgeRepo = MockBadgeRepository(badges: [bronzeBadge])
        let useCase = BadgeEvaluationUseCase(
            goalRepository: goalRepo,
            badgeRepository: badgeRepo
        )

        let result = try await useCase.evaluateAll()

        let upgradedBadge = result.upgraded.first { $0.category == .totalGoals }
        #expect(upgradedBadge?.earnedAt == originalEarnedAt)
    }

    @Test("Badge upgrade updates lastEarnedAt to current date")
    func badgeUpgradeUpdatesLastEarnedAt() async throws {
        let originalDate = Date().addingTimeInterval(-86400 * 30) // 30 days ago
        let now = Date()

        // Create 50 achieved goals for silver upgrade
        let achievedGoals = (0..<50).map { i in
            Goal(
                title: "Goal \(i)",
                dataSource: .typeQuicker,
                metricKey: "wpm",
                targetValue: 100,
                currentValue: 100,
                unit: "WPM"
            )
        }

        let bronzeBadge = EarnedBadge(
            category: .totalGoals,
            tier: .bronze,
            currentValue: 10,
            earnedAt: originalDate,
            lastEarnedAt: originalDate
        )

        let goalRepo = MockGoalRepository(goals: achievedGoals)
        let badgeRepo = MockBadgeRepository(badges: [bronzeBadge])
        let useCase = BadgeEvaluationUseCase(
            goalRepository: goalRepo,
            badgeRepository: badgeRepo
        )

        let result = try await useCase.evaluateAll()

        let upgradedBadge = result.upgraded.first { $0.category == .totalGoals }
        // lastEarnedAt should be updated to approximately now (within 1 second)
        let timeDifference = abs(upgradedBadge!.lastEarnedAt.timeIntervalSince(now))
        #expect(timeDifference < 1.0)
    }
}
