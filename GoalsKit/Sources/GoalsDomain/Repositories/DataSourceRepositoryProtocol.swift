import Foundation

/// Protocol defining the contract for external data source operations
public protocol DataSourceRepositoryProtocol: Sendable {
    /// The type of data source this repository handles
    var dataSourceType: DataSourceType { get }

    /// Metrics available from this data source
    var availableMetrics: [MetricInfo] { get }

    /// Returns true if the data source is configured and ready to use
    func isConfigured() async -> Bool

    /// Configures the data source with credentials or settings
    func configure(settings: DataSourceSettings) async throws

    /// Clears the configuration for this data source
    func clearConfiguration() async throws

    /// Fetches the latest value for a specific metric
    /// - Parameters:
    ///   - metricKey: The metric key (e.g., "wpm", "accuracy", "rating")
    ///   - taskId: Optional task ID for per-task filtering (used by Tasks data source)
    /// - Returns: The current value for the metric, or nil if unavailable
    func fetchLatestMetricValue(for metricKey: String, taskId: UUID?) async throws -> Double?

    /// Extract a metric value from stats data (for UI display with cached stats)
    /// - Parameters:
    ///   - key: The metric key (e.g., "wpm", "accuracy")
    ///   - stats: The stats data to extract from
    /// - Returns: The metric value, or nil if not found
    func metricValue(for key: String, from stats: Any) -> Double?
}

/// Settings for configuring a data source
public struct DataSourceSettings: Sendable, Equatable {
    public let dataSourceType: DataSourceType
    public let credentials: [String: String]
    public let options: [String: String]

    public init(
        dataSourceType: DataSourceType,
        credentials: [String: String] = [:],
        options: [String: String] = [:]
    ) {
        self.dataSourceType = dataSourceType
        self.credentials = credentials
        self.options = options
    }
}

// MARK: - Specialized Data Source Protocols

/// Protocol for TypeQuicker data source
public protocol TypeQuickerDataSourceProtocol: DataSourceRepositoryProtocol {
    /// Fetches TypeQuicker statistics for a date range
    func fetchStats(from startDate: Date, to endDate: Date) async throws -> [TypeQuickerStats]

    /// Fetches the latest TypeQuicker statistics
    func fetchLatestStats() async throws -> TypeQuickerStats?

    /// Fetches stats aggregated by mode across all dates in the range
    func fetchStatsByMode(from startDate: Date, to endDate: Date) async throws -> [TypeQuickerModeStats]

    // MARK: - Cache Methods (optional, for stale-while-revalidate pattern)

    /// Returns cached stats without fetching from remote (for instant display)
    func fetchCachedStats(from startDate: Date, to endDate: Date) async throws -> [TypeQuickerStats]

    /// Returns true if there's any cached data available
    func hasCachedData() async throws -> Bool
}

// Default implementations for non-cached data sources
public extension TypeQuickerDataSourceProtocol {
    func fetchCachedStats(from startDate: Date, to endDate: Date) async throws -> [TypeQuickerStats] {
        [] // Non-cached sources return empty
    }

    func hasCachedData() async throws -> Bool {
        false // Non-cached sources have no cache
    }
}

/// Protocol for AtCoder data source
public protocol AtCoderDataSourceProtocol: DataSourceRepositoryProtocol {
    /// Fetches current AtCoder statistics (point-in-time snapshot, not cached)
    func fetchStats() async throws -> AtCoderCurrentStats?

    /// Fetches contest history (historical records, cached)
    func fetchContestHistory() async throws -> [AtCoderContestResult]

    /// Fetches both stats and contest history in a single operation.
    /// More efficient than calling fetchStats() and fetchContestHistory() separately
    /// because ranking APIs are only called once.
    func fetchStatsAndContestHistory() async throws -> (stats: AtCoderCurrentStats?, history: [AtCoderContestResult])

    /// Fetches daily effort data (submissions grouped by day and difficulty)
    func fetchDailyEffort(from fromDate: Date?) async throws -> [AtCoderDailyEffort]

    /// Fetches user submissions
    func fetchSubmissions(from fromDate: Date?) async throws -> [AtCoderSubmission]

    // MARK: - Cache Methods (optional, for stale-while-revalidate pattern)

    /// Returns cached contest history without fetching from remote
    func fetchCachedContestHistory() async throws -> [AtCoderContestResult]

    /// Returns cached daily effort without fetching from remote
    func fetchCachedDailyEffort(from startDate: Date?) async throws -> [AtCoderDailyEffort]

    /// Returns true if there's any cached contest history
    func hasCachedContestHistory() async throws -> Bool

    /// Returns true if there's any cached daily effort
    func hasCachedDailyEffort() async throws -> Bool
}

// Default implementations for non-cached data sources
public extension AtCoderDataSourceProtocol {
    func fetchCachedContestHistory() async throws -> [AtCoderContestResult] {
        []
    }

    func fetchCachedDailyEffort(from startDate: Date?) async throws -> [AtCoderDailyEffort] {
        []
    }

    func hasCachedContestHistory() async throws -> Bool {
        false
    }

    func hasCachedDailyEffort() async throws -> Bool {
        false
    }
}

/// Protocol for HealthKit Sleep data source
public protocol HealthKitSleepDataSourceProtocol: DataSourceRepositoryProtocol {
    /// Fetches sleep data for a date range
    /// - Parameters:
    ///   - from: Start date (wake date)
    ///   - to: End date (wake date)
    /// - Returns: Array of daily sleep summaries
    func fetchSleepData(from: Date, to: Date) async throws -> [SleepDailySummary]

    /// Fetches the most recent sleep data
    func fetchLatestSleep() async throws -> SleepDailySummary?

    /// Requests HealthKit authorization for sleep data
    /// - Returns: true if authorization was granted
    func requestAuthorization() async throws -> Bool

    /// Checks if HealthKit authorization has been granted
    func isAuthorized() async -> Bool

    // MARK: - Cache Methods (optional, for stale-while-revalidate pattern)

    /// Returns cached sleep data without fetching from HealthKit (for instant display)
    func fetchCachedSleepData(from startDate: Date, to endDate: Date) async throws -> [SleepDailySummary]

    /// Returns true if there's any cached sleep data available
    func hasCachedData() async throws -> Bool
}

// Default implementations for non-cached HealthKit data sources
public extension HealthKitSleepDataSourceProtocol {
    func fetchCachedSleepData(from startDate: Date, to endDate: Date) async throws -> [SleepDailySummary] {
        []
    }

    func hasCachedData() async throws -> Bool {
        false
    }
}

/// Protocol for Anki data source
public protocol AnkiDataSourceProtocol: DataSourceRepositoryProtocol {
    /// Fetches daily Anki statistics for a date range
    func fetchDailyStats(from startDate: Date, to endDate: Date) async throws -> [AnkiDailyStats]

    /// Fetches the latest daily stats
    func fetchLatestStats() async throws -> AnkiDailyStats?

    /// Fetches available deck names
    func fetchDeckNames() async throws -> [String]

    /// Tests the connection to AnkiConnect
    func testConnection() async throws -> Bool

    // MARK: - Cache Methods (optional, for stale-while-revalidate pattern)

    /// Returns cached stats without fetching from remote (for instant display)
    func fetchCachedDailyStats(from startDate: Date, to endDate: Date) async throws -> [AnkiDailyStats]

    /// Returns true if there's any cached data available
    func hasCachedData() async throws -> Bool
}

// Default implementations for non-cached Anki data sources
public extension AnkiDataSourceProtocol {
    func fetchCachedDailyStats(from startDate: Date, to endDate: Date) async throws -> [AnkiDailyStats] {
        []
    }

    func hasCachedData() async throws -> Bool {
        false
    }
}

/// Protocol for Zotero data source
public protocol ZoteroDataSourceProtocol: DataSourceRepositoryProtocol {
    /// Fetches daily annotation/note statistics for a date range
    func fetchDailyStats(from startDate: Date, to endDate: Date) async throws -> [ZoteroDailyStats]

    /// Fetches the current reading status (counts in each collection)
    func fetchReadingStatus() async throws -> ZoteroReadingStatus?

    /// Tests the connection to Zotero API
    func testConnection() async throws -> Bool

    // MARK: - Cache Methods (optional, for stale-while-revalidate pattern)

    /// Returns cached stats without fetching from remote (for instant display)
    func fetchCachedDailyStats(from startDate: Date, to endDate: Date) async throws -> [ZoteroDailyStats]

    /// Returns cached reading status without fetching from remote
    func fetchCachedReadingStatus() async throws -> ZoteroReadingStatus?

    /// Returns true if there's any cached data available
    func hasCachedData() async throws -> Bool
}

// Default implementations for non-cached Zotero data sources
public extension ZoteroDataSourceProtocol {
    func fetchCachedDailyStats(from startDate: Date, to endDate: Date) async throws -> [ZoteroDailyStats] {
        []
    }

    func fetchCachedReadingStatus() async throws -> ZoteroReadingStatus? {
        nil
    }

    func hasCachedData() async throws -> Bool {
        false
    }
}

/// Protocol for Wii Fit data source
public protocol WiiFitDataSourceProtocol: DataSourceRepositoryProtocol {
    /// Syncs data from a Wii running the homebrew app (uses configured IP)
    /// - Returns: Sync result with measurements and activities
    func sync() async throws -> WiiFitSyncResult

    /// Fetches measurements for a date range (from cache or remote)
    func fetchMeasurements(from startDate: Date, to endDate: Date) async throws -> [WiiFitMeasurement]

    /// Fetches activities for a date range (from cache or remote)
    func fetchActivities(from startDate: Date, to endDate: Date) async throws -> [WiiFitActivity]

    /// Tests connection to the configured Wii
    func testConnection() async throws -> Bool

    /// Fetches available profiles from the last sync
    func fetchAvailableProfiles() async throws -> [WiiFitProfileInfo]

    // MARK: - Cache Methods

    /// Returns cached measurements without network access
    func fetchCachedMeasurements(from startDate: Date, to endDate: Date) async throws -> [WiiFitMeasurement]

    /// Returns cached activities without network access
    func fetchCachedActivities(from startDate: Date, to endDate: Date) async throws -> [WiiFitActivity]

    /// Returns true if there's any cached data available
    func hasCachedData() async throws -> Bool
}

// Default implementations for non-cached Wii Fit data sources
public extension WiiFitDataSourceProtocol {
    func fetchCachedMeasurements(from startDate: Date, to endDate: Date) async throws -> [WiiFitMeasurement] {
        []
    }

    func fetchCachedActivities(from startDate: Date, to endDate: Date) async throws -> [WiiFitActivity] {
        []
    }

    func hasCachedData() async throws -> Bool {
        false
    }
}

/// Result of a Wii Fit sync operation
public struct WiiFitSyncResult: Sendable {
    /// Measurements synced
    public let measurements: [WiiFitMeasurement]

    /// Activities synced
    public let activities: [WiiFitActivity]

    /// Profiles found on the Wii
    public let profilesFound: [WiiFitProfileInfo]

    public init(
        measurements: [WiiFitMeasurement],
        activities: [WiiFitActivity],
        profilesFound: [WiiFitProfileInfo]
    ) {
        self.measurements = measurements
        self.activities = activities
        self.profilesFound = profilesFound
    }
}

/// Information about a Wii Fit profile
public struct WiiFitProfileInfo: Codable, Sendable, Identifiable, Equatable {
    public var id: String { name }

    /// Profile/Mii name
    public let name: String

    /// Height in centimeters
    public let heightCm: Int

    /// Number of measurements available
    public let measurementCount: Int

    /// Number of activities available
    public let activityCount: Int

    public init(
        name: String,
        heightCm: Int,
        measurementCount: Int,
        activityCount: Int
    ) {
        self.name = name
        self.heightCm = heightCm
        self.measurementCount = measurementCount
        self.activityCount = activityCount
    }
}
