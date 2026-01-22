import Foundation
import GoalsDomain

/// Service to sync task data from SwiftData to shared cache for widget access
public actor TaskCachingService {
    private let taskRepository: TaskRepositoryProtocol
    private let cache: DataCache

    public init(
        taskRepository: TaskRepositoryProtocol,
        cache: DataCache
    ) {
        self.taskRepository = taskRepository
        self.cache = cache
    }

    /// Sync daily summaries for a date range to cache
    /// - Parameters:
    ///   - startDate: Start of date range
    ///   - endDate: End of date range
    public func syncToCache(from startDate: Date, to endDate: Date) async throws {
        // Fetch all tasks and sessions for the date range
        let tasks = try await taskRepository.fetchActiveTasks()
        let sessions = try await taskRepository.fetchSessions(from: startDate, to: endDate)

        // Group sessions by day and build summaries
        let dailySummaries = buildDailySummaries(sessions: sessions, tasks: tasks)

        // Store all summaries in the cache
        try await cache.store(dailySummaries)
    }

    /// Sync today's summary to cache (called after session start/stop)
    public func syncTodayToCache() async throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()

        try await syncToCache(from: today, to: tomorrow)
    }

    /// Build daily summaries from sessions and tasks
    private func buildDailySummaries(
        sessions: [TaskSession],
        tasks: [TaskDefinition]
    ) -> [TaskDailySummary] {
        let calendar = Calendar.current

        // Group sessions by day
        var sessionsByDay: [Date: [TaskSession]] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.startDate)
            sessionsByDay[day, default: []].append(session)
        }

        // Create summaries for each day that has sessions
        return sessionsByDay.map { day, daySessions in
            TaskDailySummary(date: day, sessions: daySessions, tasks: tasks)
        }.sorted { $0.date < $1.date }
    }
}
