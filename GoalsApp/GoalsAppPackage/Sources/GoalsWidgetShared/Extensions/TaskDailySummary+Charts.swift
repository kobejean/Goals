import Foundation
import SwiftUI
import GoalsDomain
import GoalsCore

/// Extension to convert TaskDailySummary to chart-compatible types
public extension TaskDailySummary {
    /// Convert to duration range data point for charting
    /// - Parameter referenceDate: Date to use as end time for active sessions
    func toDurationRangeDataPoint(referenceDate: Date = Date()) -> DurationRangeDataPoint {
        let segments = sessions.compactMap { session -> DurationSegment? in
            // Use referenceDate for active sessions, actual endDate for completed
            let endDate = session.endDate ?? referenceDate

            // Skip if session started after reference date
            guard session.startDate <= referenceDate else { return nil }

            let color = session.taskColor.swiftUIColor

            return DurationSegment(
                startTime: session.startDate,
                endTime: endDate,
                color: color,
                label: session.taskName
            )
        }

        return DurationRangeDataPoint(date: date, segments: segments)
    }
}

// MARK: - Batch Conversion with Day Boundary Handling

public extension Array where Element == TaskDailySummary {
    /// Convert to duration range data points with proper day boundary handling
    ///
    /// Sessions that cross the 4 AM boundary will be split across multiple days.
    /// For example, a session from 11 PM to 6 AM will appear as:
    /// - [11 PM - 4 AM] in day N (logical day based on 11 PM start)
    /// - [4 AM - 6 AM] in day N+1
    ///
    /// - Parameters:
    ///   - referenceDate: Date to use as end time for active sessions
    ///   - boundaryConfig: Day boundary configuration (defaults to .tasks which uses 4 AM)
    /// - Returns: Array of DurationRangeDataPoint with sessions properly split at boundaries
    func toDurationRangeDataPoints(
        referenceDate: Date = Date(),
        boundaryConfig: DayBoundaryConfig = .tasks
    ) -> [DurationRangeDataPoint] {
        // Collect all sessions from all summaries and split them
        var segmentsByLogicalDay: [Date: [DurationSegment]] = [:]

        for summary in self {
            for session in summary.sessions {
                // Use referenceDate for active sessions, actual endDate for completed
                let endDate = session.endDate ?? referenceDate

                // Skip if session started after reference date
                guard session.startDate <= referenceDate else { continue }

                let color = session.taskColor.swiftUIColor

                // Split the session at day boundaries
                let splitSegments = DayBoundarySplitter.split(
                    startTime: session.startDate,
                    endTime: endDate,
                    original: session,
                    config: boundaryConfig
                )

                #if DEBUG
                if splitSegments.count > 0 {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d HH:mm"
                    for seg in splitSegments {
                        print("[DayBoundary] Session \(formatter.string(from: session.startDate)) - \(formatter.string(from: endDate)) → logicalDay: \(formatter.string(from: seg.logicalDay))")
                    }
                }
                #endif

                let calendar = Calendar.current
                for segment in splitSegments {
                    // Check if segment belongs to previous logical day (times before boundary)
                    // If the logical day differs from the calendar day of the start time, add 24 hours offset
                    let segmentCalendarDay = calendar.startOfDay(for: segment.startTime)
                    let hourOffset: Double = (segment.logicalDay < segmentCalendarDay) ? 24.0 : 0.0

                    let durationSegment = DurationSegment(
                        startTime: segment.startTime,
                        endTime: segment.endTime,
                        color: color,
                        label: session.taskName,
                        hourOffset: hourOffset
                    )
                    segmentsByLogicalDay[segment.logicalDay, default: []].append(durationSegment)
                }
            }
        }

        // Convert to DurationRangeDataPoint array sorted by date
        return segmentsByLogicalDay.map { date, segments in
            DurationRangeDataPoint(date: date, segments: segments)
        }.sorted { $0.date < $1.date }
    }
}
