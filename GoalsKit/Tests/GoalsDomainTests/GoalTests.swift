import Testing
import Foundation
@testable import GoalsDomain

@Suite("Goal Entity Tests")
struct GoalTests {

    @Test("Numeric goal calculates progress correctly")
    func numericGoalProgress() {
        let goal = Goal(
            title: "Save Money",
            type: .numeric,
            targetValue: 10000,
            currentValue: 2500,
            unit: "USD"
        )

        #expect(goal.progress == 0.25)
        #expect(!goal.isAchieved)
    }

    @Test("Numeric goal with 100% progress is achieved")
    func numericGoalAchieved() {
        let goal = Goal(
            title: "Save Money",
            type: .numeric,
            targetValue: 10000,
            currentValue: 10000,
            unit: "USD"
        )

        #expect(goal.progress == 1.0)
        #expect(goal.isAchieved)
    }

    @Test("Numeric goal with excess progress caps at 100%")
    func numericGoalExcessProgress() {
        let goal = Goal(
            title: "Save Money",
            type: .numeric,
            targetValue: 10000,
            currentValue: 15000,
            unit: "USD"
        )

        #expect(goal.progress == 1.0)
        #expect(goal.isAchieved)
    }

    @Test("Habit goal calculates progress based on streak")
    func habitGoalProgress() {
        let goal = Goal(
            title: "Exercise Daily",
            type: .habit,
            frequency: .weekly,
            targetCount: 5,
            currentStreak: 3
        )

        #expect(goal.progress == 0.6)
        #expect(!goal.isAchieved)
    }

    @Test("Habit goal is achieved when streak meets target")
    func habitGoalAchieved() {
        let goal = Goal(
            title: "Exercise Daily",
            type: .habit,
            frequency: .weekly,
            targetCount: 5,
            currentStreak: 5
        )

        #expect(goal.progress == 1.0)
        #expect(goal.isAchieved)
    }

    @Test("Milestone goal progress is binary")
    func milestoneGoalProgress() {
        let incompleteGoal = Goal(
            title: "Run Marathon",
            type: .milestone
        )

        #expect(incompleteGoal.progress == 0.0)
        #expect(!incompleteGoal.isAchieved)

        let completeGoal = Goal(
            title: "Run Marathon",
            type: .milestone,
            isCompleted: true
        )

        #expect(completeGoal.progress == 1.0)
        #expect(completeGoal.isAchieved)
    }

    @Test("Goal with nil values handles progress gracefully")
    func goalWithNilValues() {
        let goal = Goal(
            title: "Incomplete Goal",
            type: .numeric
        )

        #expect(goal.progress == 0.0)
        #expect(!goal.isAchieved)
    }

    @Test("Goal type has correct display names")
    func goalTypeDisplayNames() {
        #expect(GoalType.numeric.displayName == "Numeric")
        #expect(GoalType.habit.displayName == "Habit")
        #expect(GoalType.milestone.displayName == "Milestone")
        #expect(GoalType.compound.displayName == "Compound")
    }

    @Test("Goal color has correct display names")
    func goalColorDisplayNames() {
        #expect(GoalColor.blue.displayName == "Blue")
        #expect(GoalColor.green.displayName == "Green")
        #expect(GoalColor.orange.displayName == "Orange")
    }
}
