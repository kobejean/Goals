import Foundation
import GoalsCore

/// Represents a user-created task template for time tracking
public struct TaskDefinition: Sendable, Equatable, UUIDIdentifiable, Codable {
    public let id: UUID
    public var name: String
    public var color: TaskColor
    public var icon: String
    public var isArchived: Bool
    public let createdAt: Date
    public var updatedAt: Date
    public var sortOrder: Int

    public init(
        id: UUID = UUID(),
        name: String,
        color: TaskColor = .blue,
        icon: String = "checkmark.circle",
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
    }
}

/// Available colors for tasks (matches GoalColor for consistency)
public enum TaskColor: String, Codable, Sendable, CaseIterable {
    case blue
    case green
    case orange
    case purple
    case red
    case pink
    case yellow
    case teal

    public var displayName: String {
        rawValue.capitalized
    }
}
