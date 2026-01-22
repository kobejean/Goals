import UIKit
import BackgroundTasks
import WidgetKit
import GoalsAppFeature

class AppDelegate: NSObject, UIApplicationDelegate {
    static let backgroundTaskIdentifier = "com.kobejean.goals.refresh"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        registerBackgroundTask()
        return true
    }

    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundTaskIdentifier,
            using: nil
        ) { @Sendable task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleBackgroundRefresh(refreshTask)
        }
    }

    private func handleBackgroundRefresh(_ task: BGAppRefreshTask) {
        // Schedule next refresh first
        Self.scheduleBackgroundRefresh()

        let syncTask = Task {
            do {
                let service = try BackgroundSyncService()
                try await service.performSync()
                task.setTaskCompleted(success: true)
            } catch {
                print("Background refresh failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            syncTask.cancel()
        }
    }

    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        // iOS determines actual refresh time; 15 min is minimum hint
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background refresh: \(error)")
        }
    }
}
