import Foundation
import GoalsCore

/// Represents a single data point of progress for a goal
public struct DataPoint: Sendable, Equatable, UUIDIdentifiable {
    public let id: UUID
    public let goalId: UUID
    public var value: Double
    public var timestamp: Date
    public var source: DataSourceType
    public var note: String?
    public var metadata: [String: String]?

    public init(
        id: UUID = UUID(),
        goalId: UUID,
        value: Double,
        timestamp: Date = Date(),
        source: DataSourceType = .manual,
        note: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.goalId = goalId
        self.value = value
        self.timestamp = timestamp
        self.source = source
        self.note = note
        self.metadata = metadata
    }
}

// MARK: - Statistics Entities

/// TypeQuicker typing statistics
public struct TypeQuickerStats: Sendable, Equatable, Codable {
    public let date: Date
    public let wordsPerMinute: Double
    public let accuracy: Double
    public let practiceTimeMinutes: Int
    public let sessionsCount: Int
    public let byMode: [TypeQuickerModeStats]?

    public init(
        date: Date,
        wordsPerMinute: Double,
        accuracy: Double,
        practiceTimeMinutes: Int,
        sessionsCount: Int,
        byMode: [TypeQuickerModeStats]? = nil
    ) {
        self.date = date
        self.wordsPerMinute = wordsPerMinute
        self.accuracy = accuracy
        self.practiceTimeMinutes = practiceTimeMinutes
        self.sessionsCount = sessionsCount
        self.byMode = byMode
    }
}

/// TypeQuicker statistics grouped by mode (e.g., "words", "quotes", "numbers")
public struct TypeQuickerModeStats: Sendable, Equatable, Codable, Identifiable {
    public var id: String { mode }
    public let mode: String
    public let wordsPerMinute: Double
    public let accuracy: Double
    public let practiceTimeMinutes: Int
    public let sessionsCount: Int

    public init(
        mode: String,
        wordsPerMinute: Double,
        accuracy: Double,
        practiceTimeMinutes: Int,
        sessionsCount: Int
    ) {
        self.mode = mode
        self.wordsPerMinute = wordsPerMinute
        self.accuracy = accuracy
        self.practiceTimeMinutes = practiceTimeMinutes
        self.sessionsCount = sessionsCount
    }

    /// Display name for the mode
    public var displayName: String {
        mode.capitalized
    }
}

/// AtCoder competitive programming statistics
public struct AtCoderStats: Sendable, Equatable, Codable {
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

/// AtCoder submission record
public struct AtCoderSubmission: Sendable, Equatable, Codable, Identifiable {
    public let id: Int
    public let epochSecond: Int
    public let problemId: String
    public let contestId: String
    public let userId: String
    public let language: String
    public let point: Double
    public let length: Int
    public let result: String
    public let executionTime: Int?

    public init(
        id: Int,
        epochSecond: Int,
        problemId: String,
        contestId: String,
        userId: String,
        language: String,
        point: Double,
        length: Int,
        result: String,
        executionTime: Int?
    ) {
        self.id = id
        self.epochSecond = epochSecond
        self.problemId = problemId
        self.contestId = contestId
        self.userId = userId
        self.language = language
        self.point = point
        self.length = length
        self.result = result
        self.executionTime = executionTime
    }

    /// Date of the submission
    public var date: Date {
        Date(timeIntervalSince1970: TimeInterval(epochSecond))
    }

    /// Whether the submission was accepted
    public var isAccepted: Bool {
        result == "AC"
    }
}

/// Daily submission summary grouped by difficulty
public struct AtCoderDailyEffort: Sendable, Equatable, Identifiable {
    public let date: Date
    public let submissionsByDifficulty: [AtCoderRankColor: Int]

    public var id: Date { date }

    public init(date: Date, submissionsByDifficulty: [AtCoderRankColor: Int]) {
        self.date = date
        self.submissionsByDifficulty = submissionsByDifficulty
    }

    /// Total submissions for the day
    public var totalSubmissions: Int {
        submissionsByDifficulty.values.reduce(0, +)
    }
}

/// Finance statistics
public struct FinanceStats: Sendable, Equatable, Codable {
    public let date: Date
    public let income: Double
    public let expenses: Double
    public let savings: Double
    public let currency: String

    public init(
        date: Date,
        income: Double,
        expenses: Double,
        savings: Double,
        currency: String = "USD"
    ) {
        self.date = date
        self.income = income
        self.expenses = expenses
        self.savings = savings
        self.currency = currency
    }

    /// Net income (income - expenses)
    public var netIncome: Double {
        income - expenses
    }

    /// Savings rate as percentage
    public var savingsRate: Double {
        guard income > 0 else { return 0 }
        return savings / income
    }
}
