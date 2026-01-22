import SwiftUI

/// A date range for chart axis configuration
public struct DateRange: Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    /// Create a date range for the last N days from a reference date
    /// Includes 12-hour padding on both ends for proper bar centering
    public static func lastDays(_ count: Int, from referenceDate: Date = Date()) -> DateRange {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: referenceDate)
        guard let start = calendar.date(byAdding: .day, value: -(count - 1), to: end) else {
            return DateRange(start: end, end: end)
        }
        // Add padding for proper bar centering
        let paddedStart = calendar.date(byAdding: .hour, value: -12, to: start) ?? start
        let paddedEnd = calendar.date(byAdding: .hour, value: 12, to: end) ?? end
        return DateRange(start: paddedStart, end: paddedEnd)
    }
}

/// Chart type for insight cards
public enum InsightChartType: String, Sendable {
    case sparkline              // Line chart for continuous values
    case durationRange          // Vertical bars showing time ranges
    case scatterWithMovingAverage  // Scatter plot with moving average line
}

/// A single time segment within a day (e.g., sleep period, focus session)
public struct DurationSegment: Identifiable, Sendable {
    public let id: UUID
    public let startTime: Date
    public let endTime: Date
    public let color: Color
    public let label: String?

    public init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        color: Color,
        label: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.color = color
        self.label = label
    }

    /// Start time as hours relative to midnight (negative for PM, e.g., -2 for 10 PM)
    public var startChartValue: Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: startTime)
        guard let hour = components.hour, let minute = components.minute else { return 0 }
        let hourValue = Double(hour) + Double(minute) / 60.0
        // Convert to chart coordinates: hours before midnight are negative
        return hourValue < 12 ? hourValue : hourValue - 24
    }

    /// End time as hours relative to midnight
    public var endChartValue: Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: endTime)
        guard let hour = components.hour, let minute = components.minute else { return 0 }
        let hourValue = Double(hour) + Double(minute) / 60.0
        // Convert to chart coordinates: hours before midnight are negative
        return hourValue < 12 ? hourValue : hourValue - 24
    }

    /// Start time as simple hour of day (0-24 scale, for daytime activities)
    public var startHour: Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: startTime)
        guard let hour = components.hour, let minute = components.minute else { return 0 }
        return Double(hour) + Double(minute) / 60.0
    }

    /// End time as simple hour of day (0-24 scale, for daytime activities)
    public var endHour: Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: endTime)
        guard let hour = components.hour, let minute = components.minute else { return 0 }
        return Double(hour) + Double(minute) / 60.0
    }
}

/// A single day's duration data with potentially multiple segments
public struct DurationRangeDataPoint: Identifiable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let segments: [DurationSegment]

    public init(date: Date, segments: [DurationSegment]) {
        self.date = date
        self.segments = segments
    }
}

/// Container for duration range chart data
public struct InsightDurationRangeData: Sendable {
    public let dataPoints: [DurationRangeDataPoint]
    public let defaultColor: Color
    public let dateRange: DateRange?  // Optional fixed X-axis range
    public let useSimpleHours: Bool   // Use 0-24 hour scale (for daytime tasks) vs midnight-centered (for sleep)

    public init(
        dataPoints: [DurationRangeDataPoint],
        defaultColor: Color,
        dateRange: DateRange? = nil,
        useSimpleHours: Bool = false
    ) {
        self.dataPoints = dataPoints
        self.defaultColor = defaultColor
        self.dateRange = dateRange
        self.useSimpleHours = useSimpleHours
    }
}
