import SwiftUI
import Charts
import GoalsDomain
import GoalsData

/// Dashboard view showing goal progress overview and widgets
public struct DashboardView: View {
    @Environment(AppContainer.self) private var container
    @State private var goals: [Goal] = []
    @State private var isLoading = true

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Overall progress section
                    overallProgressSection

                    // Quick stats
                    quickStatsSection

                    // Recent goals
                    recentGoalsSection
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .task {
                await loadGoals()
            }
            .refreshable {
                await loadGoals()
            }
        }
    }

    @ViewBuilder
    private var overallProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overall Progress")
                .font(.headline)

            HStack(spacing: 20) {
                ProgressRingView(
                    progress: overallProgress,
                    lineWidth: 12,
                    size: 100
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(completedGoalsCount) of \(goals.count) goals completed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("\(Int(overallProgress * 100))%")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }

                Spacer()
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Stats")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Active Goals",
                    value: "\(goals.filter { !$0.isArchived }.count)",
                    icon: "target",
                    color: .blue
                )

                StatCard(
                    title: "Habits",
                    value: "\(goals.filter { $0.type == .habit }.count)",
                    icon: "repeat.circle",
                    color: .green
                )

                StatCard(
                    title: "Milestones",
                    value: "\(goals.filter { $0.type == .milestone && $0.isCompleted }.count)/\(goals.filter { $0.type == .milestone }.count)",
                    icon: "flag.circle",
                    color: .purple
                )

                StatCard(
                    title: "This Week",
                    value: "—",
                    icon: "calendar",
                    color: .orange
                )
            }
        }
    }

    @ViewBuilder
    private var recentGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Goals")
                    .font(.headline)

                Spacer()

                NavigationLink {
                    GoalsListView()
                } label: {
                    Text("See All")
                        .font(.subheadline)
                }
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if goals.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 8) {
                    ForEach(goals.prefix(3)) { goal in
                        GoalRowView(goal: goal)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No goals yet")
                .font(.headline)

            Text("Create your first goal to start tracking progress")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            NavigationLink {
                CreateGoalView()
            } label: {
                Text("Create Goal")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var overallProgress: Double {
        guard !goals.isEmpty else { return 0 }
        let total = goals.reduce(0.0) { $0 + $1.progress }
        return total / Double(goals.count)
    }

    private var completedGoalsCount: Int {
        goals.filter { $0.isAchieved }.count
    }

    private func loadGoals() async {
        isLoading = true
        do {
            goals = try await container.goalRepository.fetchActive()
        } catch {
            print("Failed to load goals: \(error)")
        }
        isLoading = false
    }

    public init() {}
}

/// Quick stat card component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    DashboardView()
        .environment(try! AppContainer.preview())
}
