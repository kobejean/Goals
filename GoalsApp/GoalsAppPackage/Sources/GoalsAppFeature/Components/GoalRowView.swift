import SwiftUI
import GoalsDomain

/// A row view for displaying a goal in a list
public struct GoalRowView: View {
    let goal: Goal
    var relatedBadges: [EarnedBadge]

    public init(goal: Goal, relatedBadges: [EarnedBadge] = []) {
        self.goal = goal
        self.relatedBadges = relatedBadges
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
                    // Data source badge
                    Label(goal.dataSource.displayName, systemImage: goal.dataSource.iconName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Progress text
                    Text(progressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Badge indicator
            if !relatedBadges.isEmpty {
                badgeIndicator
            }

            // Status indicator
            statusIndicator
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var badgeIndicator: some View {
        HStack(spacing: 2) {
            ForEach(relatedBadges.prefix(2)) { badge in
                Image(systemName: badge.symbolName)
                    .font(.caption)
                    .foregroundStyle(tierColor(for: badge.tier))
            }
        }
    }

    private func tierColor(for tier: BadgeTier?) -> Color {
        guard let tier else { return .yellow }
        switch tier {
        case .bronze: return .orange
        case .silver: return .gray
        case .gold: return .yellow
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if goal.isAchieved {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else if goal.isArchived {
            Image(systemName: "archivebox.fill")
                .foregroundStyle(.gray)
        }
        // No chevron needed - NavigationLink provides it
    }

    private var progressText: String {
        let current = Int(goal.currentValue)
        let target = Int(goal.targetValue)
        return "\(current)/\(target) \(goal.unit)"
    }
}

#Preview {
    List {
        GoalRowView(goal: Goal(
            title: "Reach 50 WPM",
            dataSource: .typeQuicker,
            metricKey: "wpm",
            targetValue: 50,
            currentValue: 35,
            unit: "WPM"
        ))

        GoalRowView(goal: Goal(
            title: "Reach 1600 Rating",
            dataSource: .atCoder,
            metricKey: "rating",
            targetValue: 1600,
            currentValue: 1200,
            unit: "",
            color: .purple
        ))

        GoalRowView(goal: Goal(
            title: "95% Accuracy",
            dataSource: .typeQuicker,
            metricKey: "accuracy",
            targetValue: 95,
            currentValue: 95.5,
            unit: "%",
            color: .green
        ))
    }
}
