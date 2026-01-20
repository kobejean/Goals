import SwiftUI

/// Chart type for insight cards
public enum InsightChartType: String, Sendable {
    case sparkline      // Line chart for continuous values
    case durationRange  // Vertical bars showing time ranges
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

    public init(dataPoints: [DurationRangeDataPoint], defaultColor: Color) {
        self.dataPoints = dataPoints
        self.defaultColor = defaultColor
    }
}
