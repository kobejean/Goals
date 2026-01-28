import Foundation
import GoalsDomain

/// Protocol for data sources that support optional caching.
/// Provides a unified interface for data sources that can work with or without a cache.
///
/// **Protocol Hierarchy:**
/// - `CacheableDataSource` - Base protocol with cache helpers (for custom caching logic)
/// - `IncrementalCacheableDataSource` - Standard pattern for immutable date-based data (recommended)
///
/// **When to use which:**
/// - **IncrementalCacheableDataSource**: For immutable historical data (TypeQuicker, Anki, HealthKit Sleep).
///   Just provide `cacheStrategyKey` and call `cachedFetch(fetcher:from:to:)`.
/// - **CacheableDataSource**: For custom caching logic (count-based validation, version-based sync).
///   Use individual helpers (`fetchCached`, `storeInCache`, etc.).
public protocol CacheableDataSource: DataSourceRepositoryProtocol {
    /// The cache to use for storing and retrieving data.
    /// When nil, data source operates without caching.
    var cache: DataCache? { get }
}

// MARK: - Cached Fetch Helper

public extension CacheableDataSource {
    /// Performs a cached fetch operation with a custom strategy:
    /// 1. Calculate fetch range based on strategy
    /// 2. Fetch from remote
    /// 3. Store results in cache
    /// 4. Record successful fetch
    /// 5. On error, return cached data if available
    /// 6. Return from cache (single source of truth)
    ///
    /// - Parameters:
    ///   - strategy: The incremental fetch strategy to use
    ///   - fetcher: Function to fetch data from remote
    ///   - from: Start date of requested range
    ///   - to: End date of requested range
    /// - Returns: Array of cached records (may include previously cached data)
    func cachedFetch<T: CacheableRecord, S: IncrementalFetchStrategy>(
        strategy: S,
        fetcher: (Date, Date) async throws -> [T],
        from: Date,
        to: Date
    ) async throws -> [T] {
        guard let cache = cache else {
            // No caching - just fetch and return
            return try await fetcher(from, to)
        }

        // Calculate what we need to fetch based on strategy
        let metadata = try await cache.fetchStrategyMetadata(for: strategy)
        let fetchRange = strategy.calculateFetchRange(requested: (from, to), metadata: metadata)

        do {
            let remoteData = try await fetcher(fetchRange.start, fetchRange.end)
            if !remoteData.isEmpty {
                try await cache.store(remoteData)
            }

            // Record successful fetch
            let updatedMetadata = strategy.updateMetadata(
                previous: metadata,
                fetchedRange: (fetchRange.start, fetchRange.end),
                fetchedAt: Date()
            )
            try await cache.storeStrategyMetadata(updatedMetadata, for: strategy)
        } catch {
            // On error, check if we have cached data to fall back on
            let cachedData = try await cache.fetch(T.self, from: from, to: to)
            if cachedData.isEmpty {
                throw error
            }
            // Continue to return cached data below
        }

        // Single source of truth: always return from cache
        return try await cache.fetch(T.self, from: from, to: to)
    }
}

// MARK: - Cache Helper Methods

public extension CacheableDataSource {
    /// Fetch cached records without hitting remote.
    /// Returns empty array if no cache is configured.
    func fetchCached<T: CacheableRecord>(
        _ type: T.Type,
        from: Date? = nil,
        to: Date? = nil
    ) async throws -> [T] {
        guard let cache = cache else { return [] }
        return try await cache.fetch(type, from: from, to: to)
    }

    /// Check if any cached data exists for a record type.
    /// Returns false if no cache is configured.
    func hasCached<T: CacheableRecord>(_ type: T.Type) async throws -> Bool {
        guard let cache = cache else { return false }
        return try await cache.hasCachedData(for: type)
    }

    /// Store records in cache.
    /// No-op if no cache is configured.
    func storeInCache<T: CacheableRecord>(_ records: [T]) async throws {
        guard let cache = cache, !records.isEmpty else { return }
        try await cache.store(records)
    }

    /// Store records and return from cache (single source of truth pattern).
    /// If no cache is configured, returns the records directly.
    func storeAndFetch<T: CacheableRecord>(
        _ records: [T],
        from: Date? = nil,
        to: Date? = nil
    ) async throws -> [T] {
        guard let cache = cache else { return records }

        if !records.isEmpty {
            try await cache.store(records)
        }
        return try await cache.fetch(T.self, from: from, to: to)
    }
}

// MARK: - Strategy Metadata Helpers

public extension CacheableDataSource {
    /// Calculate the fetch range based on the incremental strategy and stored metadata.
    /// If no cache is configured, returns the requested range unchanged.
    func calculateIncrementalFetchRange<S: IncrementalFetchStrategy>(
        strategy: S,
        for requested: (start: Date, end: Date)
    ) async throws -> (start: Date, end: Date) {
        guard let cache = cache else {
            return requested
        }
        let metadata = try await cache.fetchStrategyMetadata(for: strategy)
        return strategy.calculateFetchRange(requested: requested, metadata: metadata)
    }

    /// Record that a fetch was successful and update the strategy metadata.
    func recordSuccessfulFetch<S: IncrementalFetchStrategy>(
        strategy: S,
        range: (start: Date, end: Date)
    ) async throws {
        guard let cache = cache else { return }
        let previous = try await cache.fetchStrategyMetadata(for: strategy)
        let updated = strategy.updateMetadata(
            previous: previous,
            fetchedRange: range,
            fetchedAt: Date()
        )
        try await cache.storeStrategyMetadata(updated, for: strategy)
    }
}
