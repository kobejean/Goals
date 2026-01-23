import AppIntents
import SwiftData
import WidgetKit
import GoalsDomain
import GoalsData
import GoalsWidgetShared

/// App Intent for toggling a task from the widget
struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Task"
    static var description = IntentDescription("Start or stop a task")

    /// Prevent the app from opening when the intent runs
    static var openAppWhenRun: Bool = false

    /// Don't show in Shortcuts or Spotlight
    static var isDiscoverable: Bool = false

    @Parameter(title: "Task ID")
    var taskId: String

    init() {
        self.taskId = ""
    }

    init(taskId: String) {
        self.taskId = taskId
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let taskUUID = UUID(uuidString: taskId) else {
            return .result()
        }

        // Create ModelContainer with same schema as main app
        // Must use the same shared store URL as AppContainer
        // IMPORTANT: Must include ALL models to match app's schema
        let schema = Schema([
            GoalModel.self,
            EarnedBadgeModel.self,
            TaskDefinitionModel.self,
            TaskSessionModel.self,
        ])

        guard let storeURL = SharedStorage.sharedMainStoreURL else {
            return .result()
        }

        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )

        let modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = modelContainer.mainContext

        // Find the task
        let taskDescriptor = FetchDescriptor<TaskDefinitionModel>(
            predicate: #Predicate { $0.id == taskUUID }
        )
        guard let task = try modelContext.fetch(taskDescriptor).first else {
            return .result()
        }

        // Check for active session
        let activeDescriptor = FetchDescriptor<TaskSessionModel>(
            predicate: #Predicate { $0.endDate == nil }
        )
        let activeSessions = try modelContext.fetch(activeDescriptor)

        let now = Date()

        // Check if tapped task is currently active
        if let activeSession = activeSessions.first, activeSession.taskId == taskUUID {
            // Stop the active task
            activeSession.endDate = now
        } else {
            // Stop any active sessions
            for session in activeSessions {
                session.endDate = now
            }

            // Start new session for tapped task
            let newSession = TaskSessionModel(
                id: UUID(),
                taskId: taskUUID,
                startDate: now
            )
            newSession.task = task
            modelContext.insert(newSession)
        }

        try modelContext.save()

        // Sync widget cache
        await syncWidgetCache(modelContext: modelContext)

        // Reload widget timelines
        WidgetCenter.shared.reloadTimelines(ofKind: "TaskControlPanelWidget")

        return .result()
    }

    @MainActor
    private func syncWidgetCache(modelContext: ModelContext) async {
        // Fetch active tasks
        let taskDescriptor = FetchDescriptor<TaskDefinitionModel>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        let tasks = (try? modelContext.fetch(taskDescriptor)) ?? []

        // Fetch active session
        let sessionDescriptor = FetchDescriptor<TaskSessionModel>(
            predicate: #Predicate { $0.endDate == nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let activeSessions = (try? modelContext.fetch(sessionDescriptor)) ?? []
        let activeSession = activeSessions.first

        // Convert to cached models
        let cachedTasks = tasks.map { task in
            CachedTaskInfo(
                id: task.id,
                name: task.name,
                colorRaw: task.colorRawValue,
                icon: task.icon,
                sortOrder: task.sortOrder
            )
        }

        // Build cached active session if exists
        var cachedActiveSession: CachedActiveSession?
        if let session = activeSession,
           let task = tasks.first(where: { $0.id == session.taskId }) {
            cachedActiveSession = CachedActiveSession(
                sessionId: session.id,
                taskId: session.taskId,
                taskName: task.name,
                taskColorRaw: task.colorRawValue,
                startDate: session.startDate
            )
        }

        // Write to shared storage
        WidgetCacheWriter.write(tasks: cachedTasks, activeSession: cachedActiveSession)
    }
}
