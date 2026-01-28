import Foundation
import SwiftData
import GoalsDomain
import GoalsData

/// Read-only SwiftData cache access for widgets
public actor WidgetDataCache {
    private let modelContainer: ModelContainer?

    public init() {
        // Initialize with shared container if available
        self.modelContainer = Self.createSharedModelContainer()
    }

    /// Creates a model container using the shared App Group storage with unified schema
    private static func createSharedModelContainer() -> ModelContainer? {
        guard let storeURL = SharedStorage.sharedMainStoreURL else {
            return nil
        }

        do {
            // Use unified schema to match app's main container
            let schema = UnifiedSchema.createSchema()

            let configuration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )

            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("WidgetDataCache: Failed to create model container: \(error)")
            return nil
        }
    }

    /// Fetches cached records within an optional date range using native SwiftData models
    public func fetch<T: CacheableRecord>(
        _ type: T.Type,
        from startDate: Date? = nil,
        to endDate: Date? = nil
    ) async throws -> [T] {
        guard let modelContainer else {
            return []
        }

        let context = ModelContext(modelContainer)

        // Route to type-specific fetch implementation
        switch type {
        case is TypeQuickerStats.Type:
            return try fetchTypeQuickerStats(from: startDate, to: endDate, context: context) as! [T]
        case is AtCoderContestResult.Type:
            return try fetchAtCoderContestResults(from: startDate, to: endDate, context: context) as! [T]
        case is AtCoderSubmission.Type:
            return try fetchAtCoderSubmissions(from: startDate, to: endDate, context: context) as! [T]
        case is AtCoderDailyEffort.Type:
            return try fetchAtCoderDailyEfforts(from: startDate, to: endDate, context: context) as! [T]
        case is AnkiDailyStats.Type:
            return try fetchAnkiDailyStats(from: startDate, to: endDate, context: context) as! [T]
        case is ZoteroDailyStats.Type:
            return try fetchZoteroDailyStats(from: startDate, to: endDate, context: context) as! [T]
        case is ZoteroReadingStatus.Type:
            return try fetchZoteroReadingStatuses(from: startDate, to: endDate, context: context) as! [T]
        case is SleepDailySummary.Type:
            return try fetchSleepDailySummaries(from: startDate, to: endDate, context: context) as! [T]
        case is TaskDailySummary.Type:
            return try fetchTaskDailySummaries(from: startDate, to: endDate, context: context) as! [T]
        case is NutritionDailySummary.Type:
            return try fetchNutritionDailySummaries(from: startDate, to: endDate, context: context) as! [T]
        default:
            return []
        }
    }

    // MARK: - Type-Specific Fetch Implementations

    private func fetchTypeQuickerStats(from startDate: Date?, to endDate: Date?, context: ModelContext) throws -> [TypeQuickerStats] {
        var descriptor = FetchDescriptor<TypeQuickerStatsModel>()
        if let start = startDate, let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start && $0.recordDate <= end }
        } else if let start = startDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start }
        } else if let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate <= end }
        }
        descriptor.sortBy = [SortDescriptor(\.recordDate)]
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    private func fetchAtCoderContestResults(from startDate: Date?, to endDate: Date?, context: ModelContext) throws -> [AtCoderContestResult] {
        var descriptor = FetchDescriptor<AtCoderContestResultModel>()
        if let start = startDate, let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start && $0.recordDate <= end }
        } else if let start = startDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start }
        } else if let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate <= end }
        }
        descriptor.sortBy = [SortDescriptor(\.recordDate)]
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    private func fetchAtCoderSubmissions(from startDate: Date?, to endDate: Date?, context: ModelContext) throws -> [AtCoderSubmission] {
        var descriptor = FetchDescriptor<AtCoderSubmissionModel>()
        if let start = startDate, let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start && $0.recordDate <= end }
        } else if let start = startDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start }
        } else if let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate <= end }
        }
        descriptor.sortBy = [SortDescriptor(\.recordDate)]
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    private func fetchAtCoderDailyEfforts(from startDate: Date?, to endDate: Date?, context: ModelContext) throws -> [AtCoderDailyEffort] {
        var descriptor = FetchDescriptor<AtCoderDailyEffortModel>()
        if let start = startDate, let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start && $0.recordDate <= end }
        } else if let start = startDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start }
        } else if let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate <= end }
        }
        descriptor.sortBy = [SortDescriptor(\.recordDate)]
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    private func fetchAnkiDailyStats(from startDate: Date?, to endDate: Date?, context: ModelContext) throws -> [AnkiDailyStats] {
        var descriptor = FetchDescriptor<AnkiDailyStatsModel>()
        if let start = startDate, let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start && $0.recordDate <= end }
        } else if let start = startDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start }
        } else if let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate <= end }
        }
        descriptor.sortBy = [SortDescriptor(\.recordDate)]
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    private func fetchZoteroDailyStats(from startDate: Date?, to endDate: Date?, context: ModelContext) throws -> [ZoteroDailyStats] {
        var descriptor = FetchDescriptor<ZoteroDailyStatsModel>()
        if let start = startDate, let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start && $0.recordDate <= end }
        } else if let start = startDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start }
        } else if let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate <= end }
        }
        descriptor.sortBy = [SortDescriptor(\.recordDate)]
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    private func fetchZoteroReadingStatuses(from startDate: Date?, to endDate: Date?, context: ModelContext) throws -> [ZoteroReadingStatus] {
        var descriptor = FetchDescriptor<ZoteroReadingStatusModel>()
        if let start = startDate, let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start && $0.recordDate <= end }
        } else if let start = startDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start }
        } else if let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate <= end }
        }
        descriptor.sortBy = [SortDescriptor(\.recordDate)]
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    private func fetchSleepDailySummaries(from startDate: Date?, to endDate: Date?, context: ModelContext) throws -> [SleepDailySummary] {
        var descriptor = FetchDescriptor<SleepDailySummaryModel>()
        if let start = startDate, let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start && $0.recordDate <= end }
        } else if let start = startDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start }
        } else if let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate <= end }
        }
        descriptor.sortBy = [SortDescriptor(\.recordDate)]
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    private func fetchTaskDailySummaries(from startDate: Date?, to endDate: Date?, context: ModelContext) throws -> [TaskDailySummary] {
        var descriptor = FetchDescriptor<TaskDailySummaryModel>()
        if let start = startDate, let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start && $0.recordDate <= end }
        } else if let start = startDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start }
        } else if let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate <= end }
        }
        descriptor.sortBy = [SortDescriptor(\.recordDate)]
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    private func fetchNutritionDailySummaries(from startDate: Date?, to endDate: Date?, context: ModelContext) throws -> [NutritionDailySummary] {
        var descriptor = FetchDescriptor<NutritionDailySummaryModel>()
        if let start = startDate, let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start && $0.recordDate <= end }
        } else if let start = startDate {
            descriptor.predicate = #Predicate { $0.recordDate >= start }
        } else if let end = endDate {
            descriptor.predicate = #Predicate { $0.recordDate <= end }
        }
        descriptor.sortBy = [SortDescriptor(\.recordDate)]
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    /// Check if cache has data available
    public func hasData<T: CacheableRecord>(for type: T.Type) async -> Bool {
        guard let modelContainer else {
            return false
        }

        let context = ModelContext(modelContainer)

        do {
            switch type {
            case is TypeQuickerStats.Type:
                var descriptor = FetchDescriptor<TypeQuickerStatsModel>()
                descriptor.fetchLimit = 1
                return try !context.fetch(descriptor).isEmpty
            case is AtCoderContestResult.Type:
                var descriptor = FetchDescriptor<AtCoderContestResultModel>()
                descriptor.fetchLimit = 1
                return try !context.fetch(descriptor).isEmpty
            case is AtCoderSubmission.Type:
                var descriptor = FetchDescriptor<AtCoderSubmissionModel>()
                descriptor.fetchLimit = 1
                return try !context.fetch(descriptor).isEmpty
            case is AtCoderDailyEffort.Type:
                var descriptor = FetchDescriptor<AtCoderDailyEffortModel>()
                descriptor.fetchLimit = 1
                return try !context.fetch(descriptor).isEmpty
            case is AnkiDailyStats.Type:
                var descriptor = FetchDescriptor<AnkiDailyStatsModel>()
                descriptor.fetchLimit = 1
                return try !context.fetch(descriptor).isEmpty
            case is ZoteroDailyStats.Type:
                var descriptor = FetchDescriptor<ZoteroDailyStatsModel>()
                descriptor.fetchLimit = 1
                return try !context.fetch(descriptor).isEmpty
            case is ZoteroReadingStatus.Type:
                var descriptor = FetchDescriptor<ZoteroReadingStatusModel>()
                descriptor.fetchLimit = 1
                return try !context.fetch(descriptor).isEmpty
            case is SleepDailySummary.Type:
                var descriptor = FetchDescriptor<SleepDailySummaryModel>()
                descriptor.fetchLimit = 1
                return try !context.fetch(descriptor).isEmpty
            case is TaskDailySummary.Type:
                var descriptor = FetchDescriptor<TaskDailySummaryModel>()
                descriptor.fetchLimit = 1
                return try !context.fetch(descriptor).isEmpty
            case is NutritionDailySummary.Type:
                var descriptor = FetchDescriptor<NutritionDailySummaryModel>()
                descriptor.fetchLimit = 1
                return try !context.fetch(descriptor).isEmpty
            default:
                return false
            }
        } catch {
            return false
        }
    }
}
