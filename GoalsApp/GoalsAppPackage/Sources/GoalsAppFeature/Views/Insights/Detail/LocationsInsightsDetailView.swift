import SwiftUI
import Charts
import GoalsDomain
import GoalsWidgetShared

/// Locations insights detail view with charts and breakdown
struct LocationsInsightsDetailView: View {
    @Bindable var viewModel: LocationsInsightsViewModel
    @AppStorage(UserDefaultsKeys.locationsInsightsTimeRange) private var timeRange: TimeRange = .month

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Unable to Load", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                } else if viewModel.sessions.isEmpty {
                    emptyStateView
                } else if filteredSummaries.isEmpty {
                    noDataInRangeView
                } else {
                    scheduleChartSection
                    locationDistributionSection
                }
            }
            .padding()
        }
        .navigationTitle("Locations")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.sessions.isEmpty {
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
            viewModel.startLiveUpdates()
        }
        .onDisappear {
            viewModel.stopLiveUpdates()
        }
    }

    // MARK: - Filtered Data

    private var filteredSummaries: [LocationDailySummary] {
        viewModel.filteredDailySummaries(for: timeRange)
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Location Data")
                .font(.headline)

            Text("Start tracking locations to see your insights here.")
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
            Text("No location data in this range")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let lastDate = viewModel.dailySummaries.last?.date {
                Text("Last tracked: \(lastDate, format: .dateTime.month().day().year())")
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
            .tint(.cyan)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var scheduleChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Schedule")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScheduleChart(
                data: scheduleChartData,
                style: .full,
                configuration: ScheduleChartConfiguration(
                    legendItems: locationsWithData.map { location in
                        ScheduleLegendItem(name: location.name, color: location.color.swiftUIColor)
                    },
                    chartHeight: 220
                )
            )
        }
    }

    // MARK: - Schedule Chart Data Conversion

    /// Convert filtered summaries to InsightDurationRangeData for the schedule chart
    private var scheduleChartData: InsightDurationRangeData {
        let dataPoints = filteredSummaries.compactMap { summary -> DurationRangeDataPoint? in
            let segments = summary.sessions.compactMap { session -> DurationSegment? in
                // Use referenceDate for active sessions
                let endDate = session.endDate ?? viewModel.referenceDate

                // Skip if session started after reference date
                guard session.startDate <= viewModel.referenceDate else { return nil }

                return DurationSegment(
                    startTime: session.startDate,
                    endTime: endDate,
                    color: session.locationColor.swiftUIColor,
                    label: session.locationName
                )
            }
            guard !segments.isEmpty else { return nil }
            return DurationRangeDataPoint(date: summary.date, segments: segments)
        }

        // Calculate date range for last 7 days with padding
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -6, to: today)!
        let paddedStart = calendar.date(byAdding: .hour, value: -12, to: startDate)!
        let paddedEnd = calendar.date(byAdding: .hour, value: 18, to: today)!

        return InsightDurationRangeData(
            dataPoints: dataPoints,
            defaultColor: .cyan,
            dateRange: DateRange(start: paddedStart, end: paddedEnd),
            useSimpleHours: true
        )
    }

    /// Locations that have data in the current filtered summaries
    private var locationsWithData: [LocationDefinition] {
        let locationIds = Set(filteredSummaries.flatMap { $0.sessions.map(\.locationId) })
        return viewModel.locations.filter { locationIds.contains($0.id) }
    }

    private var locationDistributionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time Distribution (\(timeRange.displayName))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LocationDistributionChart(
                summaries: filteredSummaries,
                locations: viewModel.locations,
                formatDuration: viewModel.formatDuration
            )
        }
    }
}

// MARK: - Location Distribution Chart

private struct LocationDistributionChart: View {
    let summaries: [LocationDailySummary]
    let locations: [LocationDefinition]
    let formatDuration: (TimeInterval) -> String

    private var locationDurations: [(location: LocationDefinition, duration: TimeInterval)] {
        var durations: [UUID: TimeInterval] = [:]

        for summary in summaries {
            for session in summary.sessions {
                durations[session.locationId, default: 0] += session.duration
            }
        }

        return locations.compactMap { location -> (LocationDefinition, TimeInterval)? in
            guard let duration = durations[location.id], duration > 0 else { return nil }
            return (location, duration)
        }.sorted { $0.duration > $1.duration }
    }

    private var totalDuration: TimeInterval {
        locationDurations.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Pie chart
            if !locationDurations.isEmpty {
                Chart(locationDurations, id: \.location.id) { item in
                    SectorMark(
                        angle: .value("Duration", item.duration),
                        innerRadius: .ratio(0.5),
                        angularInset: 1
                    )
                    .foregroundStyle(item.location.color.swiftUIColor)
                    .cornerRadius(4)
                }
                .frame(height: 200)
            }

            // Legend with durations
            VStack(spacing: 8) {
                ForEach(locationDurations, id: \.location.id) { item in
                    HStack {
                        Circle()
                            .fill(item.location.color.swiftUIColor)
                            .frame(width: 12, height: 12)

                        Text(item.location.name)
                            .font(.subheadline)

                        Spacer()

                        Text(formatDuration(item.duration))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Text("(\(Int((item.duration / totalDuration) * 100))%)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LocationsInsightsDetailView(
            viewModel: LocationsInsightsViewModel(
                locationRepository: PreviewLocationRepository(),
                goalRepository: PreviewGoalRepository()
            )
        )
    }
}
