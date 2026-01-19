import Foundation

// MARK: - Shared Protocol

/// Common properties shared between current stats and contest results
public protocol AtCoderStatsProtocol: Sendable, Equatable, Codable {
    var date: Date { get }
    var rating: Int { get }
    var highestRating: Int { get }
    var contestsParticipated: Int { get }
    var problemsSolved: Int { get }
    var longestStreak: Int? { get }
}

extension AtCoderStatsProtocol {
    /// AtCoder rank color based on rating
    public var rankColor: AtCoderRankColor {
        switch rating {
        case ..<400:
            return .gray
        case 400..<800:
            return .brown
        case 800..<1200:
            return .green
        case 1200..<1600:
            return .cyan
        case 1600..<2000:
            return .blue
        case 2000..<2400:
            return .yellow
        case 2400..<2800:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Current Stats (Not Cached)

/// Current AtCoder statistics snapshot - represents the user's current state
/// This is a point-in-time snapshot and should NOT be cached
public struct AtCoderCurrentStats: AtCoderStatsProtocol {
    public let date: Date
    public let rating: Int
    public let highestRating: Int
    public let contestsParticipated: Int
    public let problemsSolved: Int
    public let longestStreak: Int?

    public init(
        date: Date,
        rating: Int,
        highestRating: Int,
        contestsParticipated: Int,
        problemsSolved: Int,
        longestStreak: Int? = nil
    ) {
        self.date = date
        self.rating = rating
        self.highestRating = highestRating
        self.contestsParticipated = contestsParticipated
        self.problemsSolved = problemsSolved
        self.longestStreak = longestStreak
    }

    /// Creates a current stats snapshot from a contest result (for fallback display)
    public init(from contestResult: AtCoderContestResult) {
        self.date = contestResult.date
        self.rating = contestResult.rating
        self.highestRating = contestResult.highestRating
        self.contestsParticipated = contestResult.contestsParticipated
        self.problemsSolved = contestResult.problemsSolved
        self.longestStreak = contestResult.longestStreak
    }
}

// MARK: - Contest Result (Cached)

/// AtCoder contest result - represents a single contest participation
/// These are historical records and should be cached
public struct AtCoderContestResult: AtCoderStatsProtocol {
    public let date: Date
    public let rating: Int
    public let highestRating: Int
    public let contestsParticipated: Int
    public let problemsSolved: Int
    public let longestStreak: Int?
    public let contestScreenName: String  // Required - this is the cache key

    public init(
        date: Date,
        rating: Int,
        highestRating: Int,
        contestsParticipated: Int,
        problemsSolved: Int,
        longestStreak: Int? = nil,
        contestScreenName: String
    ) {
        self.date = date
        self.rating = rating
        self.highestRating = highestRating
        self.contestsParticipated = contestsParticipated
        self.problemsSolved = problemsSolved
        self.longestStreak = longestStreak
        self.contestScreenName = contestScreenName
    }
}

// MARK: - CacheableRecord

extension AtCoderContestResult: CacheableRecord {
    public static var dataSource: DataSourceType { .atCoder }
    public static var recordType: String { "contest_history" }

    public var cacheKey: String {
        "ac:contest:\(contestScreenName)"
    }

    public var recordDate: Date { date }
}

// MARK: - Rank Color

/// AtCoder rank colors based on rating/difficulty
public enum AtCoderRankColor: String, Sendable, CaseIterable, Codable {
    case gray
    case brown
    case green
    case cyan
    case blue
    case yellow
    case orange
    case red

    public var displayName: String {
        rawValue.capitalized
    }

    public var ratingRange: String {
        switch self {
        case .gray:
            return "0-399"
        case .brown:
            return "400-799"
        case .green:
            return "800-1199"
        case .cyan:
            return "1200-1599"
        case .blue:
            return "1600-1999"
        case .yellow:
            return "2000-2399"
        case .orange:
            return "2400-2799"
        case .red:
            return "2800+"
        }
    }

    /// Returns the color for a given difficulty rating
    public static func from(difficulty: Int?) -> AtCoderRankColor {
        guard let diff = difficulty else { return .gray }
        switch diff {
        case ..<400: return .gray
        case 400..<800: return .brown
        case 800..<1200: return .green
        case 1200..<1600: return .cyan
        case 1600..<2000: return .blue
        case 2000..<2400: return .yellow
        case 2400..<2800: return .orange
        default: return .red
        }
    }

    /// Sort order for stacking (easiest at bottom)
    public var sortOrder: Int {
        switch self {
        case .gray: return 0
        case .brown: return 1
        case .green: return 2
        case .cyan: return 3
        case .blue: return 4
        case .yellow: return 5
        case .orange: return 6
        case .red: return 7
        }
    }
}
