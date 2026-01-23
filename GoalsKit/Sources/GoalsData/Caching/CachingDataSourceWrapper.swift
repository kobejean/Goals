import Foundation
import GoalsDomain

/// Protocol for cached data source wrappers that delegate to a remote source.
/// Provides default implementations for configuration passthrough and cache helper methods.
///
/// **IMPORTANT**: Conforming types MUST declare an `incrementalStrategy` property.
/// This forces developers to explicitly choose how incremental fetching works,
/// preventing ad-hoc implementations and ensuring consistency.
///
/// Built-in strategies:
/// - `DateBasedStrategy`: For immutable historical data (most common)
/// - `VersionBasedStrategy`: For mutable data with API version tracking
/// - `AlwaysFetchRecentStrategy`: For simple cases that always fetch recent data
public protocol CachingDataSourceWrapper: DataSourceRepositoryProtocol {
    associatedtype RemoteSource: DataSourceRepositoryProtocol
    associatedtype Strategy: IncrementalFetchStrategy

    var remote: RemoteSource { get }
    var cache: DataCache { get }

    /// REQUIRED: The strategy for incremental data fetching.
    /// Developers must explicitly choose a strategy when creating a cached data source.
    var incrementalStrategy: Strategy { get }
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

// MARK: - Incremental Fetch Strategy Helpers

public extension CachingDataSourceWrapper {
    /// Calculate the fetch range based on the incremental strategy and stored metadata.
    /// - Parameter requested: The date range the caller wants data for
    /// - Returns: The actual date range to fetch from remote
    func calculateIncrementalFetchRange(
        for requested: (start: Date, end: Date)
    ) async throws -> (start: Date, end: Date) {
        let metadata = try await cache.fetchStrategyMetadata(for: incrementalStrategy)
        return incrementalStrategy.calculateFetchRange(requested: requested, metadata: metadata)
    }

    /// Record that a fetch was successful and update the strategy metadata.
    /// - Parameter range: The date range that was successfully fetched
    func recordSuccessfulFetch(range: (start: Date, end: Date)) async throws {
        let previous = try await cache.fetchStrategyMetadata(for: incrementalStrategy)
        let updated = incrementalStrategy.updateMetadata(
            previous: previous,
            fetchedRange: range,
            fetchedAt: Date()
        )
        try await cache.storeStrategyMetadata(updated, for: incrementalStrategy)
    }
}

// MARK: - Date Range Calculation (Legacy - for gap-filling)

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
        let endDay = calendar.startOfDay(for: endDate)

        // Limit iteration to a reasonable lookback (e.g., 2 years = 730 days)
        // For very old data, just fetch from the earliest cached date or use a bounded lookback
        let maxLookbackDays = 730
        let boundedStartDate: Date
        if let daysBetween = calendar.dateComponents([.day], from: startDate, to: endDate).day,
           daysBetween > maxLookbackDays {
            boundedStartDate = calendar.date(byAdding: .day, value: -maxLookbackDays, to: endDate) ?? startDate
            print("[CachingDataSourceWrapper] Date range too large (\(daysBetween) days), limiting to \(maxLookbackDays) days")
        } else {
            boundedStartDate = startDate
        }

        var checkDate = calendar.startOfDay(for: boundedStartDate)

        // Convert cached dates to a Set of day components for reliable comparison
        // (Date equality can fail due to floating point TimeInterval differences)
        let cachedDayIdentifiers = Set(cachedDates.map { date -> Int in
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            return (components.year ?? 0) * 10000 + (components.month ?? 0) * 100 + (components.day ?? 0)
        })

        print("[CachingDataSourceWrapper] Cached day identifiers count: \(cachedDayIdentifiers.count)")

        var missingRanges: [(start: Date, end: Date)] = []
        var currentStart: Date? = nil

        while checkDate <= endDay {
            let checkComponents = calendar.dateComponents([.year, .month, .day], from: checkDate)
            let checkIdentifier = (checkComponents.year ?? 0) * 10000 + (checkComponents.month ?? 0) * 100 + (checkComponents.day ?? 0)

            if !cachedDayIdentifiers.contains(checkIdentifier) {
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

        print("[CachingDataSourceWrapper] Found \(missingRanges.count) missing ranges")

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
