import Foundation
import SwiftUI
import GoalsDomain

/// Metric options for Sleep charts
public enum SleepMetric: String, CaseIterable, Sendable {
    case duration
    case efficiency
    case stages
    case bedtime
    case wakeTime

    public var displayName: String {
        switch self {
        case .duration: return "Duration"
        case .efficiency: return "Efficiency"
        case .stages: return "Stages"
        case .bedtime: return "Bedtime"
        case .wakeTime: return "Wake Time"
        }
    }

    public var yAxisLabel: String {
        switch self {
        case .duration: return "hrs"
        case .efficiency: return "%"
        case .stages: return "min"
        case .bedtime: return "hr"
        case .wakeTime: return "hr"
        }
    }

    /// Key used for goal metric lookup
    public var metricKey: String {
        switch self {
        case .duration: return "sleepDuration"
        case .efficiency: return "sleepEfficiency"
        case .stages: return "deepDuration"
        case .bedtime: return "bedtime"
        case .wakeTime: return "wakeTime"
        }
    }
}

/// Data point for charting sleep data over time
public struct SleepChartDataPoint: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let sleepHours: Double
    public let efficiency: Double
    public let bedtimeHour: Double?  // Hour of day (e.g., 22.5 for 10:30 PM)
    public let wakeTimeHour: Double? // Hour of day (e.g., 7.0 for 7:00 AM)
    public let remMinutes: Double
    public let coreMinutes: Double
    public let deepMinutes: Double
    public let awakeMinutes: Double

    public init(from summary: SleepDailySummary) {
        self.date = summary.date
        self.sleepHours = summary.totalSleepHours
        self.efficiency = summary.averageEfficiency
        self.bedtimeHour = summary.bedtimeHour
        self.wakeTimeHour = summary.wakeTimeHour
        self.remMinutes = summary.totalDurationMinutes(for: .rem)
        self.coreMinutes = summary.totalDurationMinutes(for: .core)
        self.deepMinutes = summary.totalDurationMinutes(for: .deep)
        self.awakeMinutes = summary.totalDurationMinutes(for: .awake)
    }

    public func value(for metric: SleepMetric) -> Double {
        switch metric {
        case .duration: return sleepHours
        case .efficiency: return efficiency
        case .stages: return remMinutes + coreMinutes + deepMinutes
        case .bedtime: return bedtimeHour ?? 0
        case .wakeTime: return wakeTimeHour ?? 0
        }
    }
}

/// Data point for sleep range chart (bedtime to wake time visualization)
public struct SleepRangeDataPoint: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let bedtime: Date?
    public let wakeTime: Date?
    public let stages: [SleepStageDataPoint]

    public init(from summary: SleepDailySummary) {
        self.date = summary.date
        self.bedtime = summary.bedtime
        self.wakeTime = summary.wakeTime

        // Convert stages from primary session
        if let session = summary.primarySession {
            self.stages = session.stages.map { SleepStageDataPoint(from: $0) }
        } else {
            self.stages = []
        }
    }

    /// Bedtime as hours relative to midnight (negative for PM, e.g., -2 for 10 PM)
    public var bedtimeChartValue: Double? {
        guard let bedtime = bedtime else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: bedtime)
        guard let hour = components.hour, let minute = components.minute else { return nil }
        let hourValue = Double(hour) + Double(minute) / 60.0
        // Convert to chart coordinates: hours before midnight are negative
        return hourValue < 12 ? hourValue : hourValue - 24
    }

    /// Wake time as hours after midnight
    public var wakeTimeChartValue: Double? {
        guard let wakeTime = wakeTime else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: wakeTime)
        guard let hour = components.hour, let minute = components.minute else { return nil }
        return Double(hour) + Double(minute) / 60.0
    }
}

/// Individual sleep stage data point for detailed visualization
public struct SleepStageDataPoint: Identifiable, Sendable {
    public let id: UUID
    public let type: SleepStageType
    public let startDate: Date
    public let endDate: Date
    public let durationMinutes: Double

    public init(from stage: SleepStage) {
        self.id = stage.id
        self.type = stage.type
        self.startDate = stage.startDate
        self.endDate = stage.endDate
        self.durationMinutes = stage.durationMinutes
    }

    public var color: Color {
        switch type {
        case .deep: return .indigo
        case .core: return .blue
        case .rem: return .cyan
        case .awake: return .orange
        case .asleep: return .blue.opacity(0.7)
        case .inBed: return .gray.opacity(0.5)
        }
    }
}

// MARK: - Color Extensions for Sleep Stages

extension SleepStageType {
    public var color: Color {
        switch self {
        case .deep: return .indigo
        case .core: return .blue
        case .rem: return .cyan
        case .awake: return .orange
        case .asleep: return .blue.opacity(0.7)
        case .inBed: return .gray.opacity(0.5)
        }
    }
}

// MARK: - Duration Range Conversion

extension SleepRangeDataPoint {
    /// Convert sleep range data to duration range format for insight cards
    public func toDurationRangeDataPoint(color: Color = .indigo) -> DurationRangeDataPoint? {
        guard let bedtime = bedtime, let wakeTime = wakeTime else { return nil }

        let segment = DurationSegment(
            startTime: bedtime,
            endTime: wakeTime,
            color: color
        )
        return DurationRangeDataPoint(date: date, segments: [segment])
    }
}
