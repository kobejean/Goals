import Foundation
import GoalsDomain

/// Strategy for data sources with immutable historical data.
/// Only fetches from (lastFetch - volatileWindow) to requested end date.
/// Appropriate for: TypeQuicker, Anki, AtCoder, HealthKit (past data doesn't change).
public struct DateBasedStrategy: IncrementalFetchStrategy, Sendable {
    public struct Metadata: Codable, Sendable {
        public let lastFetchDate: Date

        public init(lastFetchDate: Date) {
            self.lastFetchDate = lastFetchDate
        }
    }

    public let strategyKey: String

    /// Number of days before lastFetchDate that might still have changed.
    /// For most sources this is 1 (today's data might update throughout the day).
    public let volatileWindowDays: Int

    public init(strategyKey: String, volatileWindowDays: Int = 1) {
        self.strategyKey = strategyKey
        self.volatileWindowDays = volatileWindowDays
    }

    public func calculateFetchRange(
        requested: (start: Date, end: Date),
        metadata: Metadata?
    ) -> (start: Date, end: Date) {
        let calendar = Calendar.current

        guard let metadata = metadata else {
            // No previous fetch - fetch full requested range
            return (calendar.startOfDay(for: requested.start), requested.end)
        }

        // Calculate the volatile window start (data that might have changed)
        let volatileStart = calendar.date(
            byAdding: .day,
            value: -volatileWindowDays,
            to: metadata.lastFetchDate
        ) ?? metadata.lastFetchDate

        // Fetch from max(volatileStart, requestedStart) to requestedEnd
        let fetchStart = max(
            calendar.startOfDay(for: volatileStart),
            calendar.startOfDay(for: requested.start)
        )

        return (fetchStart, requested.end)
    }

    public func updateMetadata(
        previous: Metadata?,
        fetchedRange: (start: Date, end: Date),
        fetchedAt: Date
    ) -> Metadata {
        let calendar = Calendar.current
        // Record the end of the fetched range as lastFetchDate
        return Metadata(lastFetchDate: calendar.startOfDay(for: fetchedRange.end))
    }
}
