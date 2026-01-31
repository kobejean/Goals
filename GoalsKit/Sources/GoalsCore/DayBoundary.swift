import Foundation

/// Configuration for logical day boundaries
///
/// Different insight types use different boundaries:
/// - Tasks & Locations use 4 AM (typical sleep/wake boundary)
/// - Sleep uses 4 PM (middle of the day, so overnight sleep stays together)
public struct DayBoundaryConfig: Sendable, Equatable {
    /// Hour of day (0-23) when the logical day boundary occurs
    public let boundaryHour: Int

    public init(boundaryHour: Int) {
        precondition((0...23).contains(boundaryHour), "boundaryHour must be 0-23")
        self.boundaryHour = boundaryHour
    }

    /// Tasks boundary: 4 AM (activities before 4 AM count as previous day)
    public static let tasks = DayBoundaryConfig(boundaryHour: 4)

    /// Locations boundary: 4 AM (activities before 4 AM count as previous day)
    public static let locations = DayBoundaryConfig(boundaryHour: 4)

    /// Sleep boundary: 4 PM (sleep starting before 4 PM counts as previous day)
    public static let sleep = DayBoundaryConfig(boundaryHour: 16)

    /// Get the logical day for a given date
    ///
    /// For example, with a 4 AM boundary:
    /// - 2 AM on Jan 16 → logical day is Jan 15
    /// - 5 AM on Jan 16 → logical day is Jan 16
    ///
    /// - Parameters:
    ///   - date: The date to calculate logical day for
    ///   - calendar: Calendar to use (defaults to current)
    /// - Returns: The start of the logical day
    public func logicalDay(for date: Date, calendar: Calendar = .current) -> Date {
        let hour = calendar.component(.hour, from: date)
        let startOfCalendarDay = calendar.startOfDay(for: date)

        if hour < boundaryHour {
            // Before boundary hour, belongs to previous logical day
            return calendar.date(byAdding: .day, value: -1, to: startOfCalendarDay) ?? startOfCalendarDay
        } else {
            // At or after boundary hour, belongs to current logical day
            return startOfCalendarDay
        }
    }

    /// Get the next boundary date after a given date
    ///
    /// For example, with a 4 AM boundary:
    /// - 2 AM on Jan 16 → next boundary is 4 AM on Jan 16
    /// - 5 AM on Jan 16 → next boundary is 4 AM on Jan 17
    ///
    /// - Parameters:
    ///   - date: The date to find next boundary after
    ///   - calendar: Calendar to use (defaults to current)
    /// - Returns: The next boundary date
    public func nextBoundary(after date: Date, calendar: Calendar = .current) -> Date {
        let hour = calendar.component(.hour, from: date)
        let startOfCalendarDay = calendar.startOfDay(for: date)

        if hour < boundaryHour {
            // Before boundary hour, next boundary is today at boundaryHour
            return calendar.date(bySettingHour: boundaryHour, minute: 0, second: 0, of: startOfCalendarDay) ?? date
        } else {
            // At or after boundary hour, next boundary is tomorrow at boundaryHour
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfCalendarDay) else {
                return date
            }
            return calendar.date(bySettingHour: boundaryHour, minute: 0, second: 0, of: tomorrow) ?? date
        }
    }
}

/// Result of splitting a session at day boundaries
public struct SplitSegment<T: Sendable>: Sendable {
    /// The logical day this segment belongs to
    public let logicalDay: Date
    /// Start time of this segment
    public let startTime: Date
    /// End time of this segment
    public let endTime: Date
    /// Original data associated with this segment
    public let original: T

    public init(logicalDay: Date, startTime: Date, endTime: Date, original: T) {
        self.logicalDay = logicalDay
        self.startTime = startTime
        self.endTime = endTime
        self.original = original
    }
}

/// Utility for splitting sessions across day boundaries
public enum DayBoundarySplitter {
    /// Split a session that may span multiple logical days
    ///
    /// For example, with a 4 AM boundary and a session from 11 PM to 6 AM:
    /// - Segment 1: [11 PM - 4 AM] in logical day N
    /// - Segment 2: [4 AM - 6 AM] in logical day N+1
    ///
    /// - Parameters:
    ///   - startTime: Session start time
    ///   - endTime: Session end time
    ///   - original: Original data to associate with each segment
    ///   - config: Day boundary configuration
    ///   - calendar: Calendar to use (defaults to current)
    /// - Returns: Array of split segments, one per logical day
    public static func split<T: Sendable>(
        startTime: Date,
        endTime: Date,
        original: T,
        config: DayBoundaryConfig,
        calendar: Calendar = .current
    ) -> [SplitSegment<T>] {
        // Handle edge case: end before or equal to start
        guard endTime > startTime else {
            return []
        }

        var segments: [SplitSegment<T>] = []
        var currentStart = startTime

        while currentStart < endTime {
            let logicalDay = config.logicalDay(for: currentStart, calendar: calendar)
            let nextBoundary = config.nextBoundary(after: currentStart, calendar: calendar)

            // Segment ends at either the next boundary or the session end, whichever comes first
            let segmentEnd = min(nextBoundary, endTime)

            // Only add non-empty segments
            if segmentEnd > currentStart {
                segments.append(SplitSegment(
                    logicalDay: logicalDay,
                    startTime: currentStart,
                    endTime: segmentEnd,
                    original: original
                ))
            }

            currentStart = segmentEnd
        }

        return segments
    }
}
