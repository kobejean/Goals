import Foundation
import SwiftData
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
    /// The model container to use for storing and retrieving cached data.
    /// When nil, data source operates without caching.
    var modelContainer: ModelContainer? { get }
}

// MARK: - Strategy Metadata Storage

/// UserDefaults key prefix for strategy metadata
private let metadataKeyPrefix = "cache.strategy."

public extension CacheableDataSource {
    /// Store metadata for an incremental fetch strategy.
    /// Metadata is stored in UserDefaults as JSON for simplicity and persistence.
    func storeStrategyMetadata<S: IncrementalFetchStrategy>(
        _ metadata: S.Metadata,
        for strategy: S
    ) throws {
        let key = metadataKeyPrefix + strategy.strategyKey
        let data = try JSONEncoder().encode(metadata)
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Fetch stored metadata for an incremental fetch strategy.
    /// Returns nil if no metadata has been stored yet.
    func fetchStrategyMetadata<S: IncrementalFetchStrategy>(
        for strategy: S
    ) throws -> S.Metadata? {
        let key = metadataKeyPrefix + strategy.strategyKey
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        return try JSONDecoder().decode(S.Metadata.self, from: data)
    }

    /// Clear stored metadata for an incremental fetch strategy.
    func clearStrategyMetadata<S: IncrementalFetchStrategy>(
        for strategy: S
    ) {
        let key = metadataKeyPrefix + strategy.strategyKey
        UserDefaults.standard.removeObject(forKey: key)
    }
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
    ///   - modelType: The SwiftData model type that stores this record type
    ///   - strategy: The incremental fetch strategy to use
    ///   - fetcher: Function to fetch data from remote
    ///   - from: Start date of requested range
    ///   - to: End date of requested range
    /// - Returns: Array of cached records (may include previously cached data)
    func cachedFetch<T: CacheableRecord, M: CacheableModel, S: IncrementalFetchStrategy>(
        modelType: M.Type,
        strategy: S,
        fetcher: (Date, Date) async throws -> [T],
        from: Date,
        to: Date
    ) async throws -> [T] where M.DomainType == T {
        guard let container = modelContainer else {
            // No caching - just fetch and return
            return try await fetcher(from, to)
        }

        // Calculate what we need to fetch based on strategy
        let metadata = try fetchStrategyMetadata(for: strategy)
        let fetchRange = strategy.calculateFetchRange(requested: (from, to), metadata: metadata)

        do {
            let remoteData = try await fetcher(fetchRange.start, fetchRange.end)
            if !remoteData.isEmpty {
                try M.store(remoteData, in: container)
            }

            // Record successful fetch
            let updatedMetadata = strategy.updateMetadata(
                previous: metadata,
                fetchedRange: (fetchRange.start, fetchRange.end),
                fetchedAt: Date()
            )
            try storeStrategyMetadata(updatedMetadata, for: strategy)
        } catch {
            // On error, check if we have cached data to fall back on
            let cachedData = try M.fetch(from: from, to: to, in: container)
            if cachedData.isEmpty {
                throw error
            }
            // Continue to return cached data below
        }

        // Single source of truth: always return from cache
        return try M.fetch(from: from, to: to, in: container)
    }
}

// MARK: - Cache Helper Methods

public extension CacheableDataSource {
    /// Fetch cached records without hitting remote.
    /// Returns empty array if no cache is configured.
    func fetchCached<T: CacheableRecord, M: CacheableModel>(
        _ type: T.Type,
        modelType: M.Type,
        from: Date? = nil,
        to: Date? = nil
    ) throws -> [T] where M.DomainType == T {
        guard let container = modelContainer else { return [] }
        return try M.fetch(from: from, to: to, in: container)
    }

    /// Check if any cached data exists for a record type.
    /// Returns false if no cache is configured.
    func hasCached<T: CacheableRecord, M: CacheableModel>(
        _ type: T.Type,
        modelType: M.Type
    ) throws -> Bool where M.DomainType == T {
        guard let container = modelContainer else { return false }
        return try M.hasData(in: container)
    }

    /// Store records in cache.
    /// No-op if no cache is configured.
    func storeInCache<T: CacheableRecord, M: CacheableModel>(
        _ records: [T],
        modelType: M.Type
    ) throws where M.DomainType == T {
        guard let container = modelContainer, !records.isEmpty else { return }
        try M.store(records, in: container)
    }

    /// Store records and return from cache (single source of truth pattern).
    /// If no cache is configured, returns the records directly.
    func storeAndFetch<T: CacheableRecord, M: CacheableModel>(
        _ records: [T],
        modelType: M.Type,
        from: Date? = nil,
        to: Date? = nil
    ) throws -> [T] where M.DomainType == T {
        guard let container = modelContainer else { return records }

        if !records.isEmpty {
            try M.store(records, in: container)
        }
        return try M.fetch(from: from, to: to, in: container)
    }
}

// MARK: - Strategy Metadata Helpers

public extension CacheableDataSource {
    /// Calculate the fetch range based on the incremental strategy and stored metadata.
    /// If no cache is configured, returns the requested range unchanged.
    func calculateIncrementalFetchRange<S: IncrementalFetchStrategy>(
        strategy: S,
        for requested: (start: Date, end: Date)
    ) throws -> (start: Date, end: Date) {
        guard modelContainer != nil else {
            return requested
        }
        let metadata = try fetchStrategyMetadata(for: strategy)
        return strategy.calculateFetchRange(requested: requested, metadata: metadata)
    }

    /// Record that a fetch was successful and update the strategy metadata.
    func recordSuccessfulFetch<S: IncrementalFetchStrategy>(
        strategy: S,
        range: (start: Date, end: Date)
    ) throws {
        guard modelContainer != nil else { return }
        let previous = try fetchStrategyMetadata(for: strategy)
        let updated = strategy.updateMetadata(
            previous: previous,
            fetchedRange: range,
            fetchedAt: Date()
        )
        try storeStrategyMetadata(updated, for: strategy)
    }
}
