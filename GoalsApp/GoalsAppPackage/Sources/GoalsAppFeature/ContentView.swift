import SwiftUI
import SwiftData
import GoalsDomain
import GoalsData

/// Root content view with tab navigation
public struct ContentView: View {
    @State private var selectedTab: AppTab = .insights
    @Environment(AppContainer.self) private var container

    public var body: some View {
        TabView(selection: $selectedTab) {
            InsightsView()
                .tag(AppTab.insights)
                .tabItem { AppTab.insights.label }
                .accessibilityIdentifier("tab-insights")

            GoalsListView()
                .tag(AppTab.goals)
                .tabItem { AppTab.goals.label }
                .accessibilityIdentifier("tab-goals")

            SettingsView()
                .tag(AppTab.settings)
                .tabItem { AppTab.settings.label }
                .accessibilityIdentifier("tab-settings")
        }
    }

    public init() {}
}

#Preview {
    ContentView()
        .environment(try! AppContainer.preview())
}
