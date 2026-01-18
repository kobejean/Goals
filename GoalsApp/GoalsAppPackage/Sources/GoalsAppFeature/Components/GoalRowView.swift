import SwiftUI
import GoalsDomain

/// A row view for displaying a goal in a list
public struct GoalRowView: View {
    let goal: Goal

    public init(goal: Goal) {
        self.goal = goal
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Progress ring
            ProgressRingView(
                progress: goal.progress,
                lineWidth: 4,
                size: 44,
                color: goal.color.swiftUIColor
            )

            // Goal info
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // Type badge
                    Label(goal.type.displayName, systemImage: goal.type.iconName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Progress text
                    Text(progressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Status indicator
            statusIndicator
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if goal.isAchieved {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else if goal.isArchived {
            Image(systemName: "archivebox.fill")
                .foregroundStyle(.gray)
        } else {
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
    }

    private var progressText: String {
        switch goal.type {
        case .numeric:
            if let current = goal.currentValue, let target = goal.targetValue, let unit = goal.unit {
                return "\(Int(current))/\(Int(target)) \(unit)"
            }
            return "\(Int(goal.progress * 100))%"

        case .habit:
            if let streak = goal.currentStreak {
                return "\(streak) day streak"
            }
            return "No streak"

        case .milestone:
            return goal.isCompleted ? "Completed" : "In progress"

        case .compound:
            return "\(Int(goal.progress * 100))% complete"
        }
    }
}

#Preview {
    List {
        GoalRowView(goal: Goal(
            title: "Save $10,000",
            type: .numeric,
            targetValue: 10000,
            currentValue: 4500,
            unit: "USD"
        ))

        GoalRowView(goal: Goal(
            title: "Exercise Daily",
            type: .habit,
            frequency: .daily,
            targetCount: 7,
            currentStreak: 5
        ))

        GoalRowView(goal: Goal(
            title: "Run a Marathon",
            type: .milestone,
            isCompleted: true,
            color: .green
        ))

        GoalRowView(goal: Goal(
            title: "Learn Swift",
            type: .milestone,
            color: .purple
        ))
    }
}
