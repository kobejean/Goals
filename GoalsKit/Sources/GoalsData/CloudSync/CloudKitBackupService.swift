import CloudKit
import Foundation

/// Service for performing CloudKit backup operations
public actor CloudKitBackupService {
    // MARK: - Properties

    private let container: CKContainer
    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID

    /// Zone name for storing backup records
    public static let backupZoneName = "GoalsBackupZone"

    // MARK: - Initialization

    public init(containerIdentifier: String? = nil) {
        if let identifier = containerIdentifier {
            self.container = CKContainer(identifier: identifier)
        } else {
            self.container = CKContainer.default()
        }
        self.database = container.privateCloudDatabase
        self.zoneID = CKRecordZone.ID(
            zoneName: Self.backupZoneName,
            ownerName: CKCurrentUserDefaultName
        )
    }

    // MARK: - Zone Setup

    /// Ensure the custom zone exists (call once on app launch)
    public func setupZone() async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        do {
            _ = try await database.save(zone)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists, that's fine
        }
    }

    // MARK: - Account Status

    /// Check if user is signed in to iCloud
    public func checkAccountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    /// Returns true if the user can use CloudKit backup
    public func isAvailable() async -> Bool {
        do {
            let status = try await checkAccountStatus()
            return status == .available
        } catch {
            return false
        }
    }

    // MARK: - Sync Operations

    /// Process a batch of queued operations
    /// Returns operations that failed and should be retried
    public func processBatch(_ operations: [QueuedOperation]) async -> [QueuedOperation] {
        var failedOperations: [QueuedOperation] = []

        // Separate into saves and deletes
        var recordsToSave: [CKRecord] = []
        var recordIDsToDelete: [CKRecord.ID] = []

        for queued in operations {
            switch queued.operation {
            case .upsert(let recordType, let id, let data, let timestamp):
                let recordID = CKRecord.ID(
                    recordName: id.uuidString,
                    zoneID: zoneID
                )
                let record = CKRecord(recordType: recordType, recordID: recordID)
                record["payload"] = data as CKRecordValue
                record["updatedAt"] = timestamp as CKRecordValue
                recordsToSave.append(record)

            case .delete(_, let id):
                let recordID = CKRecord.ID(
                    recordName: id.uuidString,
                    zoneID: zoneID
                )
                recordIDsToDelete.append(recordID)
            }
        }

        // Perform batch save
        if !recordsToSave.isEmpty {
            do {
                let modifyOperation = CKModifyRecordsOperation(
                    recordsToSave: recordsToSave,
                    recordIDsToDelete: recordIDsToDelete.isEmpty ? nil : recordIDsToDelete
                )
                modifyOperation.savePolicy = .changedKeys
                modifyOperation.isAtomic = false // Allow partial success

                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    modifyOperation.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success:
                            continuation.resume()
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                    self.database.add(modifyOperation)
                }
            } catch {
                // Batch failed entirely, retry all
                for queued in operations {
                    failedOperations.append(
                        queued.withRetry(error: error.localizedDescription)
                    )
                }
            }
        } else if !recordIDsToDelete.isEmpty {
            // Handle deletes only
            do {
                let modifyOperation = CKModifyRecordsOperation(
                    recordsToSave: nil,
                    recordIDsToDelete: recordIDsToDelete
                )
                modifyOperation.isAtomic = false

                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    modifyOperation.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success:
                            continuation.resume()
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                    self.database.add(modifyOperation)
                }
            } catch {
                for queued in operations where queued.operation.isDelete {
                    failedOperations.append(
                        queued.withRetry(error: error.localizedDescription)
                    )
                }
            }
        }

        return failedOperations
    }

    // MARK: - Fetch Operations

    /// Fetch all records of a specific type
    public func fetchAllRecords(ofType recordType: String) async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let (records, nextCursor) = try await fetchRecordsBatch(
                ofType: recordType,
                cursor: cursor
            )
            allRecords.append(contentsOf: records)
            cursor = nextCursor
        } while cursor != nil

        return allRecords
    }

    private func fetchRecordsBatch(
        ofType recordType: String,
        cursor: CKQueryOperation.Cursor?
    ) async throws -> ([CKRecord], CKQueryOperation.Cursor?) {
        if let cursor = cursor {
            let (results, newCursor) = try await database.records(continuingMatchFrom: cursor)
            let records = results.compactMap { try? $0.1.get() }
            return (records, newCursor)
        } else {
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            let (results, newCursor) = try await database.records(
                matching: query,
                inZoneWith: zoneID,
                resultsLimit: CKQueryOperation.maximumResults
            )
            let records = results.compactMap { try? $0.1.get() }
            return (records, newCursor)
        }
    }

    /// Fetch a single record by ID
    public func fetchRecord(
        recordType: String,
        id: UUID
    ) async throws -> CKRecord? {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        do {
            return try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    /// Check if any backup data exists
    public func hasBackupData() async throws -> Bool {
        // Check for any records in the zone
        let recordTypes = ["Goal", "TaskDefinition", "TaskSession", "EarnedBadge"]

        for recordType in recordTypes {
            let query = CKQuery(
                recordType: recordType,
                predicate: NSPredicate(value: true)
            )
            let (results, _) = try await database.records(
                matching: query,
                inZoneWith: zoneID,
                resultsLimit: 1
            )
            if !results.isEmpty {
                return true
            }
        }

        return false
    }

    /// Get record counts by type
    public func getBackupStats() async throws -> [String: Int] {
        var stats: [String: Int] = [:]
        let recordTypes = ["Goal", "TaskDefinition", "TaskSession", "EarnedBadge", "CachedData"]

        for recordType in recordTypes {
            let records = try await fetchAllRecords(ofType: recordType)
            stats[recordType] = records.count
        }

        return stats
    }

    // MARK: - Delete Operations

    /// Delete all backup data (for testing or user request)
    public func deleteAllBackupData() async throws {
        let recordTypes = ["Goal", "TaskDefinition", "TaskSession", "EarnedBadge", "CachedData"]

        for recordType in recordTypes {
            let records = try await fetchAllRecords(ofType: recordType)
            if !records.isEmpty {
                let recordIDs = records.map(\.recordID)

                let modifyOperation = CKModifyRecordsOperation(
                    recordsToSave: nil,
                    recordIDsToDelete: recordIDs
                )
                modifyOperation.isAtomic = false

                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    modifyOperation.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success:
                            continuation.resume()
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                    self.database.add(modifyOperation)
                }
            }
        }
    }
}

// MARK: - CloudKit Container Extension

public extension CKContainer {
    /// Create a CloudKit container for Goals app
    static func goalsContainer() -> CKContainer {
        // Use the default container (configured in entitlements)
        .default()
    }
}
