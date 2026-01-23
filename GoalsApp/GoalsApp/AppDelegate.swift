import UIKit
import BackgroundTasks
import WidgetKit
import GoalsAppFeature

class AppDelegate: NSObject, UIApplicationDelegate {
    static let backgroundTaskIdentifier = "com.kobejean.goals.refresh"
    static let cloudSyncTaskIdentifier = BackgroundCloudSyncScheduler.cloudSyncTaskIdentifier

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        registerBackgroundTasks()
        return true
    }

    private func registerBackgroundTasks() {
        // Register data source refresh task
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

        // Register CloudKit sync task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.cloudSyncTaskIdentifier,
            using: nil
        ) { @Sendable task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleCloudSync(processingTask)
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

    private func handleCloudSync(_ task: BGProcessingTask) {
        // Schedule next sync
        Self.scheduleCloudSync()

        let syncTask = Task {
            if let scheduler = BackgroundCloudSyncScheduler.shared {
                _ = await scheduler.performBackgroundSync()
                task.setTaskCompleted(success: true)
            } else {
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

    static func scheduleCloudSync() {
        let request = BGProcessingTaskRequest(identifier: cloudSyncTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule cloud sync: \(error)")
        }
    }
}
