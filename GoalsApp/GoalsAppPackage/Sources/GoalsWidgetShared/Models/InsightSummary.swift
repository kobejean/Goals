import SwiftUI

/// Single day's activity for GitHub-style chart
public struct InsightActivityDay: Identifiable, Sendable {
    public var id: Date { date }  // Stable ID based on date for smooth animations
    public let date: Date
    public let color: Color      // The color for this square
    public let intensity: Double // 0.0-1.0 for opacity/shade

    public init(date: Date, color: Color, intensity: Double) {
        self.date = date
        self.color = color
        self.intensity = intensity
    }
}

/// Activity data for GitHub-style contribution chart
public struct InsightActivityData: Sendable {
    public let days: [InsightActivityDay]
    public let emptyColor: Color  // Color for days with no activity

    public init(days: [InsightActivityDay], emptyColor: Color) {
        self.days = days
        self.emptyColor = emptyColor
    }
}

/// Data point for sparkline chart
public struct InsightDataPoint: Identifiable, Sendable {
    public var id: Date { date }  // Stable ID based on date for smooth chart animations
    public let date: Date
    public let value: Double
    public let color: Color?  // Optional per-point color (e.g., for rating-based coloring)

    public init(date: Date, value: Double, color: Color? = nil) {
        self.date = date
        self.value = value
        self.color = color
    }
}

/// Summary data for insight overview cards
public struct InsightSummary: Sendable {
    public let title: String
    public let systemImage: String
    public let color: Color
    public let dataPoints: [InsightDataPoint]
    public let movingAveragePoints: [InsightDataPoint]?  // For scatter + moving average charts
    public let currentValueFormatted: String
    public let trend: Double?  // percentage change, nil if insufficient data
    public let goalValue: Double?  // optional goal target to show as line
    public let chartType: InsightChartType
    public let durationRangeData: InsightDurationRangeData?

    /// Initialize with sparkline chart type (default, backward compatible)
    public init(
        title: String,
        systemImage: String,
        color: Color,
        dataPoints: [InsightDataPoint],
        currentValueFormatted: String,
        trend: Double?,
        goalValue: Double? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.dataPoints = dataPoints
        self.movingAveragePoints = nil
        self.currentValueFormatted = currentValueFormatted
        self.trend = trend
        self.goalValue = goalValue
        self.chartType = .sparkline
        self.durationRangeData = nil
    }

    /// Initialize with duration range chart type
    public init(
        title: String,
        systemImage: String,
        color: Color,
        durationRangeData: InsightDurationRangeData,
        currentValueFormatted: String,
        trend: Double?
    ) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.dataPoints = []
        self.movingAveragePoints = nil
        self.currentValueFormatted = currentValueFormatted
        self.trend = trend
        self.goalValue = nil
        self.chartType = .durationRange
        self.durationRangeData = durationRangeData
    }

    /// Initialize with scatter + moving average chart type
    public init(
        title: String,
        systemImage: String,
        color: Color,
        scatterPoints: [InsightDataPoint],
        movingAveragePoints: [InsightDataPoint],
        currentValueFormatted: String,
        trend: Double?,
        goalValue: Double? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.dataPoints = scatterPoints
        self.movingAveragePoints = movingAveragePoints
        self.currentValueFormatted = currentValueFormatted
        self.trend = trend
        self.goalValue = goalValue
        self.chartType = .scatterWithMovingAverage
        self.durationRangeData = nil
    }
}
