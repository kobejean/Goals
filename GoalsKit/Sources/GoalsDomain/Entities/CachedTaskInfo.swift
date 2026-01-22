import Foundation

/// Lightweight Codable task model for widget storage
public struct CachedTaskInfo: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let colorRaw: String
    public let icon: String
    public let sortOrder: Int

    public init(
        id: UUID,
        name: String,
        colorRaw: String,
        icon: String,
        sortOrder: Int
    ) {
        self.id = id
        self.name = name
        self.colorRaw = colorRaw
        self.icon = icon
        self.sortOrder = sortOrder
    }

    /// Create from domain TaskDefinition
    public init(from task: TaskDefinition) {
        self.id = task.id
        self.name = task.name
        self.colorRaw = task.color.rawValue
        self.icon = task.icon
        self.sortOrder = task.sortOrder
    }

    /// Get the TaskColor enum value
    public var taskColor: TaskColor {
        TaskColor(rawValue: colorRaw) ?? .blue
    }
}
