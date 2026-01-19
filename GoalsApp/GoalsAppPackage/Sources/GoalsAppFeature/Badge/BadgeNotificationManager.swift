import Foundation
import GoalsDomain

/// Manages badge notification toast queue and display
@MainActor
@Observable
public final class BadgeNotificationManager {
    /// Currently displayed badge notification
    public private(set) var currentNotification: BadgeNotification?

    /// Queue of pending notifications
    private var notificationQueue: [BadgeNotification] = []

    /// Auto-dismiss duration in seconds
    private let dismissDuration: TimeInterval = 3.0

    /// Active dismiss task
    private var dismissTask: Task<Void, Never>?

    public init() {}

    /// Queues a badge notification for display
    public func showBadge(_ badge: EarnedBadge, isUpgrade: Bool = false) {
        let notification = BadgeNotification(badge: badge, isUpgrade: isUpgrade)
        notificationQueue.append(notification)
        processQueue()
    }

    /// Queues multiple badge notifications
    public func showBadges(from result: BadgeEvaluationResult) {
        for badge in result.newlyEarned {
            let notification = BadgeNotification(badge: badge, isUpgrade: false)
            notificationQueue.append(notification)
        }
        for badge in result.upgraded {
            let notification = BadgeNotification(badge: badge, isUpgrade: true)
            notificationQueue.append(notification)
        }
        processQueue()
    }

    /// Dismisses the current notification
    public func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        currentNotification = nil
        processQueue()
    }

    /// Processes the notification queue
    private func processQueue() {
        guard currentNotification == nil, let next = notificationQueue.first else {
            return
        }

        notificationQueue.removeFirst()
        currentNotification = next

        // Schedule auto-dismiss
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.dismissDuration ?? 3.0))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }
}

/// Represents a badge notification to display
public struct BadgeNotification: Identifiable, Sendable {
    public let id: UUID
    public let badge: EarnedBadge
    public let isUpgrade: Bool

    public init(badge: EarnedBadge, isUpgrade: Bool) {
        self.id = UUID()
        self.badge = badge
        self.isUpgrade = isUpgrade
    }
}
