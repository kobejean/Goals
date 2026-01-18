import SwiftUI
import Charts
import GoalsDomain
import GoalsData

/// Detail view for a single goal showing progress and history
public struct GoalDetailView: View {
    @Environment(AppContainer.self) private var container
    @State private var goal: Goal
    @State private var dataPoints: [DataPoint] = []
    @State private var isLoading = true
    @State private var showingAddProgress = false

    public init(goal: Goal) {
        self._goal = State(initialValue: goal)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Progress header
                progressHeader

                // Progress chart
                if !dataPoints.isEmpty {
                    progressChart
                }

                // Goal details
                detailsSection

                // Actions
                actionsSection

                // History
                historySection
            }
            .padding()
        }
        .navigationTitle(goal.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingAddProgress = true
                    } label: {
                        Label("Add Progress", systemImage: "plus.circle")
                    }

                    Divider()

                    Button(role: .destructive) {
                        Task {
                            try? await container.goalRepository.archive(id: goal.id)
                        }
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddProgress) {
            NavigationStack {
                AddProgressView(goal: goal) {
                    await loadData()
                }
            }
        }
        .task {
            await loadData()
        }
    }

    @ViewBuilder
    private var progressHeader: some View {
        VStack(spacing: 16) {
            ProgressRingView(
                progress: goal.progress,
                lineWidth: 16,
                size: 150,
                color: goal.color.swiftUIColor
            )

            Text("\(Int(goal.progress * 100))%")
                .font(.largeTitle)
                .fontWeight(.bold)

            progressDescription
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var progressDescription: some View {
        switch goal.type {
        case .numeric:
            if let current = goal.currentValue, let target = goal.targetValue, let unit = goal.unit {
                Text("\(Int(current)) / \(Int(target)) \(unit)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

        case .habit:
            if let streak = goal.currentStreak {
                VStack(spacing: 4) {
                    Text("\(streak) day streak")
                        .font(.headline)

                    if let longest = goal.longestStreak, longest > streak {
                        Text("Best: \(longest) days")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

        case .milestone:
            Text(goal.isCompleted ? "Completed!" : "In Progress")
                .font(.headline)
                .foregroundStyle(goal.isCompleted ? .green : .secondary)

        case .compound:
            Text("Compound Goal")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var progressChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress Over Time")
                .font(.headline)

            Chart(dataPoints) { point in
                LineMark(
                    x: .value("Date", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(goal.color.swiftUIColor)

                PointMark(
                    x: .value("Date", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(goal.color.swiftUIColor)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5))
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            VStack(spacing: 8) {
                DetailRow(label: "Type", value: goal.type.displayName, icon: goal.type.iconName)
                DetailRow(label: "Source", value: goal.dataSource.displayName, icon: goal.dataSource.iconName)

                if let deadline = goal.deadline {
                    DetailRow(
                        label: "Deadline",
                        value: deadline.formatted(date: .abbreviated, time: .omitted),
                        icon: "calendar"
                    )
                }

                DetailRow(
                    label: "Created",
                    value: goal.createdAt.formatted(date: .abbreviated, time: .omitted),
                    icon: "clock"
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var actionsSection: some View {
        VStack(spacing: 12) {
            switch goal.type {
            case .numeric:
                Button {
                    showingAddProgress = true
                } label: {
                    Label("Update Progress", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

            case .habit:
                Button {
                    Task {
                        try? await container.trackProgressUseCase.checkInHabit(goalId: goal.id)
                        await loadData()
                    }
                } label: {
                    Label("Check In Today", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

            case .milestone:
                if !goal.isCompleted {
                    Button {
                        Task {
                            try? await container.trackProgressUseCase.completeMilestone(goalId: goal.id)
                            await loadData()
                        }
                    } label: {
                        Label("Mark Complete", systemImage: "flag.checkered")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

            case .compound:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.headline)

            if dataPoints.isEmpty {
                Text("No progress recorded yet")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(dataPoints.prefix(10)) { point in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(point.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)

                            if let note = point.note {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Text("\(Int(point.value))")
                            .font(.headline)
                    }
                    .padding(.vertical, 4)

                    if point.id != dataPoints.prefix(10).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func loadData() async {
        isLoading = true
        do {
            if let updatedGoal = try await container.goalRepository.fetch(id: goal.id) {
                goal = updatedGoal
            }

            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .month, value: -1, to: endDate) ?? endDate
            dataPoints = try await container.dataPointRepository.fetch(
                goalId: goal.id,
                from: startDate,
                to: endDate
            )
        } catch {
            print("Failed to load goal data: \(error)")
        }
        isLoading = false
    }
}

/// Detail row component
struct DetailRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
        }
    }
}

#Preview {
    NavigationStack {
        GoalDetailView(goal: Goal(
            title: "Save $10,000",
            type: .numeric,
            targetValue: 10000,
            currentValue: 4500,
            unit: "USD"
        ))
    }
    .environment(try! AppContainer.preview())
}
