import Foundation
import SwiftUI
import GoalsDomain
import GoalsCore

// MARK: - Batch Conversion with Day Boundary Handling

public extension Array where Element == SleepDailySummary {
    /// Convert to duration range data points with proper day boundary handling
    ///
    /// Sleep sessions that cross the 4 PM boundary will be split across multiple days.
    /// The 4 PM boundary ensures overnight sleep (e.g., 10 PM to 7 AM) stays together
    /// in a single logical day, since both times fall between consecutive 4 PM boundaries.
    ///
    /// - Parameters:
    ///   - color: Color to use for the sleep segments
    ///   - boundaryConfig: Day boundary configuration (defaults to .sleep which uses 4 PM)
    /// - Returns: Array of DurationRangeDataPoint with sessions properly split at boundaries
    func toDurationRangeDataPoints(
        color: Color,
        boundaryConfig: DayBoundaryConfig = .sleep
    ) -> [DurationRangeDataPoint] {
        // Collect all sleep sessions and split them at boundaries
        var segmentsByLogicalDay: [Date: [DurationSegment]] = [:]

        for summary in self {
            guard let bedtime = summary.bedtime, let wakeTime = summary.wakeTime else {
                continue
            }

            // Split the sleep session at day boundaries
            let splitSegments = DayBoundarySplitter.split(
                startTime: bedtime,
                endTime: wakeTime,
                original: summary,
                config: boundaryConfig
            )

            let calendar = Calendar.current
            for segment in splitSegments {
                // Check if segment belongs to previous logical day (times before boundary)
                // Note: Sleep uses useSimpleHours: false, so hourOffset doesn't affect rendering
                // but we include it for consistency with other extensions
                let segmentCalendarDay = calendar.startOfDay(for: segment.startTime)
                let hourOffset: Double = (segment.logicalDay < segmentCalendarDay) ? 24.0 : 0.0

                let durationSegment = DurationSegment(
                    startTime: segment.startTime,
                    endTime: segment.endTime,
                    color: color,
                    hourOffset: hourOffset
                )
                segmentsByLogicalDay[segment.logicalDay, default: []].append(durationSegment)
            }
        }

        // Convert to DurationRangeDataPoint array sorted by date
        return segmentsByLogicalDay.map { date, segments in
            DurationRangeDataPoint(date: date, segments: segments)
        }.sorted { $0.date < $1.date }
    }
}
