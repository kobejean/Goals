import Foundation
import GoalsDomain

/// Protocol for data sources using the standard incremental caching pattern.
/// Best for immutable historical data where records don't change once created.
///
/// **Usage:**
/// ```swift
/// public actor MyDataSource: MyDataSourceProtocol, IncrementalCacheableDataSource {
///     public let cache: DataCache?
///     public nonisolated let cacheStrategyKey = "my.stats"
///
///     public init() { self.cache = nil }  // For testing
///     public init(cache: DataCache) { self.cache = cache }  // For production
///
///     public func fetchData(from: Date, to: Date) async throws -> [MyData] {
///         try await cachedFetch(fetcher: fetchFromRemote, from: from, to: to)
///     }
///
///     private func fetchFromRemote(from: Date, to: Date) async throws -> [MyData] {
///         // Fetch from API...
///     }
/// }
/// ```
public protocol IncrementalCacheableDataSource: CacheableDataSource {
    /// Unique key for storing strategy metadata in the cache.
    /// Convention: "sourceName.dataType" (e.g., "anki.dailyStats", "typeQuicker.stats")
    var cacheStrategyKey: String { get }

    /// Number of recent days to always re-fetch (volatile window).
    /// Data within this window is considered potentially incomplete and always refreshed.
    /// Default is 1 day. Override for data that may update more frequently.
    var volatileWindowDays: Int { get }
}

public extension IncrementalCacheableDataSource {
    /// Default volatile window of 1 day.
    var volatileWindowDays: Int { 1 }

    /// Performs a cached fetch using the standard DateBasedStrategy.
    /// This is the recommended method for most data sources with immutable historical data.
    ///
    /// - Parameters:
    ///   - fetcher: Function to fetch data from remote
    ///   - from: Start date of requested range
    ///   - to: End date of requested range
    /// - Returns: Array of cached records (may include previously cached data)
    func cachedFetch<T: CacheableRecord>(
        fetcher: (Date, Date) async throws -> [T],
        from: Date,
        to: Date
    ) async throws -> [T] {
        let strategy = DateBasedStrategy(
            strategyKey: cacheStrategyKey,
            volatileWindowDays: volatileWindowDays
        )
        return try await cachedFetch(strategy: strategy, fetcher: fetcher, from: from, to: to)
    }
}
