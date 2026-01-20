import Foundation
import GoalsDomain

/// Protocol for cached data source wrappers that delegate to a remote source
/// Provides default implementations for configuration passthrough and cache helper methods
public protocol CachingDataSourceWrapper: DataSourceRepositoryProtocol {
    associatedtype RemoteSource: DataSourceRepositoryProtocol

    var remote: RemoteSource { get }
    var cache: DataCache { get }
}

// MARK: - Default Passthrough Implementations

public extension CachingDataSourceWrapper {
    var dataSourceType: DataSourceType { remote.dataSourceType }

    nonisolated var availableMetrics: [MetricInfo] { remote.availableMetrics }

    nonisolated func metricValue(for key: String, from stats: Any) -> Double? {
        remote.metricValue(for: key, from: stats)
    }

    func isConfigured() async -> Bool {
        await remote.isConfigured()
    }

    func configure(settings: DataSourceSettings) async throws {
        try await remote.configure(settings: settings)
    }

    func clearConfiguration() async throws {
        try await remote.clearConfiguration()
    }
}

// MARK: - Date Range Calculation

public extension CachingDataSourceWrapper {
    /// Calculate missing date ranges that need to be fetched from remote
    /// - Parameters:
    ///   - startDate: Start of the desired date range
    ///   - endDate: End of the desired date range
    ///   - cachedDates: Set of dates that are already cached
    /// - Returns: Array of (start, end) date tuples representing missing ranges
    func calculateMissingDateRanges(
        from startDate: Date,
        to endDate: Date,
        cachedDates: Set<Date>
    ) -> [(start: Date, end: Date)] {
        let calendar = Calendar.current
        var missingRanges: [(start: Date, end: Date)] = []
        var currentStart: Date? = nil

        var checkDate = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        while checkDate <= endDay {
            if !cachedDates.contains(checkDate) {
                if currentStart == nil {
                    currentStart = checkDate
                }
            } else {
                if let start = currentStart {
                    let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                    missingRanges.append((start, previousDay))
                    currentStart = nil
                }
            }
            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
        }

        if let start = currentStart {
            missingRanges.append((start, endDay))
        }

        return missingRanges
    }
}

// MARK: - Cache Helper Methods

public extension CachingDataSourceWrapper {
    /// Store records and return from cache (single source of truth pattern)
    /// - Parameters:
    ///   - records: Records to store
    ///   - from: Optional start date for fetch
    ///   - to: Optional end date for fetch
    /// - Returns: Cached records within the date range
    func storeAndFetch<T: CacheableRecord>(
        _ records: [T],
        from: Date? = nil,
        to: Date? = nil
    ) async throws -> [T] {
        if !records.isEmpty {
            try await cache.store(records)
        }
        return try await cache.fetch(T.self, from: from, to: to)
    }

    /// Fetch cached records without hitting remote
    func fetchCached<T: CacheableRecord>(
        _ type: T.Type,
        from: Date? = nil,
        to: Date? = nil
    ) async throws -> [T] {
        try await cache.fetch(type, from: from, to: to)
    }

    /// Check if any cached data exists for a record type
    func hasCached<T: CacheableRecord>(_ type: T.Type) async throws -> Bool {
        try await cache.hasCachedData(for: type)
    }
}
