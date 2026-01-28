import Foundation

/// Wii Fit body measurement record
public struct WiiFitMeasurement: Sendable, Equatable, Codable, Identifiable {
    /// Date of measurement
    public let date: Date

    /// Body weight in kilograms
    public let weightKg: Double

    /// Body Mass Index
    public let bmi: Double

    /// Balance percentage (50.0 = perfectly centered)
    public let balancePercent: Double

    /// Profile name this measurement belongs to
    public let profileName: String

    public var id: Date { date }

    public init(
        date: Date,
        weightKg: Double,
        bmi: Double,
        balancePercent: Double,
        profileName: String
    ) {
        self.date = date
        self.weightKg = weightKg
        self.bmi = bmi
        self.balancePercent = balancePercent
        self.profileName = profileName
    }

    /// Weight in pounds
    public var weightLbs: Double {
        weightKg * 2.20462
    }

    /// Balance offset from center (positive = right, negative = left)
    public var balanceOffset: Double {
        balancePercent - 50.0
    }
}

// MARK: - CacheableRecord

extension WiiFitMeasurement: CacheableRecord {
    public static var dataSource: DataSourceType { .wiiFit }
    public static var recordType: String { "measurement" }

    public var cacheKey: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return "wiifit:m:\(profileName):\(dateFormatter.string(from: date))"
    }

    public var recordDate: Date { date }
}

// MARK: - Trend Calculation

public extension Array where Element == WiiFitMeasurement {
    /// Calculate weight change over the past N days
    func weightChange(days: Int, from referenceDate: Date = Date()) -> Double? {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: referenceDate) else {
            return nil
        }

        let sorted = self.sorted { $0.date < $1.date }
        guard let earliest = sorted.first(where: { $0.date >= cutoff }),
              let latest = sorted.last else {
            return nil
        }

        return latest.weightKg - earliest.weightKg
    }

    /// Get the most recent measurement
    var latest: WiiFitMeasurement? {
        self.max(by: { $0.date < $1.date })
    }
}
