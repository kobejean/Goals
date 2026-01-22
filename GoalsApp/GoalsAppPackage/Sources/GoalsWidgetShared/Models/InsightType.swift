import SwiftUI
import AppIntents
import UniformTypeIdentifiers

/// Identifies each type of insight card for ordering/persistence
public enum InsightType: String, CaseIterable, Codable, Sendable {
    case typeQuicker
    case atCoder
    case sleep
    case tasks
    case anki

    /// Default order for insight cards
    public static let defaultOrder: [InsightType] = [.typeQuicker, .atCoder, .sleep, .tasks, .anki]

    /// Display title for the insight type
    public var displayTitle: String {
        switch self {
        case .typeQuicker: return "Typing"
        case .atCoder: return "AtCoder"
        case .sleep: return "Sleep"
        case .tasks: return "Tasks"
        case .anki: return "Anki"
        }
    }

    /// System image for the insight type (matches app ViewModels)
    public var systemImage: String {
        switch self {
        case .typeQuicker: return "keyboard"
        case .atCoder: return "chevron.left.forwardslash.chevron.right"
        case .sleep: return "bed.double.fill"
        case .tasks: return "timer"
        case .anki: return "rectangle.stack"
        }
    }

    /// Color for the insight type (matches app ViewModels)
    /// Note: Uses explicit color instead of .accentColor for widget compatibility
    public var color: Color {
        switch self {
        case .typeQuicker: return Self.brandGreen
        case .atCoder: return Self.brandGreen
        case .sleep: return .indigo
        case .tasks: return .orange
        case .anki: return .purple
        }
    }

    /// Brand green color - matches AccentColor in asset catalog
    /// SwiftUI .accentColor doesn't resolve correctly in widgets, so we define it explicitly
    public static let brandGreen = Color(red: 0.4745, green: 0.7020, blue: 0.2078)
}

// MARK: - Transferable for Drag & Drop

extension InsightType: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .text)
    }
}

// MARK: - AppEnum for Widget Configuration

extension InsightType: AppEnum {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Insight Type")
    }

    public static var caseDisplayRepresentations: [InsightType: DisplayRepresentation] {
        [
            .typeQuicker: DisplayRepresentation(title: "Typing"),
            .atCoder: DisplayRepresentation(title: "AtCoder"),
            .sleep: DisplayRepresentation(title: "Sleep"),
            .tasks: DisplayRepresentation(title: "Tasks"),
            .anki: DisplayRepresentation(title: "Anki")
        ]
    }
}
