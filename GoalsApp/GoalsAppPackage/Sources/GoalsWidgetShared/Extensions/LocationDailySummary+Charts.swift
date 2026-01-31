import Foundation
import SwiftUI
import GoalsDomain
import GoalsCore

/// Extension to convert LocationDailySummary to chart-compatible types
public extension LocationDailySummary {
    /// Convert to duration range data point for charting
    /// - Parameter referenceDate: Date to use as end time for active sessions
    func toDurationRangeDataPoint(referenceDate: Date = Date()) -> DurationRangeDataPoint {
        let segments = sessions.compactMap { session -> DurationSegment? in
            // Use referenceDate for active sessions, actual endDate for completed
            let endDate = session.endDate ?? referenceDate

            // Skip if session started after reference date
            guard session.startDate <= referenceDate else { return nil }

            let color = session.locationColor.swiftUIColor

            return DurationSegment(
                startTime: session.startDate,
                endTime: endDate,
                color: color,
                label: session.locationName
            )
        }

        return DurationRangeDataPoint(date: date, segments: segments)
    }
}

// MARK: - Batch Conversion with Day Boundary Handling

public extension Array where Element == LocationDailySummary {
    /// Convert to duration range data points with proper day boundary handling
    ///
    /// Sessions that cross the 4 AM boundary will be split across multiple days.
    /// For example, a session from 11 PM to 6 AM will appear as:
    /// - [11 PM - 4 AM] in the starting day
    /// - [4 AM - 6 AM] in the next day
    ///
    /// - Parameters:
    ///   - referenceDate: Date to use as end time for active sessions
    ///   - boundaryConfig: Day boundary configuration (defaults to .locations which uses 4 AM)
    /// - Returns: Array of DurationRangeDataPoint with sessions properly split at boundaries
    func toDurationRangeDataPoints(
        referenceDate: Date = Date(),
        boundaryConfig: DayBoundaryConfig = .locations
    ) -> [DurationRangeDataPoint] {
        // Collect all sessions from all summaries and split them
        var segmentsByLogicalDay: [Date: [DurationSegment]] = [:]

        for summary in self {
            for session in summary.sessions {
                // Use referenceDate for active sessions, actual endDate for completed
                let endDate = session.endDate ?? referenceDate

                // Skip if session started after reference date
                guard session.startDate <= referenceDate else { continue }

                let color = session.locationColor.swiftUIColor

                // Split the session at day boundaries
                let splitSegments = DayBoundarySplitter.split(
                    startTime: session.startDate,
                    endTime: endDate,
                    original: session,
                    config: boundaryConfig
                )

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
                        label: session.locationName,
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
