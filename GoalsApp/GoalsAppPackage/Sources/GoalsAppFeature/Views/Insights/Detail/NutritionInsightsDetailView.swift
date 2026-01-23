import SwiftUI
import Charts
import GoalsDomain
import GoalsWidgetShared

/// Nutrition insights detail view with charts and breakdown
struct NutritionInsightsDetailView: View {
    @Bindable var viewModel: NutritionInsightsViewModel
    @AppStorage(UserDefaultsKeys.nutritionInsightsTimeRange) private var timeRange: TimeRange = .month

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Unable to Load", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                } else if viewModel.entries.isEmpty {
                    emptyStateView
                } else if filteredSummaries.isEmpty {
                    noDataInRangeView
                } else {
                    caloriesChartSection
                    macroBreakdownSection
                    dailyAveragesSection
                }
            }
            .padding()
        }
        .navigationTitle("Nutrition")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.entries.isEmpty {
                ToolbarItem(placement: .principal) {
                    Picker("Time Range", selection: $timeRange) {
                        ForEach([TimeRange.week, .month, .quarter, .year, .all], id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Filtered Data

    private var filteredSummaries: [NutritionDailySummary] {
        viewModel.filteredDailySummaries(for: timeRange)
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Nutrition Data")
                .font(.headline)

            Text("Start logging food to see your insights here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var noDataInRangeView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No nutrition data in this range")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let lastDate = viewModel.dailySummaries.last?.date {
                Text("Last logged: \(lastDate, format: .dateTime.month().day().year())")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Button {
                timeRange = .all
            } label: {
                Text("Show All Data")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.green)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var caloriesChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Calories")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Chart(filteredSummaries) { summary in
                BarMark(
                    x: .value("Date", summary.date, unit: .day),
                    y: .value("Calories", summary.totalNutrients.calories)
                )
                .foregroundStyle(Color.green.gradient)
                .cornerRadius(4)
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.15))
            )
        }
    }

    private var macroBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Macro Breakdown (\(timeRange.displayName))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let totalNutrients = filteredSummaries.reduce(NutrientValues.zero) { $0 + $1.totalNutrients }
            let avgNutrients = totalNutrients.divided(by: Double(max(1, filteredSummaries.count)))

            HStack(spacing: 16) {
                MacroCard(
                    name: "Protein",
                    value: avgNutrients.protein,
                    unit: "g",
                    color: .blue,
                    percentage: avgNutrients.proteinRatio
                )

                MacroCard(
                    name: "Carbs",
                    value: avgNutrients.carbohydrates,
                    unit: "g",
                    color: .green,
                    percentage: avgNutrients.carbsRatio
                )

                MacroCard(
                    name: "Fat",
                    value: avgNutrients.fat,
                    unit: "g",
                    color: .orange,
                    percentage: avgNutrients.fatRatio
                )
            }
        }
    }

    private var dailyAveragesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Averages (\(timeRange.displayName))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let totalNutrients = filteredSummaries.reduce(NutrientValues.zero) { $0 + $1.totalNutrients }
            let avgNutrients = totalNutrients.divided(by: Double(max(1, filteredSummaries.count)))

            VStack(spacing: 8) {
                NutrientAverageRow(label: "Calories", value: "\(Int(avgNutrients.calories))", unit: "kcal")
                NutrientAverageRow(label: "Protein", value: String(format: "%.1f", avgNutrients.protein), unit: "g")
                NutrientAverageRow(label: "Carbohydrates", value: String(format: "%.1f", avgNutrients.carbohydrates), unit: "g")
                NutrientAverageRow(label: "Fat", value: String(format: "%.1f", avgNutrients.fat), unit: "g")
                Divider()
                NutrientAverageRow(label: "Fiber", value: String(format: "%.1f", avgNutrients.fiber), unit: "g")
                NutrientAverageRow(label: "Sugar", value: String(format: "%.1f", avgNutrients.sugar), unit: "g")
                NutrientAverageRow(label: "Sodium", value: String(format: "%.0f", avgNutrients.sodium), unit: "mg")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.15))
            )
        }
    }
}

// MARK: - Supporting Views

private struct MacroCard: View {
    let name: String
    let value: Double
    let unit: String
    let color: Color
    let percentage: Double

    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(String(format: "%.0f", value))
                .font(.title2.weight(.semibold).monospacedDigit())

            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("\(Int(percentage * 100))%")
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

private struct NutrientAverageRow: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)

            Spacer()

            Text("\(value) \(unit)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - UserDefaults Key

extension UserDefaultsKeys {
    static let nutritionInsightsTimeRange = "nutritionInsightsTimeRange"
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NutritionInsightsDetailView(
            viewModel: NutritionInsightsViewModel(
                nutritionRepository: PreviewNutritionRepository()
            )
        )
    }
}

// MARK: - Preview Repository

private struct PreviewNutritionRepository: NutritionRepositoryProtocol {
    func fetchAllEntries() async throws -> [NutritionEntry] { [] }
    func fetchEntries(from startDate: Date, to endDate: Date) async throws -> [NutritionEntry] { [] }
    func fetchEntries(for date: Date) async throws -> [NutritionEntry] { [] }
    func fetchEntry(id: UUID) async throws -> NutritionEntry? { nil }
    func createEntry(_ entry: NutritionEntry) async throws -> NutritionEntry { entry }
    func updateEntry(_ entry: NutritionEntry) async throws -> NutritionEntry { entry }
    func deleteEntry(id: UUID) async throws {}
    func fetchDailySummaries(from startDate: Date, to endDate: Date) async throws -> [NutritionDailySummary] { [] }
    func fetchTodaySummary() async throws -> NutritionDailySummary? { nil }
}
