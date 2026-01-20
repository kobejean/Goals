import SwiftUI
import GoalsDomain
import GoalsData

/// Insights view showing minimalistic overview cards with sparkline charts
public struct InsightsView: View {
    @Environment(AppContainer.self) private var container
    @State private var displayMode: InsightDisplayMode = .chart

    public var body: some View {
        NavigationStack {
            TabView(selection: $displayMode) {
                insightsList(mode: .chart)
                    .tag(InsightDisplayMode.chart)
                insightsList(mode: .activity)
                    .tag(InsightDisplayMode.activity)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: displayMode)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("Insights")
                            .font(.largeTitle.bold())
                        Spacer()
                        Picker("Mode", selection: $displayMode) {
                            ForEach(InsightDisplayMode.allCases, id: \.self) { mode in
                                Image(systemName: mode.systemImage).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .task(id: container.settingsRevision) {
                // Load/reload data - existing data stays visible during load
                await container.insightsViewModel.loadAll()
                // Start live updates for tasks if active session exists
                container.insightsViewModel.tasks.startLiveUpdates()
            }
            .onAppear {
                // Restart timer when returning from detail view
                container.insightsViewModel.tasks.startLiveUpdates()
            }
            .onDisappear {
                container.insightsViewModel.tasks.stopLiveUpdates()
            }
        }
    }

    @ViewBuilder
    private func insightsList(mode: InsightDisplayMode) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(container.insightsViewModel.cards) { card in
                    NavigationLink {
                        card.makeDetailView()
                    } label: {
                        InsightCard(
                            title: card.title,
                            systemImage: card.systemImage,
                            color: card.color,
                            summary: card.summary,
                            activityData: card.activityData,
                            mode: mode
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    public init() {}
}

#Preview {
    InsightsView()
        .environment(try! AppContainer.preview())
}
