import Foundation
import GoalsDomain

/// Strategy for data sources that support version-based change tracking.
/// Uses API-provided version numbers to fetch only changed items.
/// Appropriate for: Zotero (annotations can be edited, API supports versioning).
public struct VersionBasedStrategy: IncrementalFetchStrategy, Sendable {
    public struct Metadata: Codable, Sendable {
        public let lastVersion: Int
        public let lastFetchDate: Date

        public init(lastVersion: Int, lastFetchDate: Date) {
            self.lastVersion = lastVersion
            self.lastFetchDate = lastFetchDate
        }
    }

    public let strategyKey: String

    public init(strategyKey: String) {
        self.strategyKey = strategyKey
    }

    /// For version-based strategy, we always fetch the full requested range
    /// but the API call will include the sinceVersion parameter.
    public func calculateFetchRange(
        requested: (start: Date, end: Date),
        metadata: Metadata?
    ) -> (start: Date, end: Date) {
        // Version-based APIs handle incremental logic server-side
        // We always request the full range but use version for efficiency
        return requested
    }

    public func updateMetadata(
        previous: Metadata?,
        fetchedRange: (start: Date, end: Date),
        fetchedAt: Date
    ) -> Metadata {
        // Note: The actual version comes from the API response.
        // This default implementation preserves the previous version if available.
        // Callers should use updateMetadata(previous:fetchedRange:fetchedAt:newVersion:)
        return Metadata(
            lastVersion: previous?.lastVersion ?? 0,
            lastFetchDate: fetchedAt
        )
    }

    /// Update metadata with a new version from the API response.
    public func updateMetadata(
        previous: Metadata?,
        fetchedRange: (start: Date, end: Date),
        fetchedAt: Date,
        newVersion: Int
    ) -> Metadata {
        return Metadata(
            lastVersion: newVersion,
            lastFetchDate: fetchedAt
        )
    }

    /// Get the version to use for incremental fetch (nil for full fetch).
    public func versionForIncrementalFetch(metadata: Metadata?) -> Int? {
        return metadata?.lastVersion
    }
}
