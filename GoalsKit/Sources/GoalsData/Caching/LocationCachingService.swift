import Foundation
import SwiftData
import GoalsDomain

/// Service to sync location data from SwiftData to shared cache for widget access
public actor LocationCachingService {
    private let locationRepository: LocationRepositoryProtocol
    private let modelContainer: ModelContainer

    public init(
        locationRepository: LocationRepositoryProtocol,
        modelContainer: ModelContainer
    ) {
        self.locationRepository = locationRepository
        self.modelContainer = modelContainer
    }

    /// Sync daily summaries for a date range to cache
    /// - Parameters:
    ///   - startDate: Start of date range
    ///   - endDate: End of date range
    public func syncToCache(from startDate: Date, to endDate: Date) async throws {
        // Fetch all locations and sessions for the date range
        let locations = try await locationRepository.fetchActiveLocations()
        let sessions = try await locationRepository.fetchSessions(from: startDate, to: endDate)

        // Group sessions by day and build summaries
        let dailySummaries = buildDailySummaries(sessions: sessions, locations: locations)

        // Store all summaries in the cache using the model's static method
        try LocationDailySummaryModel.store(dailySummaries, in: modelContainer)
    }

    /// Sync today's summary to cache (called after session start/stop)
    public func syncTodayToCache() async throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()

        try await syncToCache(from: today, to: tomorrow)
    }

    /// Build daily summaries from sessions and locations
    private func buildDailySummaries(
        sessions: [LocationSession],
        locations: [LocationDefinition]
    ) -> [LocationDailySummary] {
        let calendar = Calendar.current

        // Group sessions by day
        var sessionsByDay: [Date: [LocationSession]] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.startDate)
            sessionsByDay[day, default: []].append(session)
        }

        // Create summaries for each day that has sessions
        return sessionsByDay.map { day, daySessions in
            LocationDailySummary(date: day, sessions: daySessions, locations: locations)
        }.sorted { $0.date < $1.date }
    }
}
