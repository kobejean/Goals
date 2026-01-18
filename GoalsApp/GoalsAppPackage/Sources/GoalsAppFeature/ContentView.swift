import SwiftUI
import SwiftData
import GoalsDomain
import GoalsData

/// Root content view with tab navigation
public struct ContentView: View {
    @State private var selectedTab: AppTab = .today
    @Environment(AppContainer.self) private var container

    public var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tag(AppTab.today)
                .tabItem { AppTab.today.label }

            GoalsListView()
                .tag(AppTab.goals)
                .tabItem { AppTab.goals.label }

            InsightsView()
                .tag(AppTab.insights)
                .tabItem { AppTab.insights.label }

            SettingsView()
                .tag(AppTab.settings)
                .tabItem { AppTab.settings.label }
        }
    }

    public init() {}
}

#Preview {
    ContentView()
        .environment(try! AppContainer.preview())
}
