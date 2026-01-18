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

    public init(
        date: Date,
        rating: Int,
        highestRating: Int,
        contestsParticipated: Int,
        problemsSolved: Int
    ) {
        self.date = date
        self.rating = rating
        self.highestRating = highestRating
        self.contestsParticipated = contestsParticipated
        self.problemsSolved = problemsSolved
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

/// AtCoder rank colors
public enum AtCoderRankColor: String, Sendable, CaseIterable {
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
