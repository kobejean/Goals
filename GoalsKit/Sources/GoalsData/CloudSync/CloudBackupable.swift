import CloudKit
import Foundation

/// Protocol for types that can be backed up to CloudKit
public protocol CloudBackupable: Sendable, Codable {
    /// The CloudKit record type name
    static var recordType: String { get }

    /// Unique identifier for this record
    var cloudRecordID: CKRecord.ID { get }

    /// Timestamp for conflict resolution (last-write-wins)
    var updatedAt: Date { get }

    /// Convert this instance to a CloudKit record
    var cloudRecord: CKRecord { get }

    /// Create an instance from a CloudKit record
    static func from(record: CKRecord) throws -> Self
}

// MARK: - Default Implementation

public extension CloudBackupable where Self: Identifiable, ID == UUID {
    var cloudRecordID: CKRecord.ID {
        CKRecord.ID(recordName: id.uuidString)
    }
}

// MARK: - CloudKit Encoding/Decoding Helpers

public extension CloudBackupable {
    /// Creates a CKRecord with JSON-encoded payload
    /// This approach is more flexible than using individual CKRecord fields
    func encodeToRecord() throws -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: cloudRecordID)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)

        record["payload"] = data as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue

        return record
    }

    /// Decodes an instance from a CKRecord containing JSON payload
    static func decodeFromRecord(_ record: CKRecord) throws -> Self {
        guard let data = record["payload"] as? Data else {
            throw CloudBackupError.missingPayload
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Self.self, from: data)
    }
}

// MARK: - Errors

public enum CloudBackupError: Error, Sendable {
    case missingPayload
    case invalidData(String)
    case encodingFailed(Error)
    case decodingFailed(Error)
    case recordNotFound(CKRecord.ID)
    case cloudKitError(Error)
    case notAuthenticated
    case quotaExceeded
    case networkUnavailable
    case conflict(local: Date, remote: Date)
}

extension CloudBackupError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingPayload:
            return "CloudKit record is missing payload data"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .encodingFailed(let error):
            return "Failed to encode data: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode data: \(error.localizedDescription)"
        case .recordNotFound(let id):
            return "Record not found: \(id.recordName)"
        case .cloudKitError(let error):
            return "CloudKit error: \(error.localizedDescription)"
        case .notAuthenticated:
            return "User is not signed in to iCloud"
        case .quotaExceeded:
            return "iCloud storage quota exceeded"
        case .networkUnavailable:
            return "Network is unavailable"
        case .conflict(let local, let remote):
            return "Sync conflict: local=\(local), remote=\(remote)"
        }
    }
}
