import Foundation
import SwiftUI
import GoalsDomain

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
