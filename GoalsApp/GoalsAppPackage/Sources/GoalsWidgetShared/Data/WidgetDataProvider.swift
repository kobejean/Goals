import Foundation
import SwiftUI
import SwiftData
import GoalsDomain
import GoalsData

/// Provides insight data for widgets by reading from the shared cache.
/// Uses model static methods directly to ensure widget and app use identical data loading logic.
public actor WidgetDataProvider {
    private let modelContainer: ModelContainer?

    public init() {
        self.modelContainer = Self.createSharedModelContainer()
    }

    /// Creates a ModelContainer using the shared App Group storage
    private static func createSharedModelContainer() -> ModelContainer? {
        guard let storeURL = SharedStorage.sharedMainStoreURL else {
            return nil
        }

        do {
            let schema = UnifiedSchema.createSchema()
            let configuration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("WidgetDataProvider: Failed to create ModelContainer: \(error)")
            return nil
        }
    }

    /// Fetches insight data for a given type
    public func fetchInsightData(for type: InsightType) async -> (summary: InsightSummary?, activityData: InsightActivityData?) {
        guard let container = modelContainer else {
            return (nil, nil)
        }

        let endDate = Date()
        let calendar = Calendar.current
        // Fetch 30 days of data - InsightBuilders filters to this range internally
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) else {
            return (nil, nil)
        }

        switch type {
        case .typeQuicker:
            let stats = (try? TypeQuickerStatsModel.fetch(from: startDate, to: endDate, in: container)) ?? []
            return InsightBuilders.buildTypeQuickerInsight(from: stats)

        case .atCoder:
            // Fetch contest history (no date range - we want all contests for rating trend)
            let contestHistory = (try? AtCoderContestResultModel.fetch(in: container)) ?? []
            let dailyEffort = (try? AtCoderDailyEffortModel.fetch(from: startDate, to: endDate, in: container)) ?? []
            return InsightBuilders.buildAtCoderInsight(from: contestHistory, dailyEffort: dailyEffort)

        case .sleep:
            let sleepData = (try? SleepDailySummaryModel.fetch(from: startDate, to: endDate, in: container)) ?? []
            return InsightBuilders.buildSleepInsight(from: sleepData)

        case .tasks:
            let summaries = (try? TaskDailySummaryModel.fetch(from: startDate, to: endDate, in: container)) ?? []
            return InsightBuilders.buildTasksInsight(from: summaries)

        case .anki:
            let stats = (try? AnkiDailyStatsModel.fetch(from: startDate, to: endDate, in: container)) ?? []
            return InsightBuilders.buildAnkiInsight(from: stats)

        case .zotero:
            let stats = (try? ZoteroDailyStatsModel.fetch(from: startDate, to: endDate, in: container)) ?? []
            // Get the most recent reading status from cache
            let readingStatuses = (try? ZoteroReadingStatusModel.fetch(in: container)) ?? []
            let readingStatus = readingStatuses.max { $0.date < $1.date }
            return InsightBuilders.buildZoteroInsight(from: stats, readingStatus: readingStatus)

        case .nutrition:
            let summaries = (try? NutritionDailySummaryModel.fetch(from: startDate, to: endDate, in: container)) ?? []
            return InsightBuilders.buildNutritionInsight(from: summaries)
        }
    }
}
