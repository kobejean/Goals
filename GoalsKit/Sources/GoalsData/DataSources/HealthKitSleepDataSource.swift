import Foundation
import HealthKit
import GoalsDomain

/// Data source implementation for HealthKit sleep data.
/// Supports optional caching via DataCache - uses DateBasedStrategy since sleep records are immutable.
public actor HealthKitSleepDataSource: HealthKitSleepDataSourceProtocol, CacheableDataSource {
    public let dataSourceType: DataSourceType = .healthKitSleep

    public nonisolated var availableMetrics: [MetricInfo] {
        [
            MetricInfo(key: "sleepDuration", name: "Sleep Duration", unit: "hrs", icon: "bed.double"),
            MetricInfo(key: "sleepEfficiency", name: "Sleep Efficiency", unit: "%", icon: "percent"),
            MetricInfo(key: "remDuration", name: "REM Sleep", unit: "min", icon: "moon.stars"),
            MetricInfo(key: "deepDuration", name: "Deep Sleep", unit: "min", icon: "moon.zzz"),
            MetricInfo(key: "coreDuration", name: "Core Sleep", unit: "min", icon: "moon"),
            MetricInfo(key: "bedtime", name: "Bedtime", unit: "hr", icon: "moon.fill"),
            MetricInfo(key: "wakeTime", name: "Wake Time", unit: "hr", icon: "sun.max"),
        ]
    }

    public nonisolated func metricValue(for key: String, from stats: Any) -> Double? {
        guard let summary = stats as? SleepDailySummary else { return nil }
        switch key {
        case "sleepDuration": return summary.totalSleepHours
        case "sleepEfficiency": return summary.averageEfficiency
        case "remDuration": return summary.totalDurationMinutes(for: .rem)
        case "deepDuration": return summary.totalDurationMinutes(for: .deep)
        case "coreDuration": return summary.totalDurationMinutes(for: .core)
        case "bedtime": return summary.bedtimeHour
        case "wakeTime": return summary.wakeTimeHour
        default: return nil
        }
    }

    // MARK: - CacheableDataSource

    public let cache: DataCache?

    /// Strategy for incremental fetching.
    /// Sleep records are immutable once recorded, so we only need to fetch recent data.
    private let strategy = DateBasedStrategy(strategyKey: "healthkit.sleep", volatileWindowDays: 1)

    // MARK: - Configuration

    private let healthStore: HKHealthStore
    private let sleepType: HKCategoryType

    /// Creates a HealthKitSleepDataSource without caching (for testing).
    public init() {
        self.cache = nil
        self.healthStore = HKHealthStore()
        self.sleepType = HKCategoryType(.sleepAnalysis)
    }

    /// Creates a HealthKitSleepDataSource with caching enabled (for production).
    public init(cache: DataCache) {
        self.cache = cache
        self.healthStore = HKHealthStore()
        self.sleepType = HKCategoryType(.sleepAnalysis)
    }

    // MARK: - Configuration

    public func isConfigured() async -> Bool {
        // HealthKit doesn't require user credentials, just authorization
        await isAuthorized()
    }

    public func configure(settings: DataSourceSettings) async throws {
        // No configuration needed for HealthKit - uses system authorization
    }

    public func clearConfiguration() async throws {
        // No configuration to clear
    }

    // MARK: - Authorization

    public func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitSleepError.healthKitNotAvailable
        }

        let typesToRead: Set<HKObjectType> = [sleepType]

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    public func isAuthorized() async -> Bool {
        // Note: HealthKit doesn't reveal read authorization status for privacy reasons.
        // authorizationStatus(for:) only works for WRITE permissions.
        // For read-only access, we return true if HealthKit is available and let
        // the data fetch handle it - denied access returns empty results, not errors.
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Data Fetching

    public func fetchLatestMetricValue(for metricKey: String, taskId: UUID?) async throws -> Double? {
        guard let summary = try await fetchLatestSleep() else { return nil }
        return metricValue(for: metricKey, from: summary)
    }

    public func fetchSleepData(from startDate: Date, to endDate: Date) async throws -> [SleepDailySummary] {
        // Use cached fetch if caching is enabled
        try await cachedFetch(
            strategy: strategy,
            fetcher: fetchSleepDataFromHealthKit,
            from: startDate,
            to: endDate
        )
    }

    /// Internal method that fetches sleep data directly from HealthKit.
    private func fetchSleepDataFromHealthKit(from startDate: Date, to endDate: Date) async throws -> [SleepDailySummary] {
        let samples = try await querySleepSamples(from: startDate, to: endDate)
        let sessions = groupSamplesIntoSessions(samples)
        return groupSessionsByWakeDate(sessions, from: startDate, to: endDate)
    }

    public func fetchLatestSleep() async throws -> SleepDailySummary? {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        let summaries = try await fetchSleepData(from: startDate, to: endDate)
        return summaries.last
    }

    // MARK: - Cache-Only Methods (for instant display)

    public func fetchCachedSleepData(from startDate: Date, to endDate: Date) async throws -> [SleepDailySummary] {
        try await fetchCached(SleepDailySummary.self, from: startDate, to: endDate)
    }

    public func hasCachedData() async throws -> Bool {
        try await hasCached(SleepDailySummary.self)
    }

    // MARK: - Private Helpers

    private func querySleepSamples(from startDate: Date, to endDate: Date) async throws -> [HKCategorySample] {
        // Query sleep samples that end within the date range
        // We extend the start by 24 hours to catch overnight sessions
        let adjustedStart = Calendar.current.date(byAdding: .day, value: -1, to: startDate) ?? startDate

        let predicate = HKQuery.predicateForSamples(
            withStart: adjustedStart,
            end: Calendar.current.date(byAdding: .day, value: 1, to: endDate),
            options: .strictEndDate
        )

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let categorySamples = samples as? [HKCategorySample] ?? []
                    continuation.resume(returning: categorySamples)
                }
            }
            healthStore.execute(query)
        }
    }

    private func mapSleepValue(_ value: Int) -> SleepStageType {
        // Map HKCategoryValueSleepAnalysis values to our SleepStageType
        switch value {
        case HKCategoryValueSleepAnalysis.inBed.rawValue:
            return .inBed
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
            return .asleep
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            return .awake
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
            return .core
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
            return .deep
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            return .rem
        default:
            return .asleep
        }
    }

    private func groupSamplesIntoSessions(_ samples: [HKCategorySample]) -> [SleepSession] {
        guard !samples.isEmpty else { return [] }

        // Keep all samples - don't filter globally as it can remove valid recent data
        // when old detailed samples exist. The session grouping will handle this naturally.
        let sleepSamples = samples

        // Group samples into sessions (2hr gap = new session)
        let gapThreshold: TimeInterval = 2 * 60 * 60 // 2 hours

        var sessions: [SleepSession] = []
        var currentSessionSamples: [HKCategorySample] = []
        var lastEndDate: Date?

        for sample in sleepSamples {
            if let last = lastEndDate {
                let gap = sample.startDate.timeIntervalSince(last)
                if gap > gapThreshold {
                    // Start new session
                    if !currentSessionSamples.isEmpty {
                        if let session = createSession(from: currentSessionSamples) {
                            sessions.append(session)
                        }
                    }
                    currentSessionSamples = [sample]
                } else {
                    currentSessionSamples.append(sample)
                }
            } else {
                currentSessionSamples.append(sample)
            }
            lastEndDate = sample.endDate
        }

        // Don't forget the last session
        if !currentSessionSamples.isEmpty {
            if let session = createSession(from: currentSessionSamples) {
                sessions.append(session)
            }
        }

        return sessions
    }

    private func createSession(from samples: [HKCategorySample]) -> SleepSession? {
        guard let firstSample = samples.first,
              let lastSample = samples.last else { return nil }

        let stages = samples.map { sample in
            SleepStage(
                type: mapSleepValue(sample.value),
                startDate: sample.startDate,
                endDate: sample.endDate
            )
        }

        // Get source device name
        let source = samples.first?.sourceRevision.source.name

        return SleepSession(
            startDate: firstSample.startDate,
            endDate: lastSample.endDate,
            stages: stages,
            source: source
        )
    }

    private func groupSessionsByWakeDate(_ sessions: [SleepSession], from startDate: Date, to endDate: Date) -> [SleepDailySummary] {
        let calendar = Calendar.current

        // Group sessions by wake date (the date the session ends)
        var sessionsByWakeDate: [Date: [SleepSession]] = [:]

        for session in sessions {
            let wakeDate = calendar.startOfDay(for: session.endDate)
            sessionsByWakeDate[wakeDate, default: []].append(session)
        }

        // Create daily summaries only for dates that have sessions
        // (don't iterate day-by-day which would be slow for large date ranges)
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        let summaries = sessionsByWakeDate.compactMap { (date, sessions) -> SleepDailySummary? in
            // Filter to only include dates within the requested range
            guard date >= startDay && date <= endDay else { return nil }
            guard !sessions.isEmpty else { return nil }
            return SleepDailySummary(date: date, sessions: sessions)
        }

        return summaries.sorted { $0.date < $1.date }
    }
}

// MARK: - Errors

public enum HealthKitSleepError: Error, LocalizedError {
    case healthKitNotAvailable
    case authorizationDenied
    case queryFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        case .queryFailed(let error):
            return "Failed to query sleep data: \(error.localizedDescription)"
        }
    }
}
