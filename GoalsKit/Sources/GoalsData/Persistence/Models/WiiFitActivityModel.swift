import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for caching Wii Fit activities
@Model
public final class WiiFitActivityModel {
    /// Unique cache key for this record
    @Attribute(.unique)
    public var cacheKey: String = ""

    /// Date of the activity
    public var recordDate: Date = Date()

    /// When this record was fetched from the Wii
    public var fetchedAt: Date = Date()

    // MARK: - Activity Fields

    /// Activity type (stored as raw string for SwiftData compatibility)
    public var activityTypeRaw: String = "yoga"

    /// Activity/exercise name
    public var name: String = ""

    /// Duration in minutes
    public var durationMinutes: Int = 0

    /// Calories burned
    public var caloriesBurned: Int = 0

    /// Score or rating
    public var score: Int = 0

    /// Profile name this activity belongs to
    public var profileName: String = ""

    public init(
        cacheKey: String,
        recordDate: Date,
        fetchedAt: Date = Date(),
        activityTypeRaw: String,
        name: String,
        durationMinutes: Int,
        caloriesBurned: Int,
        score: Int,
        profileName: String
    ) {
        self.cacheKey = cacheKey
        self.recordDate = recordDate
        self.fetchedAt = fetchedAt
        self.activityTypeRaw = activityTypeRaw
        self.name = name
        self.durationMinutes = durationMinutes
        self.caloriesBurned = caloriesBurned
        self.score = score
        self.profileName = profileName
    }
}

// MARK: - CacheableModel Conformance

extension WiiFitActivityModel: CacheableModel {
    public typealias DomainType = WiiFitActivity
}

// MARK: - Domain Conversion

public extension WiiFitActivityModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> WiiFitActivity {
        WiiFitActivity(
            date: recordDate,
            activityType: WiiFitActivityType(rawValue: activityTypeRaw) ?? .training,
            name: name,
            durationMinutes: durationMinutes,
            caloriesBurned: caloriesBurned,
            score: score,
            profileName: profileName
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ record: WiiFitActivity, fetchedAt: Date = Date()) -> WiiFitActivityModel {
        WiiFitActivityModel(
            cacheKey: record.cacheKey,
            recordDate: record.recordDate,
            fetchedAt: fetchedAt,
            activityTypeRaw: record.activityType.rawValue,
            name: record.name,
            durationMinutes: record.durationMinutes,
            caloriesBurned: record.caloriesBurned,
            score: record.score,
            profileName: record.profileName
        )
    }

    /// Updates model from domain entity
    func update(from record: WiiFitActivity, fetchedAt: Date = Date()) {
        self.recordDate = record.recordDate
        self.fetchedAt = fetchedAt
        self.activityTypeRaw = record.activityType.rawValue
        self.name = record.name
        self.durationMinutes = record.durationMinutes
        self.caloriesBurned = record.caloriesBurned
        self.score = record.score
        self.profileName = record.profileName
    }
}
