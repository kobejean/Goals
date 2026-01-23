import Foundation

/// Represents a pending sync operation to be processed
public enum SyncOperation: Codable, Sendable, Equatable {
    /// Upsert (create or update) a record
    case upsert(recordType: String, id: UUID, data: Data, timestamp: Date)

    /// Delete a record
    case delete(recordType: String, id: UUID)

    /// The record type for this operation
    public var recordType: String {
        switch self {
        case .upsert(let recordType, _, _, _):
            return recordType
        case .delete(let recordType, _):
            return recordType
        }
    }

    /// The record ID for this operation
    public var id: UUID {
        switch self {
        case .upsert(_, let id, _, _):
            return id
        case .delete(_, let id):
            return id
        }
    }

    /// The timestamp for this operation (used for ordering and conflict resolution)
    public var timestamp: Date {
        switch self {
        case .upsert(_, _, _, let timestamp):
            return timestamp
        case .delete(_, _):
            return Date()
        }
    }

    /// Whether this is a delete operation
    public var isDelete: Bool {
        if case .delete = self { return true }
        return false
    }
}

// MARK: - Operation Queue Entry

/// A queued operation with metadata for retry handling
public struct QueuedOperation: Codable, Sendable, Identifiable {
    public let id: UUID
    public let operation: SyncOperation
    public let queuedAt: Date
    public var retryCount: Int
    public var lastAttemptAt: Date?
    public var lastError: String?

    public init(
        id: UUID = UUID(),
        operation: SyncOperation,
        queuedAt: Date = Date(),
        retryCount: Int = 0,
        lastAttemptAt: Date? = nil,
        lastError: String? = nil
    ) {
        self.id = id
        self.operation = operation
        self.queuedAt = queuedAt
        self.retryCount = retryCount
        self.lastAttemptAt = lastAttemptAt
        self.lastError = lastError
    }

    /// Returns a new entry with incremented retry count
    public func withRetry(error: String) -> QueuedOperation {
        QueuedOperation(
            id: id,
            operation: operation,
            queuedAt: queuedAt,
            retryCount: retryCount + 1,
            lastAttemptAt: Date(),
            lastError: error
        )
    }
}

// MARK: - Sync Status

/// Current status of the sync queue
public struct SyncStatus: Sendable, Equatable {
    public let pendingCount: Int
    public let lastSyncAt: Date?
    public let lastError: String?
    public let isProcessing: Bool

    public init(
        pendingCount: Int = 0,
        lastSyncAt: Date? = nil,
        lastError: String? = nil,
        isProcessing: Bool = false
    ) {
        self.pendingCount = pendingCount
        self.lastSyncAt = lastSyncAt
        self.lastError = lastError
        self.isProcessing = isProcessing
    }

    public static let idle = SyncStatus()

    public var hasPendingOperations: Bool {
        pendingCount > 0
    }
}
