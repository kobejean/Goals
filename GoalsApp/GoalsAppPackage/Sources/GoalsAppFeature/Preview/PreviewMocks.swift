import Foundation
import GoalsDomain
import GoalsData

// MARK: - Mock Data Sources for SwiftUI Previews

/// Mock HealthKit sleep data source for previews
actor PreviewHealthKitSleepDataSource: HealthKitSleepDataSourceProtocol {
    nonisolated var dataSourceType: DataSourceType { .healthKitSleep }
    nonisolated var availableMetrics: [MetricInfo] { [] }

    nonisolated func metricValue(for key: String, from stats: Any) -> Double? { nil }

    func isConfigured() async -> Bool { true }
    func configure(settings: DataSourceSettings) async throws {}
    func clearConfiguration() async throws {}
    func fetchLatestMetricValue(for metricKey: String, taskId: UUID?) async throws -> Double? { nil }
    func fetchSleepData(from: Date, to: Date) async throws -> [SleepDailySummary] { [] }
    func fetchLatestSleep() async throws -> SleepDailySummary? { nil }
    func requestAuthorization() async throws -> Bool { true }
    func isAuthorized() async -> Bool { true }
}

/// Mock goal repository for previews
actor PreviewGoalRepository: GoalRepositoryProtocol {
    func fetchAll() async throws -> [Goal] { [] }
    func fetchActive() async throws -> [Goal] { [] }
    func fetchArchived() async throws -> [Goal] { [] }
    func fetch(id: UUID) async throws -> Goal? { nil }
    func fetch(dataSource: DataSourceType) async throws -> [Goal] { [] }
    @discardableResult func create(_ goal: Goal) async throws -> Goal { goal }
    @discardableResult func update(_ goal: Goal) async throws -> Goal { goal }
    func delete(id: UUID) async throws {}
    func archive(id: UUID) async throws {}
    func unarchive(id: UUID) async throws {}
    func updateProgress(goalId: UUID, currentValue: Double) async throws {}
}

/// Mock task repository for previews
actor PreviewTaskRepository: TaskRepositoryProtocol {
    func fetchAllTasks() async throws -> [TaskDefinition] { [] }
    func fetchActiveTasks() async throws -> [TaskDefinition] { [] }
    func fetchTask(id: UUID) async throws -> TaskDefinition? { nil }
    func createTask(_ task: TaskDefinition) async throws -> TaskDefinition { task }
    func updateTask(_ task: TaskDefinition) async throws -> TaskDefinition { task }
    func deleteTask(id: UUID) async throws {}
    func fetchActiveSession() async throws -> TaskSession? { nil }
    func startSession(taskId: UUID) async throws -> TaskSession { TaskSession(taskId: taskId) }
    func stopSession(id: UUID) async throws -> TaskSession { TaskSession(taskId: UUID()) }
    func fetchSessions(from: Date, to: Date) async throws -> [TaskSession] { [] }
    func fetchSessions(taskId: UUID) async throws -> [TaskSession] { [] }
    func deleteSession(id: UUID) async throws {}
    func createSession(_ session: TaskSession) async throws -> TaskSession { session }
}

/// Mock location repository for previews
actor PreviewLocationRepository: LocationRepositoryProtocol {
    func fetchAllLocations() async throws -> [LocationDefinition] { [] }
    func fetchActiveLocations() async throws -> [LocationDefinition] { [] }
    func fetchLocation(id: UUID) async throws -> LocationDefinition? { nil }
    func createLocation(_ location: LocationDefinition) async throws -> LocationDefinition { location }
    func updateLocation(_ location: LocationDefinition) async throws -> LocationDefinition { location }
    func deleteLocation(id: UUID) async throws {}
    func fetchActiveSession() async throws -> LocationSession? { nil }
    func fetchSessions(for date: Date) async throws -> [LocationSession] { [] }
    func fetchSessions(locationId: UUID, from: Date, to: Date) async throws -> [LocationSession] { [] }
    func fetchSessions(from: Date, to: Date) async throws -> [LocationSession] { [] }
    func startSession(locationId: UUID, at: Date) async throws -> LocationSession { LocationSession(locationId: locationId) }
    func endSession(id: UUID, at: Date) async throws -> LocationSession { LocationSession(locationId: UUID()) }
    func confirmSession(id: UUID) async throws -> LocationSession { LocationSession(locationId: UUID()) }
    func deleteSession(id: UUID) async throws {}
    func createSession(_ session: LocationSession) async throws -> LocationSession { session }
    func addEntries(_ entries: [LocationEntry]) async throws {}
    func fetchEntries(sessionId: UUID) async throws -> [LocationEntry] { [] }
    func pruneOldEntries(olderThan: Date) async throws {}
}
