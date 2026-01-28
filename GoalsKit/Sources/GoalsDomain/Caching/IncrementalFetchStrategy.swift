import Foundation

/// Protocol defining an incremental fetch strategy for cached data sources.
/// Forces developers to explicitly choose how to handle incremental data fetching.
///
/// Built-in strategies:
/// - `DateBasedStrategy`: For immutable historical data (TypeQuicker, Anki, HealthKit)
/// - `VersionBasedStrategy`: For mutable data with version tracking (Zotero)
public protocol IncrementalFetchStrategy: Sendable {
    associatedtype Metadata: Codable & Sendable

    /// Unique key for storing this strategy's metadata in the cache.
    /// Should be unique per data source type (e.g., "typeQuicker.stats", "anki.dailyStats").
    var strategyKey: String { get }

    /// Calculate what date range to fetch based on stored metadata and requested range.
    /// - Parameters:
    ///   - requested: The date range the caller wants data for
    ///   - metadata: Previously stored metadata (nil if first fetch)
    /// - Returns: The actual date range to fetch from remote
    func calculateFetchRange(
        requested: (start: Date, end: Date),
        metadata: Metadata?
    ) -> (start: Date, end: Date)

    /// Update metadata after a successful fetch.
    /// - Parameters:
    ///   - previous: Previously stored metadata (nil if first fetch)
    ///   - fetchedRange: The range that was successfully fetched
    ///   - fetchedAt: The timestamp of the fetch
    /// - Returns: Updated metadata to store
    func updateMetadata(
        previous: Metadata?,
        fetchedRange: (start: Date, end: Date),
        fetchedAt: Date
    ) -> Metadata
}
