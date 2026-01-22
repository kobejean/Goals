import Foundation
import GoalsDomain

/// App Group identifier for sharing data between app and widgets
private let appGroupIdentifier = "group.com.kobejean.goals"

/// Key for cached task definitions in widget storage
private let widgetTasksKey = "widget.tasks"

/// Key for cached active session in widget storage
private let widgetActiveSessionKey = "widget.activeSession"

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

    // MARK: - Widget Cache

    /// Sync task data to UserDefaults for the Task Control Panel widget
    public func syncWidgetCache() async throws {
        // Fetch active tasks
        let tasks = try await taskRepository.fetchActiveTasks()

        // Fetch active session
        let activeSession = try await taskRepository.fetchActiveSession()

        // Convert to cached models
        let cachedTasks = tasks.map { CachedTaskInfo(from: $0) }

        // Build cached active session if exists
        var cachedActiveSession: CachedActiveSession?
        if let session = activeSession,
           let task = tasks.first(where: { $0.id == session.taskId }) {
            cachedActiveSession = CachedActiveSession(
                sessionId: session.id,
                taskId: session.taskId,
                taskName: task.name,
                taskColorRaw: task.color.rawValue,
                startDate: session.startDate
            )
        }

        // Store in shared UserDefaults
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }

        let encoder = JSONEncoder()

        // Store tasks
        if let tasksData = try? encoder.encode(cachedTasks) {
            defaults.set(tasksData, forKey: widgetTasksKey)
        }

        // Store active session (or nil)
        if let session = cachedActiveSession,
           let sessionData = try? encoder.encode(session) {
            defaults.set(sessionData, forKey: widgetActiveSessionKey)
        } else {
            defaults.removeObject(forKey: widgetActiveSessionKey)
        }
    }
}
