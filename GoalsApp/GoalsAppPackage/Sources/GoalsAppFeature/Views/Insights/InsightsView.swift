import SwiftUI
import GoalsDomain
import GoalsData

/// Insights view showing minimalistic overview cards with sparkline charts
public struct InsightsView: View {
    @Environment(AppContainer.self) private var container
    @State private var displayMode: InsightDisplayMode = .chart

    public var body: some View {
        NavigationStack {
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
                                mode: displayMode
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
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
            }
        }
    }

    public init() {}
}

#Preview {
    InsightsView()
        .environment(try! AppContainer.preview())
}
