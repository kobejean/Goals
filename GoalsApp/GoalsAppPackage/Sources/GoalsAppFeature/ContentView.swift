import SwiftUI

/// Root content view with tab navigation
public struct ContentView: View {
    @Environment(AppContainer.self) private var container
    @State private var selectedTab: AppTab = .insights

    public var body: some View {
        TabView(selection: $selectedTab) {
            InsightsView()
                .tag(AppTab.insights)
                .tabItem { AppTab.insights.label }
                .accessibilityIdentifier("tab-insights")

            DailyView()
                .tag(AppTab.daily)
                .tabItem { AppTab.daily.label }
                .accessibilityIdentifier("tab-daily")

            GoalsListView()
                .tag(AppTab.goals)
                .tabItem { AppTab.goals.label }
                .accessibilityIdentifier("tab-goals")

            SettingsView()
                .tag(AppTab.settings)
                .tabItem { AppTab.settings.label }
                .accessibilityIdentifier("tab-settings")
        }
        .overlay(alignment: .top) {
            if let notification = container.badgeNotificationManager.currentNotification {
                BadgeToastView(notification: notification) {
                    container.badgeNotificationManager.dismiss()
                }
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(duration: 0.3), value: notification.id)
            }
        }
    }

    public init() {}
}

#Preview {
    ContentView()
        .environment(try! AppContainer.preview())
}
