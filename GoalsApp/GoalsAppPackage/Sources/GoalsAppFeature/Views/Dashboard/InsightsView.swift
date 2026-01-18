import SwiftUI
import GoalsDomain
import GoalsData

/// Insights view showing minimalistic overview cards with sparkline charts
public struct InsightsView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModels: [any InsightsSectionViewModel] = []
    @State private var displayMode: InsightDisplayMode = .chart

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(viewModels.enumerated()), id: \.offset) { _, vm in
                        if vm.isLoading {
                            InsightCardSkeleton()
                        } else if let summary = vm.summary {
                            NavigationLink {
                                vm.makeDetailView()
                            } label: {
                                InsightCard(
                                    summary: summary,
                                    activityData: vm.activityData,
                                    mode: displayMode
                                )
                            }
                            .buttonStyle(.plain)
                        }
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
