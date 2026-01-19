import SwiftUI
import GoalsDomain

/// A subtle toast notification for badge achievements
public struct BadgeToastView: View {
    let notification: BadgeNotification
    let onDismiss: () -> Void

    public init(notification: BadgeNotification, onDismiss: @escaping () -> Void) {
        self.notification = notification
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Badge icon with tier color
            Image(systemName: notification.badge.symbolName)
                .font(.title2)
                .foregroundStyle(tierColor)

            VStack(alignment: .leading, spacing: 2) {
                // Title
                Text(notification.isUpgrade ? "Badge Upgraded!" : "Badge Earned!")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Badge name
                Text(notification.badge.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                // Tier indicator if applicable
                if let tier = notification.badge.tier {
                    Text(tier.displayName)
                        .font(.caption2)
                        .foregroundStyle(tierColor)
                }
            }

            Spacer()

            // Dismiss button
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
        .padding(.horizontal)
    }

    private var tierColor: Color {
        guard let tier = notification.badge.tier else {
            return .yellow // Default for non-tiered badges like first goal
        }

        switch tier {
        case .bronze:
            return .orange
        case .silver:
            return .gray
        case .gold:
            return .yellow
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        BadgeToastView(
            notification: BadgeNotification(
                badge: EarnedBadge(category: .firstGoal, tier: nil),
                isUpgrade: false
            ),
            onDismiss: {}
        )

        BadgeToastView(
            notification: BadgeNotification(
                badge: EarnedBadge(category: .totalGoals, tier: .bronze),
                isUpgrade: false
            ),
            onDismiss: {}
        )

        BadgeToastView(
            notification: BadgeNotification(
                badge: EarnedBadge(category: .totalGoals, tier: .silver),
                isUpgrade: true
            ),
            onDismiss: {}
        )

        BadgeToastView(
            notification: BadgeNotification(
                badge: EarnedBadge(category: .streak, tier: .gold),
                isUpgrade: true
            ),
            onDismiss: {}
        )
    }
    .padding()
}
