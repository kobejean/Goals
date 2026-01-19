import Testing
import Foundation
@testable import GoalsDomain

@Suite("Goal Entity Tests")
struct GoalTests {

    @Test("Goal calculates progress correctly")
    func goalProgress() {
        let goal = Goal(
            title: "Reach 100 WPM",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            currentValue: 25,
            unit: "WPM"
        )

        #expect(goal.progress == 0.25)
        #expect(!goal.isAchieved)
    }

    @Test("Goal with 100% progress is achieved")
    func goalAchieved() {
        let goal = Goal(
            title: "Reach 100 WPM",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            currentValue: 100,
            unit: "WPM"
        )

        #expect(goal.progress == 1.0)
        #expect(goal.isAchieved)
    }

    @Test("Goal with excess progress caps at 100%")
    func goalExcessProgress() {
        let goal = Goal(
            title: "Reach 100 WPM",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            currentValue: 150,
            unit: "WPM"
        )

        #expect(goal.progress == 1.0)
        #expect(goal.isAchieved)
    }

    @Test("Goal with zero target value handles progress gracefully")
    func goalZeroTarget() {
        let goal = Goal(
            title: "Zero Target",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 0,
            currentValue: 50,
            unit: "WPM"
        )

        #expect(goal.progress == 0.0)
        #expect(!goal.isAchieved)
    }

    @Test("Goal with zero current value has zero progress")
    func goalZeroCurrent() {
        let goal = Goal(
            title: "Fresh Goal",
            dataSource: .atCoder,
            metricKey: "rating",
            targetValue: 1600,
            currentValue: 0,
            unit: ""
        )

        #expect(goal.progress == 0.0)
        #expect(!goal.isAchieved)
    }

    @Test("Goal color has correct display names")
    func goalColorDisplayNames() {
        #expect(GoalColor.blue.displayName == "Blue")
        #expect(GoalColor.green.displayName == "Green")
        #expect(GoalColor.orange.displayName == "Orange")
        #expect(GoalColor.purple.displayName == "Purple")
        #expect(GoalColor.red.displayName == "Red")
        #expect(GoalColor.pink.displayName == "Pink")
        #expect(GoalColor.yellow.displayName == "Yellow")
        #expect(GoalColor.teal.displayName == "Teal")
    }

    @Test("Goal is Equatable")
    func goalEquatable() {
        let id = UUID()
        let date = Date()

        let goal1 = Goal(
            id: id,
            title: "Test Goal",
            dataSource: .typeQuicker,
            createdAt: date,
            updatedAt: date,
            metricKey: "wpm",
            targetValue: 100,
            currentValue: 50,
            unit: "WPM"
        )

        let goal2 = Goal(
            id: id,
            title: "Test Goal",
            dataSource: .typeQuicker,
            createdAt: date,
            updatedAt: date,
            metricKey: "wpm",
            targetValue: 100,
            currentValue: 50,
            unit: "WPM"
        )

        #expect(goal1 == goal2)
    }

    @Test("Goal archived state")
    func goalArchivedState() {
        let activeGoal = Goal(
            title: "Active Goal",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM",
            isArchived: false
        )

        let archivedGoal = Goal(
            title: "Archived Goal",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 100,
            unit: "WPM",
            isArchived: true
        )

        #expect(!activeGoal.isArchived)
        #expect(archivedGoal.isArchived)
    }
}
