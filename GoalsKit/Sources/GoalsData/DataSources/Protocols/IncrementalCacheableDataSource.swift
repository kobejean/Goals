import Foundation
import SwiftData
import GoalsDomain

/// Protocol for data sources using the standard incremental caching pattern.
/// Best for immutable historical data where records don't change once created.
///
/// **Usage:**
/// ```swift
/// public actor MyDataSource: MyDataSourceProtocol, IncrementalCacheableDataSource {
///     public let modelContainer: ModelContainer?
///     public nonisolated let cacheStrategyKey = "my.stats"
///
///     public init() { self.modelContainer = nil }  // For testing
///     public init(modelContainer: ModelContainer) { self.modelContainer = modelContainer }  // For production
///
///     public func fetchData(from: Date, to: Date) async throws -> [MyData] {
///         try await cachedFetch(modelType: MyDataModel.self, fetcher: fetchFromRemote, from: from, to: to)
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
    ///   - modelType: The SwiftData model type that stores this record type
    ///   - fetcher: Function to fetch data from remote
    ///   - from: Start date of requested range
    ///   - to: End date of requested range
    /// - Returns: Array of cached records (may include previously cached data)
    func cachedFetch<T: CacheableRecord, M: CacheableModel>(
        modelType: M.Type,
        fetcher: (Date, Date) async throws -> [T],
        from: Date,
        to: Date
    ) async throws -> [T] where M.DomainType == T {
        let strategy = DateBasedStrategy(
            strategyKey: cacheStrategyKey,
            volatileWindowDays: volatileWindowDays
        )
        return try await cachedFetch(modelType: modelType, strategy: strategy, fetcher: fetcher, from: from, to: to)
    }
}
