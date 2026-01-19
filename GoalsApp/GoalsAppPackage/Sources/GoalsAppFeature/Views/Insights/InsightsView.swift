import SwiftUI
import GoalsDomain
import GoalsData

/// Insights view showing minimalistic overview cards with sparkline charts
public struct InsightsView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModels: [any InsightsSectionViewModel] = []
    @State private var displayMode: InsightDisplayMode = .chart
    // Force refresh after data loads - needed because type erasure breaks @Observable tracking
    @State private var refreshTrigger = false

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(viewModels.enumerated()), id: \.offset) { index, vm in
                        NavigationLink {
                            vm.makeDetailView()
                        } label: {
                            InsightCard(
                                title: vm.title,
                                systemImage: vm.systemImage,
                                color: vm.color,
                                summary: vm.summary,
                                activityData: vm.activityData,
                                mode: displayMode
                            )
                        }
                        .buttonStyle(.plain)
                        // Force view recreation when refresh triggers
                        .id("\(index)-\(refreshTrigger)")
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
            .task {
                viewModels = container.makeInsightsViewModels()
                await loadAll()
                refreshTrigger.toggle()
            }
            .task(id: container.settingsRevision) {
                guard container.settingsRevision > 0 else { return }
                viewModels = container.makeInsightsViewModels()
                await loadAll()
                refreshTrigger.toggle()
            }
        }
    }

    private func loadAll() async {
        await withTaskGroup(of: Void.self) { group in
            for vm in viewModels {
                group.addTask { await vm.loadData() }
            }
        }
    }

    public init() {}
}

#Preview {
    InsightsView()
        .environment(try! AppContainer.preview())
}
