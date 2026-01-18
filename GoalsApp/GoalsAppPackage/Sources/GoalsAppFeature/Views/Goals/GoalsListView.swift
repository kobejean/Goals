import SwiftUI
import GoalsDomain
import GoalsData

/// List view showing all goals with filtering options
public struct GoalsListView: View {
    @Environment(AppContainer.self) private var container
    @State private var goals: [Goal] = []
    @State private var isLoading = true
    @State private var showingCreateGoal = false
    @State private var filterDataSource: DataSourceType? = nil
    @State private var showArchived = false

    public var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading goals...")
                } else if filteredGoals.isEmpty {
                    emptyStateView
                } else {
                    goalsList
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateGoal = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            filterDataSource = nil
                        } label: {
                            HStack {
                                Text("All Sources")
                                if filterDataSource == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        ForEach(DataSourceType.allCases, id: \.self) { source in
                            Button {
                                filterDataSource = source
                            } label: {
                                HStack {
                                    Label(source.displayName, systemImage: source.iconName)
                                    if filterDataSource == source {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }

                        Divider()

                        Toggle("Show Archived", isOn: $showArchived)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingCreateGoal) {
                NavigationStack {
                    CreateGoalView {
                        await loadGoals()
                    }
                }
            }
            .task {
                // Sync data sources first, then load goals
                _ = try? await container.syncDataSourcesUseCase.syncAll()
                await loadGoals()
            }
            .refreshable {
                // Sync all data sources on pull to refresh
                _ = try? await container.syncDataSourcesUseCase.syncAll()
                await loadGoals()
            }
        }
    }

    @ViewBuilder
    private var goalsList: some View {
        List {
            ForEach(filteredGoals) { goal in
                NavigationLink {
                    GoalDetailView(goal: goal)
                } label: {
                    GoalRowView(goal: goal)
                }
            }
            .onDelete(perform: deleteGoals)
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Goals", systemImage: "target")
        } description: {
            if let source = filterDataSource {
                Text("No \(source.displayName) goals found.")
            } else {
                Text("Create your first goal to start tracking progress.")
            }
        } actions: {
            Button {
                showingCreateGoal = true
            } label: {
                Text("Create Goal")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var filteredGoals: [Goal] {
        var result = goals

        if !showArchived {
            result = result.filter { !$0.isArchived }
        }

        if let filterDataSource = filterDataSource {
            result = result.filter { $0.dataSource == filterDataSource }
        }

        return result
    }

    private func loadGoals() async {
        isLoading = true
        do {
            goals = try await container.goalRepository.fetchAll()
        } catch {
            print("Failed to load goals: \(error)")
        }
        isLoading = false
    }

    private func deleteGoals(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let goal = filteredGoals[index]
                do {
                    try await container.goalRepository.delete(id: goal.id)
                    goals.removeAll { $0.id == goal.id }
                } catch {
                    print("Failed to delete goal: \(error)")
                }
            }
        }
    }

    public init() {}
}

#Preview {
    GoalsListView()
        .environment(try! AppContainer.preview())
}
