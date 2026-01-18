import SwiftUI
import Charts
import GoalsDomain
import GoalsData

/// Dashboard view showing today's focus and data source stats
public struct DashboardView: View {
    @Environment(AppContainer.self) private var container
    @State private var goals: [Goal] = []
    @State private var typeQuickerStats: [TypeQuickerStats] = []
    @State private var isLoading = true
    @State private var isLoadingStats = true
    @State private var isSyncing = false

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Goals overview section
                    goalsOverviewSection

                    // TypeQuicker stats widget
                    typeQuickerSection

                    // Quick add section
                    quickAddSection
                }
                .padding()
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await syncAllData()
                        }
                    } label: {
                        if isSyncing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(isSyncing)
                }
            }
            .task {
                await loadData()
            }
            .refreshable {
                await syncAllData()
                await loadData()
            }
        }
    }

    // MARK: - Goals Overview Section

    @ViewBuilder
    private var goalsOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(.blue)
                Text("Goals Overview")
                    .font(.headline)
                Spacer()
                Text("\(goals.count) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if goals.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text("No goals yet")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Create a goal to start tracking")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Show top 3 goals by progress
                VStack(spacing: 8) {
                    ForEach(goals.sorted { $0.progress > $1.progress }.prefix(3)) { goal in
                        GoalProgressRow(goal: goal)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - TypeQuicker Stats Section

    @ViewBuilder
    private var typeQuickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "keyboard")
                    .foregroundStyle(.blue)
                Text("Typing Stats")
                    .font(.headline)
                Spacer()
                Text("TypeQuicker")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isLoadingStats {
                HStack {
                    ProgressView()
                    Text("Loading stats...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if let latestStats = typeQuickerStats.last {
                // Latest stats display
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    TypeQuickerStatCard(
                        value: String(format: "%.0f", latestStats.wordsPerMinute),
                        unit: "WPM",
                        icon: "speedometer",
                        color: .blue
                    )

                    TypeQuickerStatCard(
                        value: String(format: "%.1f%%", latestStats.accuracy),
                        unit: "Accuracy",
                        icon: "target",
                        color: .green
                    )

                    TypeQuickerStatCard(
                        value: "\(latestStats.practiceTimeMinutes)",
                        unit: "Minutes",
                        icon: "clock",
                        color: .orange
                    )
                }

                // Weekly trend chart
                if typeQuickerStats.count > 1 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This Week")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Chart(typeQuickerStats, id: \.date) { stat in
                            LineMark(
                                x: .value("Date", stat.date, unit: .day),
                                y: .value("WPM", stat.wordsPerMinute)
                            )
                            .foregroundStyle(.blue)
                        }
                        .frame(height: 80)
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                    }
                }

                // Sessions count
                HStack {
                    Text("\(latestStats.sessionsCount) sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(latestStats.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "keyboard.badge.ellipsis")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No typing data yet")
                        .font(.subheadline)
                    Text("Configure TypeQuicker in Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Quick Add Section

    @ViewBuilder
    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                NavigationLink {
                    CreateGoalView {
                        await loadGoals()
                    }
                } label: {
                    QuickActionButton(
                        title: "New Goal",
                        icon: "plus.circle.fill",
                        color: .blue
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    GoalsListView()
                } label: {
                    QuickActionButton(
                        title: "All Goals",
                        icon: "list.bullet",
                        color: .purple
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        isLoadingStats = true

        async let goalsTask: () = loadGoals()
        async let statsTask: () = loadTypeQuickerStats()

        await goalsTask
        await statsTask

        isLoading = false
        isLoadingStats = false
    }

    private func loadGoals() async {
        do {
            goals = try await container.goalRepository.fetchActive()
        } catch {
            print("Failed to load goals: \(error)")
        }
    }

    private func loadTypeQuickerStats() async {
        // First, try to configure from saved settings
        if let username = UserDefaults.standard.string(forKey: "typeQuickerUsername"), !username.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .typeQuicker,
                credentials: ["username": username]
            )
            try? await container.typeQuickerDataSource.configure(settings: settings)
        }

        // Check if configured
        guard await container.typeQuickerDataSource.isConfigured() else {
            isLoadingStats = false
            return
        }

        // Fetch last 7 days of stats
        do {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
            typeQuickerStats = try await container.typeQuickerDataSource.fetchStats(from: startDate, to: endDate)
        } catch {
            print("Failed to load TypeQuicker stats: \(error)")
        }
    }

    private func syncAllData() async {
        isSyncing = true
        _ = try? await container.syncDataSourcesUseCase.syncAll()
        await loadData()
        isSyncing = false
    }

    public init() {}
}

// MARK: - Supporting Views

struct GoalProgressRow: View {
    let goal: Goal

    var body: some View {
        HStack {
            Circle()
                .fill(goal.color.swiftUIColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: goal.dataSource.iconName)
                        .foregroundStyle(goal.color.swiftUIColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text("\(Int(goal.currentValue))/\(Int(goal.targetValue)) \(goal.unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(Int(goal.progress * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(goal.progress >= 1.0 ? .green : .secondary)
        }
        .padding(.vertical, 4)
    }
}

struct TypeQuickerStatCard: View {
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    DashboardView()
        .environment(try! AppContainer.preview())
}
