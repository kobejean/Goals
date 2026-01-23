import Foundation

/// Time range options for filtering data in insights views
public enum TimeRange: String, CaseIterable, Sendable {
    case day
    case week
    case month
    case quarter
    case year
    case all

    public var displayName: String {
        switch self {
        case .day: return "1D"
        case .week: return "1W"
        case .month: return "1M"
        case .quarter: return "3M"
        case .year: return "1Y"
        case .all: return "All"
        }
    }

    public func startDate(from endDate: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .day:
            return calendar.startOfDay(for: endDate)
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .quarter:
            return calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        case .all:
            return calendar.date(byAdding: .year, value: -100, to: endDate) ?? Date.distantPast
        }
    }

    public var xAxisStride: Calendar.Component {
        switch self {
        case .day: return .hour
        case .week: return .day
        case .month: return .weekOfYear
        case .quarter: return .month
        case .year: return .month
        case .all: return .year
        }
    }

    public var xAxisCount: Int {
        switch self {
        case .day: return 4
        case .week: return 1
        case .month: return 1
        case .quarter: return 1
        case .year: return 2
        case .all: return 1
        }
    }

    public var xAxisFormat: Date.FormatStyle {
        switch self {
        case .day: return .dateTime.hour()
        case .week: return .dateTime.weekday(.abbreviated)
        case .month: return .dateTime.month(.abbreviated).day()
        case .quarter: return .dateTime.month(.abbreviated)
        case .year: return .dateTime.month(.abbreviated)
        case .all: return .dateTime.year()
        }
    }
}
