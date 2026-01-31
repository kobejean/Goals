import CoreLocation
import Foundation
import GoalsDomain

/// Orchestrates location tracking, connecting LocationManager with the repository
@MainActor
@Observable
public final class LocationTrackingService: Sendable {
    // MARK: - Published State

    /// The currently active location session
    public private(set) var activeSession: LocationSession?

    /// Current authorization status
    public private(set) var authorizationStatus: CLAuthorizationStatus

    /// Whether high-frequency tracking is active
    public private(set) var isTracking: Bool = false

    // MARK: - Dependencies

    private let locationManager: LocationManager
    private let locationRepository: LocationRepositoryProtocol

    // MARK: - Entry Buffer

    /// Buffer for batching location entries before persisting
    private var pendingEntries: [LocationEntry] = []
    private let batchSize = 6 // Flush every ~60 seconds worth of entries

    // MARK: - Debug Logging

    private func log(_ message: String) {
        guard LocationManager.debugLogging else { return }
        print("[LocationTrackingService] \(message)")
    }

    // MARK: - Initialization

    public init(
        locationManager: LocationManager,
        locationRepository: LocationRepositoryProtocol
    ) {
        self.locationManager = locationManager
        self.locationRepository = locationRepository
        self.authorizationStatus = locationManager.authorizationStatus

        setupCallbacks()
    }

    // MARK: - Setup

    private func setupCallbacks() {
        locationManager.onAuthorizationChange = { [weak self] status in
            Task { @MainActor [weak self] in
                self?.authorizationStatus = status
            }
        }

        locationManager.onRegionEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                await self?.handleRegionEvent(event)
            }
        }

        locationManager.onLocationUpdate = { [weak self] location in
            Task { @MainActor [weak self] in
                await self?.handleLocationUpdate(location)
            }
        }

        locationManager.onRegionState = { [weak self] locationId, state in
            Task { @MainActor [weak self] in
                await self?.handleRegionState(locationId: locationId, state: state)
            }
        }
    }

    // MARK: - Public Control

    /// Request location authorization
    public func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    /// Start tracking - loads locations and begins monitoring
    public func startTracking() async throws {
        log("Starting tracking...")
        // Load active locations and start monitoring them
        let locations = try await locationRepository.fetchActiveLocations()
        log("Found \(locations.count) active locations to monitor")
        for location in locations {
            locationManager.startMonitoring(
                locationId: location.id,
                latitude: location.latitude,
                longitude: location.longitude,
                radius: location.radiusMeters,
                name: location.name
            )
        }

        // Check for existing active session
        activeSession = try await locationRepository.fetchActiveSession()

        // If there's an active session, start high-frequency tracking
        if let session = activeSession {
            log("Resuming active session: \(session.id)")
            locationManager.startHighFrequencyTracking()
            isTracking = true
        } else {
            log("No active session - waiting for region events")
        }
    }

    /// Stop all tracking
    public func stopTracking() {
        locationManager.stopAllMonitoring()
        locationManager.stopHighFrequencyTracking()
        isTracking = false
    }

    /// Refresh monitored locations (call after adding/removing locations)
    public func refreshMonitoredLocations() async throws {
        locationManager.stopAllMonitoring()
        let locations = try await locationRepository.fetchActiveLocations()
        for location in locations {
            locationManager.startMonitoring(
                locationId: location.id,
                latitude: location.latitude,
                longitude: location.longitude,
                radius: location.radiusMeters,
                name: location.name
            )
        }
    }

    /// Manually start a session (for manual override)
    public func startSession(locationId: UUID) async throws {
        log("🟢 Manually starting session for location: \(locationId)")
        let session = try await locationRepository.startSession(locationId: locationId, at: Date())
        activeSession = session
        locationManager.startHighFrequencyTracking()
        isTracking = true
        log("Session started: \(session.id)")
    }

    /// Manually end the active session
    public func endActiveSession() async throws {
        guard let session = activeSession else {
            log("No active session to end")
            return
        }

        log("🔴 Manually ending session: \(session.id)")
        // Flush any pending entries
        await flushPendingEntries()

        _ = try await locationRepository.endSession(id: session.id, at: Date())
        activeSession = nil
        locationManager.stopHighFrequencyTracking()
        isTracking = false
        log("Session ended")
    }

    // MARK: - Event Handlers

    private func handleRegionEvent(_ event: RegionEvent) async {
        switch event.type {
        case .entered:
            await handleRegionEnter(locationId: event.locationId, at: event.timestamp)
        case .exited:
            await handleRegionExit(locationId: event.locationId, at: event.timestamp)
        }
    }

    private func handleRegionEnter(locationId: UUID, at timestamp: Date) async {
        // If already tracking this location, ignore
        if let current = activeSession, current.locationId == locationId {
            log("Ignoring region enter - already tracking this location")
            return
        }

        // If tracking a different location, end it first (automatic switch)
        if let current = activeSession {
            log("🔄 AUTO: Switching from location \(current.locationId) to \(locationId)")
            await flushPendingEntries()
            do {
                _ = try await locationRepository.endSession(id: current.id, at: timestamp)
            } catch {
                log("❌ Failed to end previous session during switch: \(error)")
            }
        }

        log("🟢 AUTO: Region entered, starting session for location: \(locationId)")
        do {
            let session = try await locationRepository.startSession(locationId: locationId, at: timestamp)
            activeSession = session
            locationManager.startHighFrequencyTracking()
            isTracking = true
            log("Session auto-started: \(session.id)")
        } catch {
            log("❌ Failed to start location session: \(error)")
        }
    }

    private func handleRegionExit(locationId: UUID, at timestamp: Date) async {
        // Only end if the active session is for this location
        guard let session = activeSession, session.locationId == locationId else {
            log("Ignoring region exit - no matching active session")
            return
        }

        log("🔴 AUTO: Region exited, ending session: \(session.id)")
        do {
            // Flush any pending entries
            await flushPendingEntries()

            _ = try await locationRepository.endSession(id: session.id, at: timestamp)
            activeSession = nil
            locationManager.stopHighFrequencyTracking()
            isTracking = false
            log("Session auto-ended")

            // Check if we're inside another monitored region
            // (handles overlapping regions or quick transitions)
            log("🔍 Checking for other active regions after exit...")
            locationManager.requestStateForAllRegions()
        } catch {
            log("❌ Failed to end location session: \(error)")
        }
    }

    private func handleRegionState(locationId: UUID, state: CLRegionState) async {
        switch state {
        case .inside:
            // If we're inside a region and don't have an active session, start one
            if activeSession == nil {
                log("🔍 Detected inside region \(locationId) with no active session - starting")
                await handleRegionEnter(locationId: locationId, at: Date())
            } else if activeSession?.locationId != locationId {
                // We're inside a different region than the active session
                // This can happen with overlapping regions
                log("🔍 Detected inside region \(locationId) but tracking \(activeSession!.locationId)")
            }
        case .outside:
            log("🔍 Confirmed outside region \(locationId)")
        case .unknown:
            log("🔍 Unknown state for region \(locationId)")
        @unknown default:
            break
        }
    }

    private func handleLocationUpdate(_ location: CLLocation) async {
        guard let session = activeSession else { return }

        let entry = LocationEntry(
            sessionId: session.id,
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracy: location.horizontalAccuracy,
            altitude: location.altitude,
            verticalAccuracy: location.verticalAccuracy >= 0 ? location.verticalAccuracy : nil,
            speed: location.speed >= 0 ? location.speed : nil,
            course: location.course >= 0 ? location.course : nil
        )

        pendingEntries.append(entry)

        // Flush if buffer is full
        if pendingEntries.count >= batchSize {
            await flushPendingEntries()
        }
    }

    private func flushPendingEntries() async {
        guard !pendingEntries.isEmpty else { return }

        let entriesToFlush = pendingEntries
        pendingEntries = []

        log("💾 Flushing \(entriesToFlush.count) pending location entries to database")
        do {
            try await locationRepository.addEntries(entriesToFlush)
        } catch {
            log("❌ Failed to save location entries: \(error)")
        }
    }

    // MARK: - Maintenance

    /// Prune old location entries (call periodically)
    public func pruneOldEntries(olderThan days: Int = 30) async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        try await locationRepository.pruneOldEntries(olderThan: cutoffDate)
    }
}
