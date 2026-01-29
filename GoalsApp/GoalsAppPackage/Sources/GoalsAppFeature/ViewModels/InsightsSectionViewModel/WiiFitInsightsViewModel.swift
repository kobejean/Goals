import SwiftUI
import GoalsDomain
import GoalsData
import GoalsCore
import GoalsWidgetShared

/// ViewModel for Wii Fit insights section
@MainActor @Observable
public final class WiiFitInsightsViewModel: InsightsSectionViewModel {
    // MARK: - Static Properties

    public let title = "Wii Fit"
    public let systemImage = "scalemass.fill"
    public let color: Color = .cyan
    public let requiresThrottle = true

    // MARK: - Published State

    public private(set) var measurements: [WiiFitMeasurement] = []
    public private(set) var goals: [Goal] = []
    public private(set) var insight: (summary: InsightSummary?, activityData: InsightActivityData?) = (nil, nil)
    public private(set) var errorMessage: String?
    public private(set) var fetchStatus: InsightFetchStatus = .idle
    public var selectedMetric: WiiFitMetric = .weight

    // MARK: - Dependencies

    private let dataSource: any WiiFitDataSourceProtocol
    private let goalRepository: any GoalRepositoryProtocol

    // MARK: - Initialization

    public init(
        dataSource: any WiiFitDataSourceProtocol,
        goalRepository: any GoalRepositoryProtocol
    ) {
        self.dataSource = dataSource
        self.goalRepository = goalRepository
    }

    // MARK: - Computed Properties

    /// Latest weight measurement
    public var latestWeight: Double? {
        measurements.latest?.weightKg
    }

    /// Latest BMI
    public var latestBMI: Double? {
        measurements.latest?.bmi
    }

    /// Latest balance percentage
    public var latestBalance: Double? {
        measurements.latest?.balancePercent
    }

    /// Weight change over the last 7 days
    public var weeklyWeightChange: Double? {
        measurements.weightChange(days: 7)
    }

    /// Weight change over the last 30 days
    public var monthlyWeightChange: Double? {
        measurements.weightChange(days: 30)
    }

    /// Total number of measurements
    public var measurementCount: Int {
        measurements.count
    }

    /// Days since first measurement
    public var trackingDays: Int? {
        guard let earliest = measurements.min(by: { $0.date < $1.date }),
              let latest = measurements.max(by: { $0.date < $1.date }) else {
            return nil
        }
        return Calendar.current.dateComponents([.day], from: earliest.date, to: latest.date).day
    }

    /// Trend percentage for the selected metric
    public var metricTrend: Double? {
        switch selectedMetric {
        case .weight:
            return measurements.trendPercentage { $0.weightKg }
        case .bmi:
            return measurements.trendPercentage { $0.bmi }
        case .balance:
            return measurements.trendPercentage { $0.balancePercent }
        }
    }

    /// Rebuild insight from current measurements and goals
    private func rebuildInsight() {
        insight = WiiFitInsightProvider.build(from: measurements, goals: goals)
    }

    /// Get the goal target for a specific metric
    public func goalTarget(for metric: WiiFitMetric) -> Double? {
        goals.targetValue(for: metric.metricKey)
    }

    // MARK: - Chart Data Helpers

    /// Chart data points for the selected metric
    public var chartData: [WiiFitChartDataPoint] {
        measurements.map { m in
            WiiFitChartDataPoint(
                date: m.date,
                weight: m.weightKg,
                bmi: m.bmi,
                balance: m.balancePercent
            )
        }
    }

    /// Filter chart data by time range
    public func filteredChartData(for timeRange: TimeRange) -> [WiiFitChartDataPoint] {
        let cutoffDate = timeRange.startDate(from: Date())
        return chartData.filter { $0.date >= cutoffDate }
    }

    /// Calculate 7-day moving average for filtered chart data
    public func movingAverageData(for filteredData: [WiiFitChartDataPoint], metric: WiiFitMetric) -> [(date: Date, value: Double)] {
        let data = filteredData.map { (date: $0.date, value: $0.value(for: metric)) }
        return InsightCalculations.calculateMovingAverage(for: data, window: 7)
    }

    /// Calculate Y-axis range for chart, including goal line if present
    public func chartYAxisRange(for filteredData: [WiiFitChartDataPoint], metric: WiiFitMetric) -> ClosedRange<Double> {
        var values = filteredData.map { $0.value(for: metric) }

        if let goalTarget = goalTarget(for: metric) {
            values.append(goalTarget)
        }

        guard let minVal = values.min(), let maxVal = values.max() else {
            return 0...100
        }

        let range = maxVal - minVal
        let padding = Swift.max(range * 0.15, 1)

        let lower = Swift.max(0, minVal - padding)
        let upper = maxVal + padding

        return lower...upper
    }

    // MARK: - Data Loading

    public func loadCachedData() async {
        // Configure from saved settings if available
        if let settings = WiiFitDataSource.loadSettingsFromUserDefaults() {
            try? await dataSource.configure(settings: settings)
        }

        guard await dataSource.isConfigured() else { return }

        let endDate = Date()
        let startDate = TimeRange.all.startDate(from: endDate)

        // Load goals (needed for goal lines on charts)
        goals = (try? await goalRepository.fetch(dataSource: .wiiFit)) ?? []

        // Load cached measurements
        if let cachedMeasurements = try? await dataSource.fetchCachedMeasurements(from: startDate, to: endDate), !cachedMeasurements.isEmpty {
            measurements = cachedMeasurements
            rebuildInsight()
            fetchStatus = .success
        }
    }

    public func loadData() async {
        errorMessage = nil
        fetchStatus = .loading

        // Configure from saved settings if available
        if let settings = WiiFitDataSource.loadSettingsFromUserDefaults() {
            try? await dataSource.configure(settings: settings)
        }

        guard await dataSource.isConfigured() else {
            errorMessage = "Configure Wii Fit connection in Settings"
            fetchStatus = .error
            return
        }

        let endDate = Date()
        let startDate = TimeRange.all.startDate(from: endDate)

        // Load goals first (needed for goal lines on charts)
        goals = (try? await goalRepository.fetch(dataSource: .wiiFit)) ?? []

        // Display cached data immediately
        if let cachedMeasurements = try? await dataSource.fetchCachedMeasurements(from: startDate, to: endDate), !cachedMeasurements.isEmpty {
            measurements = cachedMeasurements
            rebuildInsight()
        }

        // Fetch fresh data from cache (sync happens manually from Settings)
        do {
            measurements = try await dataSource.fetchMeasurements(from: startDate, to: endDate)
            rebuildInsight()
            fetchStatus = .success
        } catch is CancellationError {
            // Task was cancelled - don't change status (another fetch may be in progress)
        } catch {
            // Show error status even if we have cached data
            fetchStatus = .error
            if measurements.isEmpty {
                errorMessage = "No Wii Fit data available. Sync from Settings."
            }
        }
    }
}
