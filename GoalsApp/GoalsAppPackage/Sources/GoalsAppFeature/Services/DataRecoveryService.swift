import Foundation
import GoalsData
import GoalsDomain

/// Service for detecting and recovering data from CloudKit backup
public actor DataRecoveryService {
    private let backupService: CloudKitBackupService
    private let goalRepository: GoalRepositoryProtocol
    private let taskRepository: TaskRepositoryProtocol
    private let badgeRepository: BadgeRepositoryProtocol

    public init(
        backupService: CloudKitBackupService,
        goalRepository: GoalRepositoryProtocol,
        taskRepository: TaskRepositoryProtocol,
        badgeRepository: BadgeRepositoryProtocol
    ) {
        self.backupService = backupService
        self.goalRepository = goalRepository
        self.taskRepository = taskRepository
        self.badgeRepository = badgeRepository
    }

    /// Check if local data store is empty
    public func isLocalDataEmpty() async -> Bool {
        do {
            let goals = try await goalRepository.fetchAll()
            let tasks = try await taskRepository.fetchAllTasks()
            let badges = try await badgeRepository.fetchAll()

            return goals.isEmpty && tasks.isEmpty && badges.isEmpty
        } catch {
            // If we can't fetch, assume not empty to avoid prompting restore
            return false
        }
    }

    /// Check if CloudKit backup has any data
    public func hasBackupData() async -> Bool {
        do {
            return try await backupService.hasBackupData()
        } catch {
            return false
        }
    }

    /// Determine if we should prompt user to restore
    public func shouldPromptRestore() async -> Bool {
        // Only prompt if local is empty AND backup exists
        let localEmpty = await isLocalDataEmpty()
        guard localEmpty else { return false }

        let hasBackup = await hasBackupData()
        return hasBackup
    }

    /// Get backup statistics
    public func getBackupStats() async -> BackupStats? {
        do {
            let stats = try await backupService.getBackupStats()
            return BackupStats(recordCounts: stats)
        } catch {
            return nil
        }
    }

    /// Restore all data from CloudKit backup
    public func restoreFromBackup() async throws -> RestoreResult {
        var result = RestoreResult()

        // Restore Goals
        let goalRecords = try await backupService.fetchAllRecords(ofType: Goal.recordType)
        for record in goalRecords {
            do {
                let goal = try Goal.from(record: record)
                try await goalRepository.create(goal)
                result.goalsRestored += 1
            } catch {
                result.errors.append("Failed to restore goal: \(error.localizedDescription)")
            }
        }

        // Restore TaskDefinitions
        let taskRecords = try await backupService.fetchAllRecords(ofType: TaskDefinition.recordType)
        for record in taskRecords {
            do {
                let task = try TaskDefinition.from(record: record)
                try await taskRepository.createTask(task)
                result.tasksRestored += 1
            } catch {
                result.errors.append("Failed to restore task: \(error.localizedDescription)")
            }
        }

        // Restore TaskSessions
        let sessionRecords = try await backupService.fetchAllRecords(ofType: TaskSession.recordType)
        for record in sessionRecords {
            do {
                let session = try TaskSession.from(record: record)
                try await taskRepository.createSession(session)
                result.sessionsRestored += 1
            } catch {
                result.errors.append("Failed to restore session: \(error.localizedDescription)")
            }
        }

        // Restore Badges
        let badgeRecords = try await backupService.fetchAllRecords(ofType: EarnedBadge.recordType)
        for record in badgeRecords {
            do {
                let badge = try EarnedBadge.from(record: record)
                try await badgeRepository.upsert(badge)
                result.badgesRestored += 1
            } catch {
                result.errors.append("Failed to restore badge: \(error.localizedDescription)")
            }
        }

        return result
    }
}

// MARK: - Supporting Types

/// Statistics about the backup
public struct BackupStats: Sendable, Equatable {
    public let recordCounts: [String: Int]

    public var totalRecords: Int {
        recordCounts.values.reduce(0, +)
    }

    public var goalCount: Int { recordCounts["Goal"] ?? 0 }
    public var taskCount: Int { recordCounts["TaskDefinition"] ?? 0 }
    public var sessionCount: Int { recordCounts["TaskSession"] ?? 0 }
    public var badgeCount: Int { recordCounts["EarnedBadge"] ?? 0 }
    public var cacheCount: Int { recordCounts["CachedData"] ?? 0 }

    public var hasData: Bool { totalRecords > 0 }
}

/// Result of a restore operation
public struct RestoreResult: Sendable {
    public var goalsRestored: Int = 0
    public var tasksRestored: Int = 0
    public var sessionsRestored: Int = 0
    public var badgesRestored: Int = 0
    public var errors: [String] = []

    public var totalRestored: Int {
        goalsRestored + tasksRestored + sessionsRestored + badgesRestored
    }

    public var hasErrors: Bool { !errors.isEmpty }
    public var isSuccess: Bool { totalRestored > 0 && !hasErrors }
}

/// Recovery state for the UI
public enum RecoveryState: Sendable {
    case checking
    case noBackupFound
    case backupAvailable(BackupStats)
    case restoring
    case restored(RestoreResult)
    case error(String)
}
