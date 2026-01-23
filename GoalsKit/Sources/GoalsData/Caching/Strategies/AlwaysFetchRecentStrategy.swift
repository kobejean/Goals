import Foundation
import GoalsDomain

/// Strategy that always fetches the last N days of data.
/// Useful for simple cases or data that needs frequent refresh.
/// This is stateless - it doesn't track fetch history.
public struct AlwaysFetchRecentStrategy: IncrementalFetchStrategy, Sendable {
    public struct Metadata: Codable, Sendable {
        // Stateless - empty metadata
        public init() {}
    }

    public let strategyKey: String

    /// Number of recent days to always fetch
    public let recentDays: Int

    public init(strategyKey: String, recentDays: Int) {
        self.strategyKey = strategyKey
        self.recentDays = recentDays
    }

    public func calculateFetchRange(
        requested: (start: Date, end: Date),
        metadata: Metadata?
    ) -> (start: Date, end: Date) {
        let calendar = Calendar.current

        // Calculate recentDays back from end date
        let recentStart = calendar.date(
            byAdding: .day,
            value: -recentDays,
            to: requested.end
        ) ?? requested.start

        // Fetch max(recentStart, requestedStart) to requestedEnd
        let fetchStart = max(
            calendar.startOfDay(for: recentStart),
            calendar.startOfDay(for: requested.start)
        )

        return (fetchStart, requested.end)
    }

    public func updateMetadata(
        previous: Metadata?,
        fetchedRange: (start: Date, end: Date),
        fetchedAt: Date
    ) -> Metadata {
        // Stateless - return empty metadata
        return Metadata()
    }
}
