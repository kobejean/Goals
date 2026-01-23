import Foundation
import GoalsData

/// Service for processing CloudKit sync operations
/// Background task registration should be done in AppDelegate
public final class BackgroundCloudSyncScheduler: @unchecked Sendable {
    /// Background task identifier for cloud sync
    public static let cloudSyncTaskIdentifier = "com.kobejean.goals.cloudsync"

    /// Shared instance for background task handler
    /// Set once during app initialization, read from background task handler
    public nonisolated(unsafe) static var shared: BackgroundCloudSyncScheduler?

    private let syncQueue: CloudSyncQueue
    private let backupService: CloudKitBackupService

    public init(syncQueue: CloudSyncQueue, backupService: CloudKitBackupService) {
        self.syncQueue = syncQueue
        self.backupService = backupService
    }

    /// Configure the sync queue handler
    /// Call this once during app initialization
    public func configure() async {
        await syncQueue.setOperationsHandler { [backupService] operations in
            await backupService.processBatch(operations)
        }
    }

    /// Process the sync queue
    /// Call this during background execution time
    public func processQueueIfNeeded() async {
        guard await !syncQueue.isEmpty else { return }

        // Check CloudKit availability
        guard await backupService.isAvailable() else {
            print("BackgroundCloudSyncScheduler: CloudKit not available")
            return
        }

        // Set up zone if needed (first run)
        do {
            try await backupService.setupZone()
        } catch {
            print("BackgroundCloudSyncScheduler: Failed to setup zone: \(error)")
            return
        }

        // Process the queue
        let success = await syncQueue.processQueue()
        print("BackgroundCloudSyncScheduler: Queue processed, success: \(success)")
    }

    /// Get current sync status
    public func getStatus() async -> SyncStatus {
        await syncQueue.getStatus()
    }

    /// Force an immediate sync (for manual backup button)
    public func syncNow() async {
        await configure()
        await processQueueIfNeeded()
    }

    /// Perform the background sync operation
    /// Returns true on success
    public func performBackgroundSync() async -> Bool {
        await configure()
        await processQueueIfNeeded()
        return true
    }

    /// Check if there are pending operations
    public func hasPendingOperations() async -> Bool {
        await syncQueue.pendingCount > 0
    }
}
