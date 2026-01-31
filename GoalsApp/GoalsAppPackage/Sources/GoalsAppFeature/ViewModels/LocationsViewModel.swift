import SwiftUI
import CoreLocation
import WidgetKit
import GoalsDomain
import GoalsData

/// ViewModel for the Locations section, managing location tracking state
@MainActor
@Observable
public final class LocationsViewModel: Sendable {
    // MARK: - Published State

    /// All active (non-archived) location definitions
    public private(set) var locations: [LocationDefinition] = []

    /// Currently active session, if any - forwards to tracking service
    public var activeSession: LocationSession? {
        locationTrackingService.activeSession
    }

    /// Today's sessions by location ID
    public private(set) var todaySessionsByLocation: [UUID: [LocationSession]] = [:]

    /// Current authorization status - forwards to tracking service
    public var authorizationStatus: CLAuthorizationStatus {
        locationTrackingService.authorizationStatus
    }

    /// Loading state
    public private(set) var isLoading = false

    /// Error message, if any
    public private(set) var errorMessage: String?

    /// Timer tick for live duration updates
    public private(set) var timerTick: Date = Date()

    // MARK: - Dependencies

    private let locationRepository: LocationRepositoryProtocol
    private let locationTrackingService: LocationTrackingService

    // MARK: - Timer & Observation

    private var timerTask: Task<Void, Never>?
    private var observationTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(
        locationRepository: LocationRepositoryProtocol,
        locationTrackingService: LocationTrackingService
    ) {
        self.locationRepository = locationRepository
        self.locationTrackingService = locationTrackingService
    }

    // MARK: - Public Methods

    /// Load all data (locations, active session, today's sessions)
    public func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load locations and today's sessions in parallel
            async let locationsResult = locationRepository.fetchActiveLocations()
            async let todayResult = fetchTodaySessions()

            locations = try await locationsResult
            todaySessionsByLocation = try await todayResult

            // Start observing tracking service for changes
            startObservingTrackingService()

            // Start timer if there's an active session
            if activeSession != nil {
                startTimer()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Request location permission
    public func requestLocationPermission() {
        locationTrackingService.requestAuthorization()
    }

    /// Start tracking locations
    public func startTracking() async {
        do {
            try await locationTrackingService.startTracking()
            // activeSession is now a computed property, no need to set it
            if activeSession != nil {
                startTimer()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Manually toggle a location session
    public func toggleLocation(_ location: LocationDefinition) async {
        do {
            if let active = activeSession, active.locationId == location.id {
                // End the current session
                try await locationTrackingService.endActiveSession()
                // activeSession is computed, timer will stop via observation
            } else {
                // Start session at this location (will end any other active session)
                try await locationTrackingService.startSession(locationId: location.id)
                // activeSession is computed, timer will start via observation
            }

            // Refresh today's sessions
            todaySessionsByLocation = try await fetchTodaySessions()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Create a new location
    public func createLocation(_ location: LocationDefinition) async {
        do {
            let created = try await locationRepository.createLocation(location)
            locations.append(created)
            locations.sort { $0.sortOrder < $1.sortOrder }

            // Refresh monitored locations
            try await locationTrackingService.refreshMonitoredLocations()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Update an existing location
    public func updateLocation(_ location: LocationDefinition) async {
        do {
            let updated = try await locationRepository.updateLocation(location)
            if let index = locations.firstIndex(where: { $0.id == updated.id }) {
                locations[index] = updated
            }

            // Refresh monitored locations
            try await locationTrackingService.refreshMonitoredLocations()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Delete a location
    public func deleteLocation(_ location: LocationDefinition) async {
        do {
            try await locationRepository.deleteLocation(id: location.id)
            locations.removeAll { $0.id == location.id }

            // Refresh monitored locations
            try await locationTrackingService.refreshMonitoredLocations()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Get today's total duration for a specific location
    public func todayDuration(for locationId: UUID) -> TimeInterval {
        let sessions = todaySessionsByLocation[locationId] ?? []
        return sessions.totalDuration
    }

    /// Get the currently active location definition, if any
    public var activeLocation: LocationDefinition? {
        guard let session = activeSession else { return nil }
        return locations.first { $0.id == session.locationId }
    }

    // MARK: - Private Methods

    private func fetchTodaySessions() async throws -> [UUID: [LocationSession]] {
        let sessions = try await locationRepository.fetchSessions(for: Date())

        var grouped: [UUID: [LocationSession]] = [:]
        for session in sessions {
            grouped[session.locationId, default: []].append(session)
        }
        return grouped
    }

    private func startTimer() {
        stopTimer()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self?.timerTick = Date()
                }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func startObservingTrackingService() {
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            var previousSessionId: UUID? = self?.activeSession?.id

            while !Task.isCancelled {
                // Check every second for session changes
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }

                await MainActor.run { [weak self] in
                    guard let self = self else { return }

                    let currentSessionId = self.activeSession?.id

                    // Detect session change
                    if currentSessionId != previousSessionId {
                        previousSessionId = currentSessionId

                        if currentSessionId != nil {
                            // Session started - start timer
                            self.startTimer()
                        } else {
                            // Session ended - stop timer
                            self.stopTimer()
                        }

                        // Refresh today's sessions when session changes
                        Task {
                            self.todaySessionsByLocation = (try? await self.fetchTodaySessions()) ?? [:]
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    }
                }
            }
        }
    }
}
