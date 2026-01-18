import SwiftUI
import Charts
import GoalsDomain
import GoalsData

/// Dashboard view showing today's focus and actionable items
public struct DashboardView: View {
    @Environment(AppContainer.self) private var container
    @State private var goals: [Goal] = []
    @State private var typeQuickerStats: [TypeQuickerStats] = []
    @State private var isLoading = true
    @State private var isLoadingStats = true
    @State private var showingAddProgress = false
    @State private var selectedGoal: Goal?

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Today's Focus section
                    todaysFocusSection

                    // TypeQuicker stats widget
                    typeQuickerSection

                    // Goals needing attention
                    goalsNeedingAttentionSection

                    // Quick add section
                    quickAddSection
                }
                .padding()
            }
            .navigationTitle("Today")
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
            .sheet(isPresented: $showingAddProgress) {
                if let goal = selectedGoal {
                    NavigationStack {
                        AddProgressView(goal: goal) {
                            await loadGoals()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Today's Focus Section

    @ViewBuilder
    private var todaysFocusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.orange)
                Text("Today's Focus")
                    .font(.headline)
                Spacer()
                Text(Date(), style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if habitsNeedingCheckIn.isEmpty && goalsDueSoon.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading) {
                        Text("All caught up!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("No habits or goals need attention today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 8) {
                    // Habits needing check-in
                    ForEach(habitsNeedingCheckIn) { goal in
                        HabitCheckInRow(goal: goal) {
                            selectedGoal = goal
                            showingAddProgress = true
                        }
                    }

                    // Goals due soon
                    ForEach(goalsDueSoon) { goal in
                        GoalDueSoonRow(goal: goal)
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

                            AreaMark(
                                x: .value("Date", stat.date, unit: .day),
                                y: .value("WPM", stat.wordsPerMinute)
                            )
                            .foregroundStyle(.blue.opacity(0.1))
                        }
                        .frame(height: 80)
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                    }
                }

                // Sessions count
                HStack {
                    Text("\(latestStats.sessionsCount) sessions today")
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

    // MARK: - Goals Needing Attention

    @ViewBuilder
    private var goalsNeedingAttentionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text("Needs Attention")
                    .font(.headline)
                Spacer()
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if streaksAtRisk.isEmpty && staleGoals.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    Text("All goals are on track!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
            } else {
                VStack(spacing: 8) {
                    // Streaks at risk
                    ForEach(streaksAtRisk) { goal in
                        StreakAtRiskRow(goal: goal) {
                            selectedGoal = goal
                            showingAddProgress = true
                        }
                    }

                    // Stale goals (no progress in a while)
                    ForEach(staleGoals.prefix(3)) { goal in
                        StaleGoalRow(goal: goal)
                    }
                }
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
                    CreateGoalView()
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

    // MARK: - Computed Properties

    private var habitsNeedingCheckIn: [Goal] {
        goals.filter { goal in
            goal.type == .habit && !goal.isArchived && !goal.isAchieved
        }
    }

    private var goalsDueSoon: [Goal] {
        let calendar = Calendar.current
        let today = Date()
        let threeDaysFromNow = calendar.date(byAdding: .day, value: 3, to: today)!

        return goals.filter { goal in
            guard let deadline = goal.deadline, !goal.isArchived, !goal.isAchieved else {
                return false
            }
            return deadline <= threeDaysFromNow && deadline >= today
        }
    }

    private var streaksAtRisk: [Goal] {
        goals.filter { goal in
            guard goal.type == .habit, !goal.isArchived else { return false }
            let streak = goal.currentStreak ?? 0
            return streak > 0 && streak < 3 // Low streaks that could be lost
        }
    }

    private var staleGoals: [Goal] {
        goals.filter { goal in
            guard !goal.isArchived, !goal.isAchieved, goal.type == .numeric else {
                return false
            }
            // Show goals with low progress (would need lastUpdated field for true staleness)
            return goal.progress < 0.3
        }
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

    public init() {}
}

// MARK: - Supporting Views

struct HabitCheckInRow: View {
    let goal: Goal
    let onCheckIn: () -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(goal.color.swiftUIColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "repeat.circle")
                        .foregroundStyle(goal.color.swiftUIColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let streak = goal.currentStreak, streak > 0 {
                    Text("\(streak) day streak")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("Start your streak!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: onCheckIn) {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

struct GoalDueSoonRow: View {
    let goal: Goal

    var body: some View {
        HStack {
            Circle()
                .fill(goal.color.swiftUIColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundStyle(goal.color.swiftUIColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let deadline = goal.deadline {
                    Text("Due \(deadline, style: .relative)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            Text("\(Int(goal.progress * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct StreakAtRiskRow: View {
    let goal: Goal
    let onCheckIn: () -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(.orange.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "flame")
                        .foregroundStyle(.orange)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Streak at risk!")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()

            Button(action: onCheckIn) {
                Text("Check in")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

struct StaleGoalRow: View {
    let goal: Goal

    var body: some View {
        HStack {
            Circle()
                .fill(goal.color.swiftUIColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(goal.color.swiftUIColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Needs progress update")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(Int(goal.progress * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
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
