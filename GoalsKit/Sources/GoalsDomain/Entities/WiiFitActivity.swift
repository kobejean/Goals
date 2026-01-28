import Foundation

/// Types of Wii Fit activities
public enum WiiFitActivityType: String, Codable, Sendable, CaseIterable {
    case yoga
    case strength
    case aerobics
    case balance
    case training

    public var displayName: String {
        switch self {
        case .yoga: return "Yoga"
        case .strength: return "Strength Training"
        case .aerobics: return "Aerobics"
        case .balance: return "Balance Games"
        case .training: return "Training Plus"
        }
    }

    public var systemImage: String {
        switch self {
        case .yoga: return "figure.yoga"
        case .strength: return "figure.strengthtraining.traditional"
        case .aerobics: return "figure.run"
        case .balance: return "figure.stand.line.dotted.figure.stand"
        case .training: return "figure.mixed.cardio"
        }
    }
}

/// Wii Fit activity/exercise record
public struct WiiFitActivity: Sendable, Equatable, Codable, Identifiable {
    /// Date and time of the activity
    public let date: Date

    /// Type of activity
    public let activityType: WiiFitActivityType

    /// Activity/exercise name (e.g., "Half Moon", "Push-Up Challenge")
    public let name: String

    /// Duration in minutes
    public let durationMinutes: Int

    /// Calories burned
    public let caloriesBurned: Int

    /// Score or rating (0 if not applicable)
    public let score: Int

    /// Profile name this activity belongs to
    public let profileName: String

    public var id: String { cacheKey }

    public init(
        date: Date,
        activityType: WiiFitActivityType,
        name: String,
        durationMinutes: Int,
        caloriesBurned: Int,
        score: Int,
        profileName: String
    ) {
        self.date = date
        self.activityType = activityType
        self.name = name
        self.durationMinutes = durationMinutes
        self.caloriesBurned = caloriesBurned
        self.score = score
        self.profileName = profileName
    }
}

// MARK: - CacheableRecord

extension WiiFitActivity: CacheableRecord {
    public static var dataSource: DataSourceType { .wiiFit }
    public static var recordType: String { "activity" }

    public var cacheKey: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        // Include name in key to distinguish activities at the same time
        return "wiifit:a:\(profileName):\(dateFormatter.string(from: date)):\(name)"
    }

    public var recordDate: Date { date }
}

// MARK: - Aggregation

public extension Array where Element == WiiFitActivity {
    /// Total calories burned
    var totalCalories: Int {
        reduce(0) { $0 + $1.caloriesBurned }
    }

    /// Total exercise duration in minutes
    var totalDurationMinutes: Int {
        reduce(0) { $0 + $1.durationMinutes }
    }

    /// Group activities by type
    func grouped() -> [WiiFitActivityType: [WiiFitActivity]] {
        Dictionary(grouping: self) { $0.activityType }
    }

    /// Activities for a specific day
    func forDay(_ date: Date) -> [WiiFitActivity] {
        let calendar = Calendar.current
        return filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
}
