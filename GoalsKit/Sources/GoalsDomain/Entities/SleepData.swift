import Foundation

/// Type of sleep stage recorded by HealthKit
public enum SleepStageType: String, Codable, Sendable, CaseIterable {
    case awake
    case rem
    case core
    case deep
    case asleep  // Unspecified sleep (legacy/fallback)
    case inBed   // In bed but not necessarily asleep

    /// Display name for the stage
    public var displayName: String {
        switch self {
        case .awake: return "Awake"
        case .rem: return "REM"
        case .core: return "Core"
        case .deep: return "Deep"
        case .asleep: return "Asleep"
        case .inBed: return "In Bed"
        }
    }

    /// Whether this stage counts toward actual sleep time
    public var isActualSleep: Bool {
        switch self {
        case .rem, .core, .deep, .asleep:
            return true
        case .awake, .inBed:
            return false
        }
    }
}

/// A single sleep stage within a sleep session
public struct SleepStage: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let type: SleepStageType
    public let startDate: Date
    public let endDate: Date

    public init(id: UUID = UUID(), type: SleepStageType, startDate: Date, endDate: Date) {
        self.id = id
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
    }

    /// Duration of this stage in seconds
    public var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    /// Duration of this stage in minutes
    public var durationMinutes: Double {
        duration / 60.0
    }
}

/// A complete sleep session (from bedtime to wake)
public struct SleepSession: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let startDate: Date
    public let endDate: Date
    public let stages: [SleepStage]
    public let source: String?  // Source device/app name

    public init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        stages: [SleepStage] = [],
        source: String? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.stages = stages
        self.source = source
    }

    /// Total time in bed (full session duration)
    public var totalTimeInBed: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    /// Total time in bed in hours
    public var totalTimeInBedHours: Double {
        totalTimeInBed / 3600.0
    }

    /// Total actual sleep time (excluding awake/in-bed stages)
    public var totalSleepTime: TimeInterval {
        stages.filter { $0.type.isActualSleep }.reduce(0) { $0 + $1.duration }
    }

    /// Total sleep time in hours
    public var totalSleepHours: Double {
        totalSleepTime / 3600.0
    }

    /// Sleep efficiency as a percentage (sleep time / time in bed)
    public var efficiency: Double {
        guard totalTimeInBed > 0 else { return 0 }
        return (totalSleepTime / totalTimeInBed) * 100
    }

    /// Number of interruptions (awake stages during sleep)
    public var interruptions: Int {
        stages.filter { $0.type == .awake }.count
    }

    /// Duration for a specific stage type
    public func duration(for stageType: SleepStageType) -> TimeInterval {
        stages.filter { $0.type == stageType }.reduce(0) { $0 + $1.duration }
    }

    /// Duration for a specific stage type in minutes
    public func durationMinutes(for stageType: SleepStageType) -> Double {
        duration(for: stageType) / 60.0
    }
}

/// Daily sleep summary (grouped by wake date)
public struct SleepDailySummary: Codable, Sendable, Equatable, Identifiable {
    public var id: Date { date }

    /// The wake date (the date this sleep is attributed to)
    public let date: Date

    /// All sleep sessions ending on this date
    public let sessions: [SleepSession]

    public init(date: Date, sessions: [SleepSession]) {
        self.date = date
        self.sessions = sessions
    }

    /// The primary (longest) sleep session for the night
    public var primarySession: SleepSession? {
        sessions.max(by: { $0.totalSleepTime < $1.totalSleepTime })
    }

    /// Total sleep hours across all sessions
    public var totalSleepHours: Double {
        sessions.reduce(0) { $0 + $1.totalSleepHours }
    }

    /// Bedtime of the primary session (as hour of day, e.g., 22.5 for 10:30 PM)
    public var bedtimeHour: Double? {
        guard let session = primarySession else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: session.startDate)
        guard let hour = components.hour, let minute = components.minute else { return nil }
        return Double(hour) + Double(minute) / 60.0
    }

    /// Wake time of the primary session (as hour of day)
    public var wakeTimeHour: Double? {
        guard let session = primarySession else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: session.endDate)
        guard let hour = components.hour, let minute = components.minute else { return nil }
        return Double(hour) + Double(minute) / 60.0
    }

    /// Bedtime as a Date object (for the primary session)
    public var bedtime: Date? {
        primarySession?.startDate
    }

    /// Wake time as a Date object (for the primary session)
    public var wakeTime: Date? {
        primarySession?.endDate
    }

    /// Average sleep efficiency across all sessions
    public var averageEfficiency: Double {
        guard !sessions.isEmpty else { return 0 }
        let total = sessions.reduce(0) { $0 + $1.efficiency }
        return total / Double(sessions.count)
    }

    /// Total duration for a specific stage type across all sessions
    public func totalDurationMinutes(for stageType: SleepStageType) -> Double {
        sessions.reduce(0) { $0 + $1.durationMinutes(for: stageType) }
    }
}

// MARK: - CacheableRecord

extension SleepDailySummary: CacheableRecord {
    public static var dataSource: DataSourceType { .healthKitSleep }
    public static var recordType: String { "daily" }

    public var cacheKey: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "hk:sleep:\(dateFormatter.string(from: date))"
    }

    public var recordDate: Date { date }
}
