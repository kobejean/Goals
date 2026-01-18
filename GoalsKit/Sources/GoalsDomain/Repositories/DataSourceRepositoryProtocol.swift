import Foundation

/// Protocol defining the contract for external data source operations
public protocol DataSourceRepositoryProtocol: Sendable {
    /// The type of data source this repository handles
    var dataSourceType: DataSourceType { get }

    /// Metrics available from this data source
    var availableMetrics: [MetricInfo] { get }

    /// Fetches data from the external source for a date range
    func fetchData(from startDate: Date, to endDate: Date) async throws -> [DataPoint]

    /// Fetches the latest data from the external source
    func fetchLatest() async throws -> DataPoint?

    /// Returns true if the data source is configured and ready to use
    func isConfigured() async -> Bool

    /// Configures the data source with credentials or settings
    func configure(settings: DataSourceSettings) async throws

    /// Clears the configuration for this data source
    func clearConfiguration() async throws

    /// Extract a metric value from stats data
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
}

/// Protocol for AtCoder data source
public protocol AtCoderDataSourceProtocol: DataSourceRepositoryProtocol {
    /// Fetches AtCoder statistics
    func fetchStats() async throws -> AtCoderStats?

    /// Fetches contest history
    func fetchContestHistory() async throws -> [AtCoderStats]
}

/// Protocol for Finance data source
public protocol FinanceDataSourceProtocol: DataSourceRepositoryProtocol {
    /// Fetches finance statistics for a date range
    func fetchStats(from startDate: Date, to endDate: Date) async throws -> [FinanceStats]

    /// Fetches the latest finance statistics
    func fetchLatestStats() async throws -> FinanceStats?
}
