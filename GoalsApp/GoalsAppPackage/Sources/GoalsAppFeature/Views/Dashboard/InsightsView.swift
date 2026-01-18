import SwiftUI
import Charts
import GoalsDomain
import GoalsData

/// Insights view showing analytics and trends
public struct InsightsView: View {
    @Environment(AppContainer.self) private var container
    @State private var goals: [Goal] = []
    @State private var selectedTimeRange: TimeRange = .week
    @State private var isLoading = true

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Time range picker
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if goals.isEmpty {
                        emptyStateView
                    } else {
                        // Goal completion chart
                        completionChart

                        // Goal type distribution
                        typeDistributionChart

                        // Stats summary
                        statsSummary
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Insights")
            .task {
                await loadData()
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Data Yet", systemImage: "chart.bar.xaxis")
        } description: {
            Text("Create goals and track progress to see insights here.")
        }
    }

    @ViewBuilder
    private var completionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goal Completion")
                .font(.headline)

            let completed = goals.filter { $0.isAchieved }.count
            let inProgress = goals.filter { !$0.isAchieved && !$0.isArchived }.count
            let archived = goals.filter { $0.isArchived }.count

            Chart {
                SectorMark(
                    angle: .value("Count", completed),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(.green)
                .annotation(position: .overlay) {
                    Text("\(completed)")
                        .font(.caption)
                        .foregroundStyle(.white)
                }

                SectorMark(
                    angle: .value("Count", inProgress),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(.blue)
                .annotation(position: .overlay) {
                    Text("\(inProgress)")
                        .font(.caption)
                        .foregroundStyle(.white)
                }

                SectorMark(
                    angle: .value("Count", archived),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(.gray)
                .annotation(position: .overlay) {
                    if archived > 0 {
                        Text("\(archived)")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(height: 200)

            HStack(spacing: 20) {
                LegendItem(color: .green, label: "Completed")
                LegendItem(color: .blue, label: "In Progress")
                LegendItem(color: .gray, label: "Archived")
            }
            .font(.caption)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    @ViewBuilder
    private var typeDistributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goals by Type")
                .font(.headline)

            let typeCounts = Dictionary(grouping: goals, by: { $0.type })
                .mapValues { $0.count }

            Chart {
                ForEach(GoalType.allCases, id: \.self) { type in
                    BarMark(
                        x: .value("Type", type.displayName),
                        y: .value("Count", typeCounts[type] ?? 0)
                    )
                    .foregroundStyle(by: .value("Type", type.displayName))
                }
            }
            .frame(height: 150)
            .chartLegend(.hidden)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    @ViewBuilder
    private var statsSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                SummaryCard(
                    title: "Total Goals",
                    value: "\(goals.count)",
                    icon: "target"
                )

                SummaryCard(
                    title: "Completion Rate",
                    value: "\(completionRate)%",
                    icon: "percent"
                )

                SummaryCard(
                    title: "Active Streaks",
                    value: "\(activeStreaksCount)",
                    icon: "flame"
                )

                SummaryCard(
                    title: "Avg Progress",
                    value: "\(averageProgress)%",
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var completionRate: Int {
        guard !goals.isEmpty else { return 0 }
        let completed = goals.filter { $0.isAchieved }.count
        return Int(Double(completed) / Double(goals.count) * 100)
    }

    private var activeStreaksCount: Int {
        goals.filter { $0.type == .habit && ($0.currentStreak ?? 0) > 0 }.count
    }

    private var averageProgress: Int {
        guard !goals.isEmpty else { return 0 }
        let total = goals.reduce(0.0) { $0 + $1.progress }
        return Int(total / Double(goals.count) * 100)
    }

    private func loadData() async {
        isLoading = true
        do {
            goals = try await container.goalRepository.fetchAll()
        } catch {
            print("Failed to load goals: \(error)")
        }
        isLoading = false
    }

    public init() {}
}

/// Time range for insights
enum TimeRange: String, CaseIterable {
    case week
    case month
    case year
    case all

    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        case .all: return "All"
        }
    }
}

/// Legend item component
struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}

/// Summary card component
struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    InsightsView()
        .environment(try! AppContainer.preview())
}
