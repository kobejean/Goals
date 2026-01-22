import Foundation
import SwiftUI
import GoalsDomain

/// Provides insight data for widgets by reading from the shared cache
public actor WidgetDataProvider {
    private let cache: WidgetDataCache

    public init() {
        self.cache = WidgetDataCache()
    }

    /// Fetches insight data for a given type
    public func fetchInsightData(for type: InsightType) async -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        let endDate = Date()
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -90, to: endDate) else {
            return (nil, nil)
        }

        switch type {
        case .typeQuicker:
            let stats = (try? await cache.fetch(TypeQuickerStats.self, from: startDate, to: endDate)) ?? []
            return InsightBuilders.buildTypeQuickerInsight(from: stats)

        case .atCoder:
            // Fetch contest history (no date range - we want all contests for rating trend)
            let contestHistory = (try? await cache.fetch(AtCoderContestResult.self)) ?? []
            let dailyEffort = (try? await cache.fetch(AtCoderDailyEffort.self, from: startDate, to: endDate)) ?? []
            return InsightBuilders.buildAtCoderInsight(from: contestHistory, dailyEffort: dailyEffort)

        case .sleep:
            let sleepData = (try? await cache.fetch(SleepDailySummary.self, from: startDate, to: endDate)) ?? []
            return InsightBuilders.buildSleepInsight(from: sleepData)

        case .tasks:
            let summaries = (try? await cache.fetch(TaskDailySummary.self, from: startDate, to: endDate)) ?? []
            return InsightBuilders.buildTasksInsight(from: summaries)

        case .anki:
            let stats = (try? await cache.fetch(AnkiDailyStats.self, from: startDate, to: endDate)) ?? []
            return InsightBuilders.buildAnkiInsight(from: stats)

        case .zotero:
            let stats = (try? await cache.fetch(ZoteroDailyStats.self, from: startDate, to: endDate)) ?? []
            // Get the most recent reading status from cache
            let readingStatuses = (try? await cache.fetch(ZoteroReadingStatus.self)) ?? []
            let readingStatus = readingStatuses.max { $0.date < $1.date }
            return InsightBuilders.buildZoteroInsight(from: stats, readingStatus: readingStatus)
        }
    }
}
