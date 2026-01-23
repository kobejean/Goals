import CloudKit
import CryptoKit
import Foundation
import GoalsDomain

// MARK: - Goal + CloudBackupable

extension Goal: CloudBackupable {
    public static var recordType: String { "Goal" }

    public var cloudRecord: CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: cloudRecordID)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(self)
            record["payload"] = data as CKRecordValue
            record["updatedAt"] = updatedAt as CKRecordValue
        } catch {
            // Will be handled by the sync service
        }
        return record
    }

    public static func from(record: CKRecord) throws -> Goal {
        guard let data = record["payload"] as? Data else {
            throw CloudBackupError.missingPayload
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Goal.self, from: data)
    }
}

// MARK: - TaskDefinition + CloudBackupable

extension TaskDefinition: CloudBackupable {
    public static var recordType: String { "TaskDefinition" }

    public var cloudRecord: CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: cloudRecordID)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(self)
            record["payload"] = data as CKRecordValue
            record["updatedAt"] = updatedAt as CKRecordValue
        } catch {
            // Will be handled by the sync service
        }
        return record
    }

    public static func from(record: CKRecord) throws -> TaskDefinition {
        guard let data = record["payload"] as? Data else {
            throw CloudBackupError.missingPayload
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TaskDefinition.self, from: data)
    }
}

// MARK: - TaskSession + CloudBackupable

extension TaskSession: CloudBackupable {
    public static var recordType: String { "TaskSession" }

    public var cloudRecord: CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: cloudRecordID)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(self)
            record["payload"] = data as CKRecordValue
            record["updatedAt"] = updatedAt as CKRecordValue
        } catch {
            // Will be handled by the sync service
        }
        return record
    }

    public static func from(record: CKRecord) throws -> TaskSession {
        guard let data = record["payload"] as? Data else {
            throw CloudBackupError.missingPayload
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TaskSession.self, from: data)
    }
}

// MARK: - EarnedBadge + CloudBackupable

extension EarnedBadge: CloudBackupable {
    public static var recordType: String { "EarnedBadge" }

    public var cloudRecord: CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: cloudRecordID)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(self)
            record["payload"] = data as CKRecordValue
            record["updatedAt"] = updatedAt as CKRecordValue
        } catch {
            // Will be handled by the sync service
        }
        return record
    }

    public static func from(record: CKRecord) throws -> EarnedBadge {
        guard let data = record["payload"] as? Data else {
            throw CloudBackupError.missingPayload
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(EarnedBadge.self, from: data)
    }
}

// MARK: - CacheBackupRecord + CloudBackupable

extension CacheBackupRecord: CloudBackupable {
    public static var recordType: String { "CachedData" }

    public var updatedAt: Date { fetchedAt }

    public var cloudRecordID: CKRecord.ID {
        // Use SHA256 hash of the cache key for stable, deterministic record ID
        let data = Data(cacheKey.utf8)
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        return CKRecord.ID(recordName: hashString)
    }

    public var cloudRecord: CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: cloudRecordID)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(self)
            record["payload"] = data as CKRecordValue
            record["updatedAt"] = fetchedAt as CKRecordValue
            record["cacheKey"] = cacheKey as CKRecordValue
            record["dataSource"] = dataSourceRaw as CKRecordValue
        } catch {
            // Will be handled by the sync service
        }
        return record
    }

    public static func from(record: CKRecord) throws -> CacheBackupRecord {
        guard let data = record["payload"] as? Data else {
            throw CloudBackupError.missingPayload
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CacheBackupRecord.self, from: data)
    }
}
