import Foundation
import SwiftData
import GoalsDomain

/// Actor responsible for caching domain objects in SwiftData
/// Provides thread-safe operations for storing and retrieving cached records
public actor DataCache {
    private let modelContainer: ModelContainer

    /// UserDefaults key prefix for strategy metadata
    private static let metadataKeyPrefix = "cache.strategy."

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Strategy Metadata Storage

    /// Store metadata for an incremental fetch strategy.
    /// Metadata is stored in UserDefaults as JSON for simplicity and persistence.
    public func storeStrategyMetadata<S: IncrementalFetchStrategy>(
        _ metadata: S.Metadata,
        for strategy: S
    ) throws {
        let key = Self.metadataKeyPrefix + strategy.strategyKey
        let data = try JSONEncoder().encode(metadata)
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Fetch stored metadata for an incremental fetch strategy.
    /// Returns nil if no metadata has been stored yet.
    public func fetchStrategyMetadata<S: IncrementalFetchStrategy>(
        for strategy: S
    ) throws -> S.Metadata? {
        let key = Self.metadataKeyPrefix + strategy.strategyKey
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        return try JSONDecoder().decode(S.Metadata.self, from: data)
    }

    /// Clear stored metadata for an incremental fetch strategy.
    public func clearStrategyMetadata<S: IncrementalFetchStrategy>(
        for strategy: S
    ) {
        let key = Self.metadataKeyPrefix + strategy.strategyKey
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Store Operations

    /// Stores multiple records in the cache using native SwiftData models
    /// - Parameter records: Array of records conforming to CacheableRecord
    /// - Note: Uses conflict resolution based on fetchedAt timestamp (newer wins)
    public func store<T: CacheableRecord>(_ records: [T]) async throws {
        guard !records.isEmpty else { return }

        let context = ModelContext(modelContainer)
        let fetchedAt = Date()

        for record in records {
            try storeRecord(record, in: context, fetchedAt: fetchedAt)
        }

        try context.save()
    }

    /// Stores a single record in the cache
    public func store<T: CacheableRecord>(_ record: T) async throws {
        try await store([record])
    }

    /// Type-specific store implementation using native SwiftData models
    private func storeRecord<T: CacheableRecord>(_ record: T, in context: ModelContext, fetchedAt: Date) throws {
        let cacheKey = record.cacheKey

        // Route to type-specific implementation
        switch record {
        case let stats as TypeQuickerStats:
            try storeTypeQuickerStats(stats, cacheKey: cacheKey, in: context, fetchedAt: fetchedAt)
        case let result as AtCoderContestResult:
            try storeAtCoderContestResult(result, cacheKey: cacheKey, in: context, fetchedAt: fetchedAt)
        case let submission as AtCoderSubmission:
            try storeAtCoderSubmission(submission, cacheKey: cacheKey, in: context, fetchedAt: fetchedAt)
        case let effort as AtCoderDailyEffort:
            try storeAtCoderDailyEffort(effort, cacheKey: cacheKey, in: context, fetchedAt: fetchedAt)
        case let stats as AnkiDailyStats:
            try storeAnkiDailyStats(stats, cacheKey: cacheKey, in: context, fetchedAt: fetchedAt)
        case let stats as ZoteroDailyStats:
            try storeZoteroDailyStats(stats, cacheKey: cacheKey, in: context, fetchedAt: fetchedAt)
        case let status as ZoteroReadingStatus:
            try storeZoteroReadingStatus(status, cacheKey: cacheKey, in: context, fetchedAt: fetchedAt)
        case let summary as SleepDailySummary:
            try storeSleepDailySummary(summary, cacheKey: cacheKey, in: context, fetchedAt: fetchedAt)
        case let summary as TaskDailySummary:
            try storeTaskDailySummary(summary, cacheKey: cacheKey, in: context, fetchedAt: fetchedAt)
        case let summary as NutritionDailySummary:
            try storeNutritionDailySummary(summary, cacheKey: cacheKey, in: context, fetchedAt: fetchedAt)
        default:
            // Unknown type - this shouldn't happen with our known types
            throw CacheError.unsupportedType(String(describing: T.self))
        }
    }

    // MARK: - Type-Specific Store Implementations

    private func storeTypeQuickerStats(_ record: TypeQuickerStats, cacheKey: String, in context: ModelContext, fetchedAt: Date) throws {
        let descriptor = FetchDescriptor<TypeQuickerStatsModel>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        if let existing = try context.fetch(descriptor).first {
            if fetchedAt > existing.fetchedAt {
                existing.update(from: record, fetchedAt: fetchedAt)
            }
        } else {
            let model = TypeQuickerStatsModel.from(record, fetchedAt: fetchedAt)
            context.insert(model)
        }
    }

    private func storeAtCoderContestResult(_ record: AtCoderContestResult, cacheKey: String, in context: ModelContext, fetchedAt: Date) throws {
        let descriptor = FetchDescriptor<AtCoderContestResultModel>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        if let existing = try context.fetch(descriptor).first {
            if fetchedAt > existing.fetchedAt {
                existing.update(from: record, fetchedAt: fetchedAt)
            }
        } else {
            let model = AtCoderContestResultModel.from(record, fetchedAt: fetchedAt)
            context.insert(model)
        }
    }

    private func storeAtCoderSubmission(_ record: AtCoderSubmission, cacheKey: String, in context: ModelContext, fetchedAt: Date) throws {
        let descriptor = FetchDescriptor<AtCoderSubmissionModel>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        if let existing = try context.fetch(descriptor).first {
            if fetchedAt > existing.fetchedAt {
                existing.update(from: record, fetchedAt: fetchedAt)
            }
        } else {
            let model = AtCoderSubmissionModel.from(record, fetchedAt: fetchedAt)
            context.insert(model)
        }
    }

    private func storeAtCoderDailyEffort(_ record: AtCoderDailyEffort, cacheKey: String, in context: ModelContext, fetchedAt: Date) throws {
        let descriptor = FetchDescriptor<AtCoderDailyEffortModel>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        if let existing = try context.fetch(descriptor).first {
            if fetchedAt > existing.fetchedAt {
                existing.update(from: record, fetchedAt: fetchedAt)
            }
        } else {
            let model = AtCoderDailyEffortModel.from(record, fetchedAt: fetchedAt)
            context.insert(model)
        }
    }

    private func storeAnkiDailyStats(_ record: AnkiDailyStats, cacheKey: String, in context: ModelContext, fetchedAt: Date) throws {
        let descriptor = FetchDescriptor<AnkiDailyStatsModel>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        if let existing = try context.fetch(descriptor).first {
            if fetchedAt > existing.fetchedAt {
                existing.update(from: record, fetchedAt: fetchedAt)
            }
        } else {
            let model = AnkiDailyStatsModel.from(record, fetchedAt: fetchedAt)
            context.insert(model)
        }
    }

    private func storeZoteroDailyStats(_ record: ZoteroDailyStats, cacheKey: String, in context: ModelContext, fetchedAt: Date) throws {
        let descriptor = FetchDescriptor<ZoteroDailyStatsModel>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        if let existing = try context.fetch(descriptor).first {
            if fetchedAt > existing.fetchedAt {
                existing.update(from: record, fetchedAt: fetchedAt)
            }
        } else {
            let model = ZoteroDailyStatsModel.from(record, fetchedAt: fetchedAt)
            context.insert(model)
        }
    }

    private func storeZoteroReadingStatus(_ record: ZoteroReadingStatus, cacheKey: String, in context: ModelContext, fetchedAt: Date) throws {
        let descriptor = FetchDescriptor<ZoteroReadingStatusModel>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        if let existing = try context.fetch(descriptor).first {
            if fetchedAt > existing.fetchedAt {
                existing.update(from: record, fetchedAt: fetchedAt)
            }
        } else {
            let model = ZoteroReadingStatusModel.from(record, fetchedAt: fetchedAt)
            context.insert(model)
        }
    }

    private func storeSleepDailySummary(_ record: SleepDailySummary, cacheKey: String, in context: ModelContext, fetchedAt: Date) throws {
        let descriptor = FetchDescriptor<SleepDailySummaryModel>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        if let existing = try context.fetch(descriptor).first {
            if fetchedAt > existing.fetchedAt {
                existing.update(from: record, fetchedAt: fetchedAt)
            }
        } else {
            let model = SleepDailySummaryModel.from(record, fetchedAt: fetchedAt)
            context.insert(model)
        }
    }

    private func storeTaskDailySummary(_ record: TaskDailySummary, cacheKey: String, in context: ModelContext, fetchedAt: Date) throws {
        let descriptor = FetchDescriptor<TaskDailySummaryModel>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        if let existing = try context.fetch(descriptor).first {
            if fetchedAt > existing.fetchedAt {
                existing.update(from: record, fetchedAt: fetchedAt)
            }
        } else {
            let model = TaskDailySummaryModel.from(record, fetchedAt: fetchedAt)
            context.insert(model)
        }
    }

    private func storeNutritionDailySummary(_ record: NutritionDailySummary, cacheKey: String, in context: ModelContext, fetchedAt: Date) throws {
        let descriptor = FetchDescriptor<NutritionDailySummaryModel>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        if let existing = try context.fetch(descriptor).first {
            if fetchedAt > existing.fetchedAt {
                existing.update(from: record, fetchedAt: fetchedAt)
            }
        } else {
            let model = NutritionDailySummaryModel.from(record, fetchedAt: fetchedAt)
            context.insert(model)
        }
    }

    // MARK: - Fetch Operations

    /// Fetches cached records within an optional date range
    /// - Parameters:
    ///   - type: The type of record to fetch
    ///   - from: Optional start date (inclusive)
    ///   - to: Optional end date (inclusive)
    /// - Returns: Array of decoded records sorted by recordDate
    public func fetch<T: CacheableRecord>(
        _ type: T.Type,
        from startDate: Date? = nil,
        to endDate: Date? = nil
    ) async throws -> [T] {
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
            throw CacheError.unsupportedType(String(describing: T.self))
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

    /// Fetches a single record by its cache key
    public func fetch<T: CacheableRecord>(
        _ type: T.Type,
        cacheKey: String
    ) async throws -> T? {
        let context = ModelContext(modelContainer)

        // Route to type-specific fetch implementation
        switch type {
        case is TypeQuickerStats.Type:
            return try fetchTypeQuickerStatsByCacheKey(cacheKey, context: context) as? T
        case is AtCoderContestResult.Type:
            return try fetchAtCoderContestResultByCacheKey(cacheKey, context: context) as? T
        case is AtCoderSubmission.Type:
            return try fetchAtCoderSubmissionByCacheKey(cacheKey, context: context) as? T
        case is AtCoderDailyEffort.Type:
            return try fetchAtCoderDailyEffortByCacheKey(cacheKey, context: context) as? T
        case is AnkiDailyStats.Type:
            return try fetchAnkiDailyStatsByCacheKey(cacheKey, context: context) as? T
        case is ZoteroDailyStats.Type:
            return try fetchZoteroDailyStatsByCacheKey(cacheKey, context: context) as? T
        case is ZoteroReadingStatus.Type:
            return try fetchZoteroReadingStatusByCacheKey(cacheKey, context: context) as? T
        case is SleepDailySummary.Type:
            return try fetchSleepDailySummaryByCacheKey(cacheKey, context: context) as? T
        case is TaskDailySummary.Type:
            return try fetchTaskDailySummaryByCacheKey(cacheKey, context: context) as? T
        case is NutritionDailySummary.Type:
            return try fetchNutritionDailySummaryByCacheKey(cacheKey, context: context) as? T
        default:
            throw CacheError.unsupportedType(String(describing: T.self))
        }
    }

    // MARK: - Type-Specific Fetch by Cache Key

    private func fetchTypeQuickerStatsByCacheKey(_ cacheKey: String, context: ModelContext) throws -> TypeQuickerStats? {
        let descriptor = FetchDescriptor<TypeQuickerStatsModel>(predicate: #Predicate { $0.cacheKey == cacheKey })
        return try context.fetch(descriptor).first?.toDomain()
    }

    private func fetchAtCoderContestResultByCacheKey(_ cacheKey: String, context: ModelContext) throws -> AtCoderContestResult? {
        let descriptor = FetchDescriptor<AtCoderContestResultModel>(predicate: #Predicate { $0.cacheKey == cacheKey })
        return try context.fetch(descriptor).first?.toDomain()
    }

    private func fetchAtCoderSubmissionByCacheKey(_ cacheKey: String, context: ModelContext) throws -> AtCoderSubmission? {
        let descriptor = FetchDescriptor<AtCoderSubmissionModel>(predicate: #Predicate { $0.cacheKey == cacheKey })
        return try context.fetch(descriptor).first?.toDomain()
    }

    private func fetchAtCoderDailyEffortByCacheKey(_ cacheKey: String, context: ModelContext) throws -> AtCoderDailyEffort? {
        let descriptor = FetchDescriptor<AtCoderDailyEffortModel>(predicate: #Predicate { $0.cacheKey == cacheKey })
        return try context.fetch(descriptor).first?.toDomain()
    }

    private func fetchAnkiDailyStatsByCacheKey(_ cacheKey: String, context: ModelContext) throws -> AnkiDailyStats? {
        let descriptor = FetchDescriptor<AnkiDailyStatsModel>(predicate: #Predicate { $0.cacheKey == cacheKey })
        return try context.fetch(descriptor).first?.toDomain()
    }

    private func fetchZoteroDailyStatsByCacheKey(_ cacheKey: String, context: ModelContext) throws -> ZoteroDailyStats? {
        let descriptor = FetchDescriptor<ZoteroDailyStatsModel>(predicate: #Predicate { $0.cacheKey == cacheKey })
        return try context.fetch(descriptor).first?.toDomain()
    }

    private func fetchZoteroReadingStatusByCacheKey(_ cacheKey: String, context: ModelContext) throws -> ZoteroReadingStatus? {
        let descriptor = FetchDescriptor<ZoteroReadingStatusModel>(predicate: #Predicate { $0.cacheKey == cacheKey })
        return try context.fetch(descriptor).first?.toDomain()
    }

    private func fetchSleepDailySummaryByCacheKey(_ cacheKey: String, context: ModelContext) throws -> SleepDailySummary? {
        let descriptor = FetchDescriptor<SleepDailySummaryModel>(predicate: #Predicate { $0.cacheKey == cacheKey })
        return try context.fetch(descriptor).first?.toDomain()
    }

    private func fetchTaskDailySummaryByCacheKey(_ cacheKey: String, context: ModelContext) throws -> TaskDailySummary? {
        let descriptor = FetchDescriptor<TaskDailySummaryModel>(predicate: #Predicate { $0.cacheKey == cacheKey })
        return try context.fetch(descriptor).first?.toDomain()
    }

    private func fetchNutritionDailySummaryByCacheKey(_ cacheKey: String, context: ModelContext) throws -> NutritionDailySummary? {
        let descriptor = FetchDescriptor<NutritionDailySummaryModel>(predicate: #Predicate { $0.cacheKey == cacheKey })
        return try context.fetch(descriptor).first?.toDomain()
    }

    // MARK: - Query Operations

    /// Returns the most recent record date for a given type
    /// Useful for determining what data to fetch incrementally
    public func latestRecordDate<T: CacheableRecord>(for type: T.Type) async throws -> Date? {
        let context = ModelContext(modelContainer)

        switch type {
        case is TypeQuickerStats.Type:
            var descriptor = FetchDescriptor<TypeQuickerStatsModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .reverse)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        case is AtCoderContestResult.Type:
            var descriptor = FetchDescriptor<AtCoderContestResultModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .reverse)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        case is AtCoderSubmission.Type:
            var descriptor = FetchDescriptor<AtCoderSubmissionModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .reverse)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        case is AtCoderDailyEffort.Type:
            var descriptor = FetchDescriptor<AtCoderDailyEffortModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .reverse)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        case is AnkiDailyStats.Type:
            var descriptor = FetchDescriptor<AnkiDailyStatsModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .reverse)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        case is ZoteroDailyStats.Type:
            var descriptor = FetchDescriptor<ZoteroDailyStatsModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .reverse)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        case is ZoteroReadingStatus.Type:
            var descriptor = FetchDescriptor<ZoteroReadingStatusModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .reverse)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        case is SleepDailySummary.Type:
            var descriptor = FetchDescriptor<SleepDailySummaryModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .reverse)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        case is TaskDailySummary.Type:
            var descriptor = FetchDescriptor<TaskDailySummaryModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .reverse)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        case is NutritionDailySummary.Type:
            var descriptor = FetchDescriptor<NutritionDailySummaryModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .reverse)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        default:
            throw CacheError.unsupportedType(String(describing: T.self))
        }
    }

    /// Returns the earliest record date for a given type
    public func earliestRecordDate<T: CacheableRecord>(for type: T.Type) async throws -> Date? {
        let context = ModelContext(modelContainer)

        switch type {
        case is TypeQuickerStats.Type:
            var descriptor = FetchDescriptor<TypeQuickerStatsModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .forward)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        case is AtCoderContestResult.Type:
            var descriptor = FetchDescriptor<AtCoderContestResultModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .forward)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        case is AtCoderSubmission.Type:
            var descriptor = FetchDescriptor<AtCoderSubmissionModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .forward)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        case is AtCoderDailyEffort.Type:
            var descriptor = FetchDescriptor<AtCoderDailyEffortModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .forward)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        case is AnkiDailyStats.Type:
            var descriptor = FetchDescriptor<AnkiDailyStatsModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .forward)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        case is ZoteroDailyStats.Type:
            var descriptor = FetchDescriptor<ZoteroDailyStatsModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .forward)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        case is ZoteroReadingStatus.Type:
            var descriptor = FetchDescriptor<ZoteroReadingStatusModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .forward)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        case is SleepDailySummary.Type:
            var descriptor = FetchDescriptor<SleepDailySummaryModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .forward)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        case is TaskDailySummary.Type:
            var descriptor = FetchDescriptor<TaskDailySummaryModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .forward)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        case is NutritionDailySummary.Type:
            var descriptor = FetchDescriptor<NutritionDailySummaryModel>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .forward)]
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.recordDate
        default:
            throw CacheError.unsupportedType(String(describing: T.self))
        }
    }

    /// Checks if any cached data exists for a given record type
    public func hasCachedData<T: CacheableRecord>(for type: T.Type) async throws -> Bool {
        let context = ModelContext(modelContainer)

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
            throw CacheError.unsupportedType(String(describing: T.self))
        }
    }

    /// Returns the count of cached records for a given type
    public func count<T: CacheableRecord>(for type: T.Type) async throws -> Int {
        let context = ModelContext(modelContainer)

        switch type {
        case is TypeQuickerStats.Type:
            return try context.fetchCount(FetchDescriptor<TypeQuickerStatsModel>())
        case is AtCoderContestResult.Type:
            return try context.fetchCount(FetchDescriptor<AtCoderContestResultModel>())
        case is AtCoderSubmission.Type:
            return try context.fetchCount(FetchDescriptor<AtCoderSubmissionModel>())
        case is AtCoderDailyEffort.Type:
            return try context.fetchCount(FetchDescriptor<AtCoderDailyEffortModel>())
        case is AnkiDailyStats.Type:
            return try context.fetchCount(FetchDescriptor<AnkiDailyStatsModel>())
        case is ZoteroDailyStats.Type:
            return try context.fetchCount(FetchDescriptor<ZoteroDailyStatsModel>())
        case is ZoteroReadingStatus.Type:
            return try context.fetchCount(FetchDescriptor<ZoteroReadingStatusModel>())
        case is SleepDailySummary.Type:
            return try context.fetchCount(FetchDescriptor<SleepDailySummaryModel>())
        case is TaskDailySummary.Type:
            return try context.fetchCount(FetchDescriptor<TaskDailySummaryModel>())
        case is NutritionDailySummary.Type:
            return try context.fetchCount(FetchDescriptor<NutritionDailySummaryModel>())
        default:
            throw CacheError.unsupportedType(String(describing: T.self))
        }
    }

    // MARK: - Delete Operations

    /// Deletes all cached records for a given type
    public func deleteAll<T: CacheableRecord>(for type: T.Type) async throws {
        let context = ModelContext(modelContainer)

        switch type {
        case is TypeQuickerStats.Type:
            try deleteAllModels(of: TypeQuickerStatsModel.self, from: context)
        case is AtCoderContestResult.Type:
            try deleteAllModels(of: AtCoderContestResultModel.self, from: context)
        case is AtCoderSubmission.Type:
            try deleteAllModels(of: AtCoderSubmissionModel.self, from: context)
        case is AtCoderDailyEffort.Type:
            try deleteAllModels(of: AtCoderDailyEffortModel.self, from: context)
        case is AnkiDailyStats.Type:
            try deleteAllModels(of: AnkiDailyStatsModel.self, from: context)
        case is ZoteroDailyStats.Type:
            try deleteAllModels(of: ZoteroDailyStatsModel.self, from: context)
        case is ZoteroReadingStatus.Type:
            try deleteAllModels(of: ZoteroReadingStatusModel.self, from: context)
        case is SleepDailySummary.Type:
            try deleteAllModels(of: SleepDailySummaryModel.self, from: context)
        case is TaskDailySummary.Type:
            try deleteAllModels(of: TaskDailySummaryModel.self, from: context)
        case is NutritionDailySummary.Type:
            try deleteAllModels(of: NutritionDailySummaryModel.self, from: context)
        default:
            throw CacheError.unsupportedType(String(describing: T.self))
        }

        try context.save()
    }

    /// Deletes cached records older than a specified date
    public func deleteOlderThan<T: CacheableRecord>(
        _ date: Date,
        for type: T.Type
    ) async throws {
        let context = ModelContext(modelContainer)

        switch type {
        case is TypeQuickerStats.Type:
            try deleteModelsOlderThan(date, of: TypeQuickerStatsModel.self, from: context)
        case is AtCoderContestResult.Type:
            try deleteModelsOlderThan(date, of: AtCoderContestResultModel.self, from: context)
        case is AtCoderSubmission.Type:
            try deleteModelsOlderThan(date, of: AtCoderSubmissionModel.self, from: context)
        case is AtCoderDailyEffort.Type:
            try deleteModelsOlderThan(date, of: AtCoderDailyEffortModel.self, from: context)
        case is AnkiDailyStats.Type:
            try deleteModelsOlderThan(date, of: AnkiDailyStatsModel.self, from: context)
        case is ZoteroDailyStats.Type:
            try deleteModelsOlderThan(date, of: ZoteroDailyStatsModel.self, from: context)
        case is ZoteroReadingStatus.Type:
            try deleteModelsOlderThan(date, of: ZoteroReadingStatusModel.self, from: context)
        case is SleepDailySummary.Type:
            try deleteModelsOlderThan(date, of: SleepDailySummaryModel.self, from: context)
        case is TaskDailySummary.Type:
            try deleteModelsOlderThan(date, of: TaskDailySummaryModel.self, from: context)
        case is NutritionDailySummary.Type:
            try deleteModelsOlderThan(date, of: NutritionDailySummaryModel.self, from: context)
        default:
            throw CacheError.unsupportedType(String(describing: T.self))
        }

        try context.save()
    }

    // MARK: - Private Helpers

    private func deleteAllModels<M: PersistentModel>(of modelType: M.Type, from context: ModelContext) throws {
        let descriptor = FetchDescriptor<M>()
        let entries = try context.fetch(descriptor)
        for entry in entries {
            context.delete(entry)
        }
    }

    private func deleteModelsOlderThan<M: PersistentModel>(_ date: Date, of modelType: M.Type, from context: ModelContext) throws {
        // Since we can't use generic predicates with PersistentModel directly,
        // we need to handle this per-type in the caller. This is a fallback that fetches all and filters.
        let descriptor = FetchDescriptor<M>()
        let entries = try context.fetch(descriptor)

        for entry in entries {
            // Use reflection to check recordDate
            let mirror = Mirror(reflecting: entry)
            if let recordDateChild = mirror.children.first(where: { $0.label == "recordDate" }),
               let recordDate = recordDateChild.value as? Date,
               recordDate < date {
                context.delete(entry)
            }
        }
    }

}

// MARK: - Cache Errors

public enum CacheError: Error {
    case unsupportedType(String)
}
