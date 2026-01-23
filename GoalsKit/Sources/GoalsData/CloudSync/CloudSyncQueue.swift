import Foundation

/// Actor for managing the queue of pending CloudKit sync operations
/// Provides crash recovery by persisting the queue to disk
public actor CloudSyncQueue {
    // MARK: - Properties

    private var queue: [QueuedOperation] = []
    private var isProcessing = false
    private var lastSyncAt: Date?
    private var lastError: String?

    private let storageURL: URL
    private let maxRetries: Int
    private let batchSize: Int

    /// Callback invoked when operations need processing
    private var onOperationsReady: (@Sendable ([QueuedOperation]) async -> [QueuedOperation])?

    /// Sets the callback for processing operations
    public func setOperationsHandler(_ handler: @escaping @Sendable ([QueuedOperation]) async -> [QueuedOperation]) {
        onOperationsReady = handler
    }

    // MARK: - Initialization

    public init(
        storageURL: URL,
        maxRetries: Int = 3,
        batchSize: Int = 50
    ) {
        self.storageURL = storageURL
        self.maxRetries = maxRetries
        self.batchSize = batchSize
    }

    /// Load persisted queue from disk
    public func loadFromDisk() async throws {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return
        }

        let data = try Data(contentsOf: storageURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        queue = try decoder.decode([QueuedOperation].self, from: data)
    }

    // MARK: - Queue Management

    /// Enqueue an operation for sync
    public func enqueue(_ operation: SyncOperation) async {
        // Remove any existing operation for the same record (newer replaces older)
        queue.removeAll { existing in
            existing.operation.recordType == operation.recordType &&
            existing.operation.id == operation.id
        }

        let entry = QueuedOperation(operation: operation)
        queue.append(entry)

        await persistToDisk()
    }

    /// Enqueue multiple operations atomically
    public func enqueue(_ operations: [SyncOperation]) async {
        for operation in operations {
            queue.removeAll { existing in
                existing.operation.recordType == operation.recordType &&
                existing.operation.id == operation.id
            }

            let entry = QueuedOperation(operation: operation)
            queue.append(entry)
        }

        await persistToDisk()
    }

    /// Get current sync status
    public func getStatus() -> SyncStatus {
        SyncStatus(
            pendingCount: queue.count,
            lastSyncAt: lastSyncAt,
            lastError: lastError,
            isProcessing: isProcessing
        )
    }

    /// Get pending operation count
    public var pendingCount: Int {
        queue.count
    }

    /// Check if queue is empty
    public var isEmpty: Bool {
        queue.isEmpty
    }

    // MARK: - Processing

    /// Process pending operations in batches
    /// Returns true if all operations were processed successfully
    @discardableResult
    public func processQueue() async -> Bool {
        guard !isProcessing else { return false }
        guard !queue.isEmpty else { return true }
        guard let processor = onOperationsReady else { return false }

        isProcessing = true
        defer { isProcessing = false }

        var allSuccessful = true

        while !queue.isEmpty {
            // Take a batch of operations
            let batch = Array(queue.prefix(batchSize))

            // Process the batch
            let failedOperations = await processor(batch)

            // Remove processed operations
            let processedIds = Set(batch.map(\.id))
            queue.removeAll { processedIds.contains($0.id) }

            // Re-queue failed operations with retry count
            for failed in failedOperations {
                if failed.retryCount < maxRetries {
                    queue.append(failed)
                } else {
                    // Log permanently failed operation
                    lastError = "Operation \(failed.id) exceeded max retries: \(failed.lastError ?? "unknown")"
                    allSuccessful = false
                }
            }

            await persistToDisk()
        }

        if allSuccessful {
            lastSyncAt = Date()
            lastError = nil
        }

        return allSuccessful
    }

    /// Clear the entire queue (use with caution)
    public func clearQueue() async {
        queue.removeAll()
        await persistToDisk()
    }

    /// Remove operations for a specific record type
    public func removeOperations(forRecordType recordType: String) async {
        queue.removeAll { $0.operation.recordType == recordType }
        await persistToDisk()
    }

    // MARK: - Persistence

    private func persistToDisk() async {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(queue)

            // Ensure directory exists
            let directory = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )

            try data.write(to: storageURL, options: .atomic)
        } catch {
            lastError = "Failed to persist queue: \(error.localizedDescription)"
        }
    }
}

// MARK: - Convenience Methods

public extension CloudSyncQueue {
    /// Create an upsert operation for a CloudBackupable entity
    func enqueueUpsert<T: CloudBackupable>(_ entity: T) async where T: Identifiable, T.ID == UUID {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entity)

            let operation = SyncOperation.upsert(
                recordType: T.recordType,
                id: entity.id,
                data: data,
                timestamp: entity.updatedAt
            )

            await enqueue(operation)
        } catch {
            lastError = "Failed to encode entity for sync: \(error.localizedDescription)"
        }
    }

    /// Create a delete operation for a record
    func enqueueDelete(recordType: String, id: UUID) async {
        let operation = SyncOperation.delete(recordType: recordType, id: id)
        await enqueue(operation)
    }
}
