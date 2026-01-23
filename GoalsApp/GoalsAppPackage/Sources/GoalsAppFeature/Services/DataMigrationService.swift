import Foundation
import GoalsWidgetShared

/// Service to handle one-time data migrations
public enum DataMigrationService {
    private static let migrationKey = "hasCompletedSharedStoreMigration_v2"

    /// Migrate data from the old app-private store to the new shared store
    /// This is a one-time migration that runs on first launch after the update
    /// Must be called before creating the ModelContainer
    public static func migrateToSharedStoreIfNeeded() {
        // Check if migration already completed
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            return
        }

        // Reset old migration key if exists (force re-migration)
        UserDefaults.standard.removeObject(forKey: "hasCompletedSharedStoreMigration_v1")

        // Find the old store location (default SwiftData location)
        guard let oldStoreURL = findOldStoreURL(),
              FileManager.default.fileExists(atPath: oldStoreURL.path) else {
            // No old store exists, mark migration as complete
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        guard let newStoreURL = SharedStorage.sharedMainStoreURL else {
            return
        }

        // Check store sizes to decide if migration is needed
        let oldStoreSize = (try? FileManager.default.attributesOfItem(atPath: oldStoreURL.path)[.size] as? Int) ?? 0

        if FileManager.default.fileExists(atPath: newStoreURL.path) {
            let newStoreSize = (try? FileManager.default.attributesOfItem(atPath: newStoreURL.path)[.size] as? Int) ?? 0

            // If old store is larger, it likely has more data - replace new store
            if oldStoreSize > newStoreSize {
                print("📦 Old store (\(oldStoreSize) bytes) larger than new store (\(newStoreSize) bytes), will migrate")
                // Remove new store and associated files
                try? FileManager.default.removeItem(at: newStoreURL)
                try? FileManager.default.removeItem(at: newStoreURL.appendingPathExtension("wal"))
                try? FileManager.default.removeItem(at: newStoreURL.appendingPathExtension("shm"))
            } else if newStoreSize > 32768 { // New store has real data
                UserDefaults.standard.set(true, forKey: migrationKey)
                return
            } else {
                // Remove empty new store to allow copy
                try? FileManager.default.removeItem(at: newStoreURL)
            }
        }

        do {
            try performFileMigration(from: oldStoreURL, to: newStoreURL)
            UserDefaults.standard.set(true, forKey: migrationKey)
            print("✅ Successfully migrated data to shared store")
        } catch {
            print("⚠️ Migration failed: \(error.localizedDescription)")
            // Don't mark as complete so we can retry
        }
    }

    private static func findOldStoreURL() -> URL? {
        // Default SwiftData store location is in Application Support
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        // SwiftData uses "default.store" as the default filename
        let defaultStore = appSupport.appendingPathComponent("default.store")
        if FileManager.default.fileExists(atPath: defaultStore.path) {
            return defaultStore
        }

        return nil
    }

    private static func performFileMigration(from oldStoreURL: URL, to newStoreURL: URL) throws {
        // Ensure the destination directory exists
        let destinationDir = newStoreURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)

        // Copy the main store file
        try FileManager.default.copyItem(at: oldStoreURL, to: newStoreURL)

        // Copy associated files (WAL, SHM) if they exist
        let walURL = oldStoreURL.appendingPathExtension("wal")
        let shmURL = oldStoreURL.appendingPathExtension("shm")

        if FileManager.default.fileExists(atPath: walURL.path) {
            let newWalURL = newStoreURL.appendingPathExtension("wal")
            try? FileManager.default.removeItem(at: newWalURL)
            try FileManager.default.copyItem(at: walURL, to: newWalURL)
        }

        if FileManager.default.fileExists(atPath: shmURL.path) {
            let newShmURL = newStoreURL.appendingPathExtension("shm")
            try? FileManager.default.removeItem(at: newShmURL)
            try FileManager.default.copyItem(at: shmURL, to: newShmURL)
        }

        print("📦 Migrated database files from \(oldStoreURL.path) to \(newStoreURL.path)")
    }
}
