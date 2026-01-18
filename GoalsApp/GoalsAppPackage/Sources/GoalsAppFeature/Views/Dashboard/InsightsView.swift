import SwiftUI
import GoalsDomain
import GoalsData

/// Insights view showing time-based trends and analytics
public struct InsightsView: View {
    @Environment(AppContainer.self) private var container
    @State private var selectedTimeRange: TimeRange = .all
    @State private var viewModels: [any InsightsSectionViewModel] = []

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModels.isEmpty || viewModels.allSatisfy(\.isLoading) {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        ForEach(Array(viewModels.enumerated()), id: \.offset) { _, viewModel in
                            viewModel.makeSection(timeRange: selectedTimeRange)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Insights")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }
            .task {
                await initialize()
            }
            .onChange(of: selectedTimeRange) {
                Task {
                    await loadAll()
                }
            }
        }
    }

    // MARK: - Initialization

    private func initialize() async {
        viewModels = container.makeInsightsViewModels()
        await loadAll()
    }

    private func loadAll() async {
        await withTaskGroup(of: Void.self) { group in
            for viewModel in viewModels {
                group.addTask {
                    await viewModel.loadData(timeRange: selectedTimeRange)
                }
            }
        }
    }

    public init() {}
}

#Preview {
    InsightsView()
        .environment(try! AppContainer.preview())
}
