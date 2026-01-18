import Foundation

/// Use case for syncing data from external data sources
public struct SyncDataSourcesUseCase: Sendable {
    private let goalRepository: GoalRepositoryProtocol
    private let dataPointRepository: DataPointRepositoryProtocol
    private let dataSources: [DataSourceType: any DataSourceRepositoryProtocol]

    public init(
        goalRepository: GoalRepositoryProtocol,
        dataPointRepository: DataPointRepositoryProtocol,
        dataSources: [DataSourceType: any DataSourceRepositoryProtocol]
    ) {
        self.goalRepository = goalRepository
        self.dataPointRepository = dataPointRepository
        self.dataSources = dataSources
    }

    /// Syncs data from all configured data sources
    public func syncAll() async throws -> SyncResult {
        var results: [DataSourceType: SyncSourceResult] = [:]

        for (sourceType, repository) in dataSources {
            guard await repository.isConfigured() else {
                results[sourceType] = SyncSourceResult(
                    dataSource: sourceType,
                    success: false,
                    dataPointsCreated: 0,
                    error: SyncError.notConfigured
                )
                continue
            }

            do {
                let result = try await syncDataSource(sourceType, repository: repository)
                results[sourceType] = result
            } catch {
                results[sourceType] = SyncSourceResult(
                    dataSource: sourceType,
                    success: false,
                    dataPointsCreated: 0,
                    error: error
                )
            }
        }

        return SyncResult(
            timestamp: Date(),
            sourceResults: results
        )
    }

    /// Syncs data from a specific data source
    public func sync(dataSource: DataSourceType) async throws -> SyncSourceResult {
        guard let repository = dataSources[dataSource] else {
            throw SyncError.dataSourceNotFound
        }

        guard await repository.isConfigured() else {
            throw SyncError.notConfigured
        }

        return try await syncDataSource(dataSource, repository: repository)
    }

    private func syncDataSource(
        _ sourceType: DataSourceType,
        repository: any DataSourceRepositoryProtocol
    ) async throws -> SyncSourceResult {
        // Get goals that use this data source
        let goals = try await goalRepository.fetch(dataSource: sourceType)

        guard !goals.isEmpty else {
            return SyncSourceResult(
                dataSource: sourceType,
                success: true,
                dataPointsCreated: 0,
                error: nil
            )
        }

        // Fetch data from the source (last 30 days by default)
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate

        let dataPoints = try await repository.fetchData(from: startDate, to: endDate)

        // Get the latest stats for metric-based goal updates
        let latestStats = try await repository.fetchLatest()

        // Create data points for each goal
        var createdCount = 0
        for goal in goals {
            let goalDataPoints = dataPoints.map { point in
                DataPoint(
                    goalId: goal.id,
                    value: point.value,
                    timestamp: point.timestamp,
                    source: sourceType,
                    note: point.note,
                    metadata: point.metadata
                )
            }

            let created = try await dataPointRepository.createBatch(goalDataPoints)
            createdCount += created.count

            // Update goal progress based on metric key or latest data
            if let metricKey = goal.metricKey, let latestStats {
                // For metric-based goals, extract the specific metric value
                let value = extractMetricValue(
                    from: latestStats,
                    for: metricKey,
                    sourceType: sourceType
                )
                if let value {
                    try await goalRepository.updateProgress(
                        goalId: goal.id,
                        currentValue: value
                    )
                }
            } else if let latest = created.last {
                // For non-metric goals, use the latest data point value
                try await goalRepository.updateProgress(
                    goalId: goal.id,
                    currentValue: latest.value
                )
            }
        }

        return SyncSourceResult(
            dataSource: sourceType,
            success: true,
            dataPointsCreated: createdCount,
            error: nil
        )
    }

    /// Extract a metric value from a data point
    private func extractMetricValue(
        from dataPoint: DataPoint,
        for metricKey: String,
        sourceType: DataSourceType
    ) -> Double? {
        let metadata = dataPoint.metadata ?? [:]

        switch sourceType {
        case .typeQuicker:
            switch metricKey {
            case "wpm":
                return dataPoint.value // WPM is the main value
            case "accuracy":
                return metadata["accuracy"].flatMap { Double($0) }
            case "practiceTime":
                return metadata["practiceMinutes"].flatMap { Double($0) }
            default:
                return nil
            }
        case .atCoder:
            switch metricKey {
            case "rating":
                return dataPoint.value // Rating is the main value
            case "highestRating":
                return metadata["highestRating"].flatMap { Double($0) }
            case "contestsParticipated":
                return metadata["contests"].flatMap { Double($0) }
            case "problemsSolved":
                return metadata["problemsSolved"].flatMap { Double($0) }
            case "longestStreak":
                return metadata["longestStreak"].flatMap { Double($0) }
            default:
                return nil
            }
        default:
            return nil
        }
    }
}

/// Errors that can occur during sync
public enum SyncError: Error, Sendable {
    case dataSourceNotFound
    case notConfigured
    case networkError(String)
    case parseError(String)
}

/// Result of syncing all data sources
public struct SyncResult: Sendable {
    public let timestamp: Date
    public let sourceResults: [DataSourceType: SyncSourceResult]

    public init(timestamp: Date, sourceResults: [DataSourceType: SyncSourceResult]) {
        self.timestamp = timestamp
        self.sourceResults = sourceResults
    }

    /// Returns true if all sources synced successfully
    public var allSuccessful: Bool {
        sourceResults.values.allSatisfy { $0.success }
    }

    /// Total number of data points created across all sources
    public var totalDataPointsCreated: Int {
        sourceResults.values.reduce(0) { $0 + $1.dataPointsCreated }
    }
}

/// Result of syncing a single data source
public struct SyncSourceResult: Sendable {
    public let dataSource: DataSourceType
    public let success: Bool
    public let dataPointsCreated: Int
    public let error: Error?

    public init(
        dataSource: DataSourceType,
        success: Bool,
        dataPointsCreated: Int,
        error: Error?
    ) {
        self.dataSource = dataSource
        self.success = success
        self.dataPointsCreated = dataPointsCreated
        self.error = error
    }
}
