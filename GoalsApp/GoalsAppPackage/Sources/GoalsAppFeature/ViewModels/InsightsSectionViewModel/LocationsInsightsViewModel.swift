import SwiftUI
import GoalsDomain
import GoalsCore
import GoalsData
import GoalsWidgetShared

/// ViewModel for Locations insights section
@MainActor @Observable
public final class LocationsInsightsViewModel: InsightsSectionViewModel {
    // MARK: - Static Properties

    public let title = "Locations"
    public let systemImage = "location.fill"
    public let color: Color = .cyan
    public let requiresThrottle = false  // Local SwiftData, no network calls

    // MARK: - Published State

    public private(set) var locations: [LocationDefinition] = []
    public private(set) var sessions: [LocationSession] = []
    public private(set) var goals: [Goal] = []
    public private(set) var todayPath: [PathEntry] = []
    public private(set) var errorMessage: String?
    public private(set) var fetchStatus: InsightFetchStatus = .idle

    // MARK: - Dependencies

    private let locationRepository: LocationRepositoryProtocol
    private let goalRepository: GoalRepositoryProtocol
    private let locationCachingService: LocationCachingService?

    // MARK: - Timer State

    /// Reference date for computing active session durations
    public private(set) var referenceDate: Date = Date()

    /// Timer task for live updates
    private var timerTask: Task<Void, Never>?

    /// Whether there's currently an active session
    public var hasActiveSession: Bool {
        sessions.contains { $0.isActive }
    }

    // MARK: - Initialization

    public init(
        locationRepository: LocationRepositoryProtocol,
        goalRepository: GoalRepositoryProtocol,
        locationCachingService: LocationCachingService? = nil
    ) {
        self.locationRepository = locationRepository
        self.goalRepository = goalRepository
        self.locationCachingService = locationCachingService
    }

    // MARK: - Computed Properties

    /// Daily summaries grouped by date
    public var dailySummaries: [LocationDailySummary] {
        let calendar = Calendar.current
        var summariesByDate: [Date: [LocationSession]] = [:]

        for session in sessions {
            let day = calendar.startOfDay(for: session.startDate)
            summariesByDate[day, default: []].append(session)
        }

        return summariesByDate.map { date, daySessions in
            LocationDailySummary(date: date, sessions: daySessions, locations: locations)
        }.sorted { $0.date < $1.date }
    }

    /// Today's total tracked time in hours
    public var todayTotalHours: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        let todaySessions = sessions.filter { calendar.startOfDay(for: $0.startDate) == today }
        return todaySessions.totalDuration(at: referenceDate) / 3600.0
    }

    /// Weekly average tracked hours
    public var weeklyAverageHours: Double? {
        let recentData = dailySummaries.suffix(7)
        guard !recentData.isEmpty else { return nil }
        let total = recentData.reduce(0.0) { $0 + $1.totalDuration }
        return (total / Double(recentData.count)) / 3600.0
    }

    /// Tracking trend (percentage change from first half to second half of data)
    public var trackingTrend: Double? {
        dailySummaries.halfTrendPercentage { $0.totalDuration / 3600.0 }
    }

    // MARK: - Insight Data (delegated to provider)

    /// Insight data built from current daily summaries
    public var insight: InsightData {
        LocationInsightProvider.build(from: dailySummaries, goals: goals, referenceDate: referenceDate)
    }

    /// Get the goal target for a specific metric
    public func goalTarget(for metricKey: String) -> Double? {
        goals.targetValue(for: metricKey)
    }

    // MARK: - Filtered Data

    /// Filter sessions by time range
    public func filteredSessions(for timeRange: TimeRange) -> [LocationSession] {
        let cutoffDate = timeRange.startDate(from: Date())
        let filtered = sessions.filter { $0.startDate >= cutoffDate }

        // For "all" time range, limit to most recent 500 entries
        if timeRange == .all && filtered.count > 500 {
            return Array(filtered.suffix(500))
        }
        return filtered
    }

    /// Filter daily summaries by time range
    public func filteredDailySummaries(for timeRange: TimeRange) -> [LocationDailySummary] {
        let cutoffDate = timeRange.startDate(from: Date())
        let filtered = dailySummaries.filter { $0.date >= cutoffDate }

        // For "all" time range, limit to 90 days for chart performance
        if timeRange == .all && filtered.count > 90 {
            return Array(filtered.suffix(90))
        }
        return filtered
    }

    /// Get duration range data points for a time range (limited to 30 for readability)
    public func filteredRangeData(for timeRange: TimeRange) -> [DurationRangeDataPoint] {
        let filtered = filteredDailySummaries(for: timeRange)
        let dataToShow = filtered.count > 30 ? Array(filtered.suffix(30)) : filtered
        return dataToShow.map { $0.toDurationRangeDataPoint(referenceDate: referenceDate) }
    }

    // MARK: - Data Loading

    public func loadCachedData() async {
        let endDate = Date()
        let startDate = TimeRange.all.startDate(from: endDate)

        do {
            // Load locations and sessions in parallel (from local SwiftData store)
            async let locationsResult = locationRepository.fetchActiveLocations()
            async let sessionsResult = locationRepository.fetchSessions(from: startDate, to: endDate)
            async let goalsResult = goalRepository.fetch(dataSource: .locations)

            locations = try await locationsResult
            sessions = try await sessionsResult
            goals = try await goalsResult

            // Update reference date after loading
            referenceDate = Date()

            if !sessions.isEmpty {
                fetchStatus = .success
            }
        } catch {
            // Silently fail for cached data loading
        }
    }

    public func loadData() async {
        errorMessage = nil
        fetchStatus = .loading

        let endDate = Date()
        let startDate = TimeRange.all.startDate(from: endDate)

        do {
            // Load locations, sessions, goals, and today's path in parallel
            async let locationsResult = locationRepository.fetchActiveLocations()
            async let sessionsResult = locationRepository.fetchSessions(from: startDate, to: endDate)
            async let goalsResult = goalRepository.fetch(dataSource: .locations)
            async let pathResult = locationRepository.fetchPathEntries(for: Date())

            locations = try await locationsResult
            sessions = try await sessionsResult
            goals = try await goalsResult
            todayPath = try await pathResult

            // Update reference date after loading
            referenceDate = Date()

            // Sync to cache for widget access
            try? await locationCachingService?.syncToCache(from: startDate, to: endDate)
            fetchStatus = .success
        } catch {
            errorMessage = "Failed to load location data: \(error.localizedDescription)"
            fetchStatus = .error
        }
    }

    /// Reload today's path data (for refresh)
    public func reloadTodayPath() async {
        do {
            todayPath = try await locationRepository.fetchPathEntries(for: Date())
        } catch {
            // Silent failure for path reload
        }
    }

    // MARK: - Formatting Helpers

    public func formatHours(_ hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h == 0 && m == 0 {
            return "0m"
        }
        if h == 0 {
            return "\(m)m"
        }
        if m == 0 {
            return "\(h)h"
        }
        return "\(h)h \(m)m"
    }

    public func formatDuration(_ seconds: TimeInterval) -> String {
        formatHours(seconds / 3600.0)
    }

    // MARK: - Timer Management

    /// Start timer for live updates when active session exists
    public func startLiveUpdates() {
        guard hasActiveSession else { return }
        stopLiveUpdates()

        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self?.referenceDate = Date()
                }
            }
        }
    }

    /// Stop timer for live updates
    public func stopLiveUpdates() {
        timerTask?.cancel()
        timerTask = nil
    }
}

// MARK: - Array Extension for Trend Calculation

extension Array where Element == LocationDailySummary {
    /// Calculate half trend percentage (change from first half to second half)
    func halfTrendPercentage(_ value: (Element) -> Double) -> Double? {
        guard count >= 4 else { return nil }

        let midpoint = count / 2
        let firstHalf = self[0..<midpoint]
        let secondHalf = self[midpoint...]

        let firstAverage = firstHalf.reduce(0.0) { $0 + value($1) } / Double(firstHalf.count)
        let secondAverage = secondHalf.reduce(0.0) { $0 + value($1) } / Double(secondHalf.count)

        guard firstAverage > 0 else { return nil }
        return ((secondAverage - firstAverage) / firstAverage) * 100
    }
}
