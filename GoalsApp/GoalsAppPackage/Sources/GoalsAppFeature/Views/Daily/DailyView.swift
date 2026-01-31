import SwiftUI
import GoalsDomain

/// Sections available in the Daily tab
public enum DailySection: String, CaseIterable, Identifiable {
    case tasks
    case locations
    case nutrition

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .tasks:
            return "Tasks"
        case .locations:
            return "Locations"
        case .nutrition:
            return "Nutrition"
        }
    }

    public var systemImage: String {
        switch self {
        case .tasks:
            return "timer"
        case .locations:
            return "location.fill"
        case .nutrition:
            return "fork.knife"
        }
    }
}

/// Main view for the Daily tab with segmented control for Tasks and Nutrition
public struct DailyView: View {
    @Environment(AppContainer.self) private var container
    @State private var selectedSection: DailySection = .tasks

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented picker
                Picker("Section", selection: $selectedSection) {
                    ForEach(DailySection.allCases) { section in
                        Label(section.title, systemImage: section.systemImage)
                            .tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                // Content
                switch selectedSection {
                case .tasks:
                    TasksSectionView()
                case .locations:
                    LocationsSectionView()
                case .nutrition:
                    NutritionSectionView()
                }
            }
            .navigationTitle("Daily")
        }
    }

    public init() {}
}

#Preview {
    DailyView()
        .environment(try! AppContainer.preview())
}
