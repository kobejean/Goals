import Foundation

/// Use case for syncing data from external data sources
public struct SyncDataSourcesUseCase: Sendable {
    private let goalRepository: GoalRepositoryProtocol
    private let dataSources: [DataSourceType: any DataSourceRepositoryProtocol]

    public init(
        goalRepository: GoalRepositoryProtocol,
        dataSources: [DataSourceType: any DataSourceRepositoryProtocol]
    ) {
        self.goalRepository = goalRepository
        self.dataSources = dataSources
    }

    /// Syncs data from all configured data sources in parallel
    public func syncAll() async throws -> SyncResult {
        // Run all syncs in parallel for better performance
        await withTaskGroup(of: (DataSourceType, SyncSourceResult).self) { group in
            for (sourceType, repository) in dataSources {
                group.addTask {
                    guard await repository.isConfigured() else {
                        return (sourceType, SyncSourceResult(
                            dataSource: sourceType,
                            success: false,
                            goalsUpdated: 0,
                            error: SyncError.notConfigured
                        ))
                    }

                    do {
                        let result = try await self.syncDataSource(sourceType, repository: repository)
                        return (sourceType, result)
                    } catch {
                        return (sourceType, SyncSourceResult(
                            dataSource: sourceType,
                            success: false,
                            goalsUpdated: 0,
                            error: error
                        ))
                    }
                }
            }

            var results: [DataSourceType: SyncSourceResult] = [:]
            for await (sourceType, result) in group {
                results[sourceType] = result
            }

            return SyncResult(
                timestamp: Date(),
                sourceResults: results
            )
        }
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
                goalsUpdated: 0,
                error: nil
            )
        }

        // Update each goal's current value based on its metric key
        var updatedCount = 0
        for goal in goals {
            if let value = try await repository.fetchLatestMetricValue(for: goal.metricKey) {
                try await goalRepository.updateProgress(goalId: goal.id, currentValue: value)
                updatedCount += 1
            }
        }

        return SyncSourceResult(
            dataSource: sourceType,
            success: true,
            goalsUpdated: updatedCount,
            error: nil
        )
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

    /// Total number of goals updated across all sources
    public var totalGoalsUpdated: Int {
        sourceResults.values.reduce(0) { $0 + $1.goalsUpdated }
    }
}

/// Result of syncing a single data source
public struct SyncSourceResult: Sendable {
    public let dataSource: DataSourceType
    public let success: Bool
    public let goalsUpdated: Int
    public let error: Error?

    public init(
        dataSource: DataSourceType,
        success: Bool,
        goalsUpdated: Int,
        error: Error?
    ) {
        self.dataSource = dataSource
        self.success = success
        self.goalsUpdated = goalsUpdated
        self.error = error
    }
}
