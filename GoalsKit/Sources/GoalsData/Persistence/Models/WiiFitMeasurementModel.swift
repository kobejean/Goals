import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for caching Wii Fit body measurements
@Model
public final class WiiFitMeasurementModel {
    /// Unique cache key for this record
    @Attribute(.unique)
    public var cacheKey: String = ""

    /// Date of the measurement
    public var recordDate: Date = Date()

    /// When this record was fetched from the Wii
    public var fetchedAt: Date = Date()

    // MARK: - Measurement Fields

    /// Body weight in kilograms
    public var weightKg: Double = 0.0

    /// Body Mass Index
    public var bmi: Double = 0.0

    /// Balance percentage (50.0 = perfectly centered)
    public var balancePercent: Double = 50.0

    /// Profile name this measurement belongs to
    public var profileName: String = ""

    public init(
        cacheKey: String,
        recordDate: Date,
        fetchedAt: Date = Date(),
        weightKg: Double,
        bmi: Double,
        balancePercent: Double,
        profileName: String
    ) {
        self.cacheKey = cacheKey
        self.recordDate = recordDate
        self.fetchedAt = fetchedAt
        self.weightKg = weightKg
        self.bmi = bmi
        self.balancePercent = balancePercent
        self.profileName = profileName
    }
}

// MARK: - CacheableModel Conformance

extension WiiFitMeasurementModel: CacheableModel {
    public typealias DomainType = WiiFitMeasurement
}

// MARK: - Domain Conversion

public extension WiiFitMeasurementModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> WiiFitMeasurement {
        WiiFitMeasurement(
            date: recordDate,
            weightKg: weightKg,
            bmi: bmi,
            balancePercent: balancePercent,
            profileName: profileName
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ record: WiiFitMeasurement, fetchedAt: Date = Date()) -> WiiFitMeasurementModel {
        WiiFitMeasurementModel(
            cacheKey: record.cacheKey,
            recordDate: record.recordDate,
            fetchedAt: fetchedAt,
            weightKg: record.weightKg,
            bmi: record.bmi,
            balancePercent: record.balancePercent,
            profileName: record.profileName
        )
    }

    /// Updates model from domain entity
    func update(from record: WiiFitMeasurement, fetchedAt: Date = Date()) {
        self.recordDate = record.recordDate
        self.fetchedAt = fetchedAt
        self.weightKg = record.weightKg
        self.bmi = record.bmi
        self.balancePercent = record.balancePercent
        self.profileName = record.profileName
    }
}
