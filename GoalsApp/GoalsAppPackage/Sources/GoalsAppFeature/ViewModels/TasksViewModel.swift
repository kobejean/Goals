import SwiftUI
import GoalsDomain

/// ViewModel for the Tasks tab, managing task tracking state
@MainActor
@Observable
public final class TasksViewModel: Sendable {
    // MARK: - Published State

    /// All active (non-archived) task definitions
    public private(set) var tasks: [TaskDefinition] = []

    /// Currently active session, if any
    public private(set) var activeSession: TaskSession?

    /// Today's sessions by task ID
    public private(set) var todaySessionsByTask: [UUID: [TaskSession]] = [:]

    /// Loading state
    public private(set) var isLoading = false

    /// Error message, if any
    public private(set) var errorMessage: String?

    /// Timer tick for live duration updates
    public private(set) var timerTick: Date = Date()

    // MARK: - Dependencies

    private let taskRepository: TaskRepositoryProtocol

    // MARK: - Timer

    private var timerTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(taskRepository: TaskRepositoryProtocol) {
        self.taskRepository = taskRepository
    }

    // MARK: - Public Methods

    /// Load all data (tasks, active session, today's sessions)
    public func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load tasks and sessions in parallel
            async let tasksResult = taskRepository.fetchActiveTasks()
            async let activeResult = taskRepository.fetchActiveSession()
            async let todayResult = fetchTodaySessions()

            tasks = try await tasksResult
            activeSession = try await activeResult
            todaySessionsByTask = try await todayResult

            // Start timer if there's an active session
            if activeSession != nil {
                startTimer()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Toggle a task - start if inactive, stop if active
    public func toggleTask(_ task: TaskDefinition) async {
        do {
            if let active = activeSession, active.taskId == task.id {
                // Stop the current task
                activeSession = try await taskRepository.stopSession(id: active.id)
                activeSession = nil
                stopTimer()
            } else {
                // Start this task (will auto-stop any other active task)
                activeSession = try await taskRepository.startSession(taskId: task.id)
                startTimer()
            }

            // Refresh today's sessions
            todaySessionsByTask = try await fetchTodaySessions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Create a new task
    public func createTask(_ task: TaskDefinition) async {
        do {
            let created = try await taskRepository.createTask(task)
            tasks.append(created)
            tasks.sort { $0.sortOrder < $1.sortOrder }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Update an existing task
    public func updateTask(_ task: TaskDefinition) async {
        do {
            let updated = try await taskRepository.updateTask(task)
            if let index = tasks.firstIndex(where: { $0.id == updated.id }) {
                tasks[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Delete a task
    public func deleteTask(_ task: TaskDefinition) async {
        do {
            try await taskRepository.deleteTask(id: task.id)
            tasks.removeAll { $0.id == task.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Get today's total duration for a specific task
    public func todayDuration(for taskId: UUID) -> TimeInterval {
        let sessions = todaySessionsByTask[taskId] ?? []
        return sessions.totalDuration
    }

    /// Format a duration for display
    public func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Get the currently active task definition, if any
    public var activeTask: TaskDefinition? {
        guard let session = activeSession else { return nil }
        return tasks.first { $0.id == session.taskId }
    }

    // MARK: - Private Methods

    private func fetchTodaySessions() async throws -> [UUID: [TaskSession]] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()

        let sessions = try await taskRepository.fetchSessions(from: startOfDay, to: endOfDay)

        var grouped: [UUID: [TaskSession]] = [:]
        for session in sessions {
            grouped[session.taskId, default: []].append(session)
        }
        return grouped
    }

    private func startTimer() {
        stopTimer()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self?.timerTick = Date()
                }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}
