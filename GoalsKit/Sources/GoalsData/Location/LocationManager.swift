import CoreLocation
import Foundation

// MARK: - Debug Helpers

extension CLAuthorizationStatus {
    var debugDescription: String {
        switch self {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown(\(rawValue))"
        }
    }
}

/// Event type for region monitoring
public enum RegionEventType: Sendable {
    case entered
    case exited
}

/// Represents a region entry/exit event
public struct RegionEvent: Sendable {
    public let locationId: UUID
    public let type: RegionEventType
    public let timestamp: Date

    public init(locationId: UUID, type: RegionEventType, timestamp: Date = Date()) {
        self.locationId = locationId
        self.type = type
        self.timestamp = timestamp
    }
}

/// Wrapper around CLLocationManager for handling location services
/// Uses an actor for thread-safe state management
public final class LocationManager: NSObject, @unchecked Sendable {
    // MARK: - Configuration

    /// Interval for high-frequency tracking during active sessions (seconds)
    public static let highFrequencyInterval: TimeInterval = 10

    /// Distance filter for location updates (meters)
    public static let distanceFilter: CLLocationDistance = 10

    /// Enable debug logging (set to false for production)
    public static nonisolated(unsafe) var debugLogging = true

    private func log(_ message: String) {
        guard Self.debugLogging else { return }
        print("[LocationManager] \(message)")
    }

    // MARK: - Callbacks

    /// Called when authorization status changes
    public var onAuthorizationChange: (@Sendable (CLAuthorizationStatus) -> Void)?

    /// Called when a region event occurs
    public var onRegionEvent: (@Sendable (RegionEvent) -> Void)?

    /// Called when location updates are received during high-frequency tracking
    public var onLocationUpdate: (@Sendable (CLLocation) -> Void)?

    /// Called when region state is determined (inside/outside)
    public var onRegionState: (@Sendable (UUID, CLRegionState) -> Void)?

    // MARK: - State

    private let locationManager: CLLocationManager
    private var isHighFrequencyTracking = false
    private var monitoredLocationIds: [String: UUID] = [:] // region identifier -> location UUID
    private let lock = NSLock()

    // MARK: - Initialization

    public override init() {
        self.locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = Self.distanceFilter
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    // MARK: - Authorization

    /// Current authorization status
    public var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    /// Request "always" authorization for background location access
    public func requestAlwaysAuthorization() {
        log("Requesting 'always' authorization")
        locationManager.requestAlwaysAuthorization()
    }

    /// Request "when in use" authorization
    public func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: - Region Monitoring (Geofencing)

    /// Start monitoring a location for entry/exit
    public func startMonitoring(locationId: UUID, latitude: Double, longitude: Double, radius: Double, name: String) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = CLCircularRegion(
            center: coordinate,
            radius: min(radius, locationManager.maximumRegionMonitoringDistance),
            identifier: locationId.uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true

        lock.withLock {
            monitoredLocationIds[locationId.uuidString] = locationId
        }

        locationManager.startMonitoring(for: region)
        log("Started monitoring region '\(name)' at (\(latitude), \(longitude)) with radius \(radius)m")
    }

    /// Stop monitoring a specific location
    public func stopMonitoring(locationId: UUID) {
        let identifier = locationId.uuidString

        lock.lock()
        monitoredLocationIds.removeValue(forKey: identifier)
        lock.unlock()

        for region in locationManager.monitoredRegions {
            if region.identifier == identifier {
                locationManager.stopMonitoring(for: region)
                break
            }
        }
    }

    /// Stop monitoring all locations
    public func stopAllMonitoring() {
        lock.lock()
        monitoredLocationIds.removeAll()
        lock.unlock()

        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
    }

    /// Get currently monitored location IDs
    public var monitoredLocations: [UUID] {
        lock.withLock {
            Array(monitoredLocationIds.values)
        }
    }

    /// Request state for all monitored regions
    /// Triggers onRegionState callback for each region
    public func requestStateForAllRegions() {
        log("Requesting state for all monitored regions")
        for region in locationManager.monitoredRegions {
            locationManager.requestState(for: region)
        }
    }

    // MARK: - High-Frequency Tracking

    /// Start high-frequency location tracking (every 10 seconds)
    public func startHighFrequencyTracking() {
        guard !isHighFrequencyTracking else { return }
        isHighFrequencyTracking = true
        locationManager.startUpdatingLocation()
        log("Started high-frequency location tracking")
    }

    /// Stop high-frequency location tracking
    public func stopHighFrequencyTracking() {
        guard isHighFrequencyTracking else { return }
        isHighFrequencyTracking = false
        locationManager.stopUpdatingLocation()
        log("Stopped high-frequency location tracking")
    }

    /// Whether high-frequency tracking is active
    public var isTracking: Bool {
        isHighFrequencyTracking
    }

    // MARK: - Current Location

    /// Request a single location update
    public func requestLocation() {
        locationManager.requestLocation()
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        log("Authorization changed to: \(manager.authorizationStatus.debugDescription)")
        onAuthorizationChange?(manager.authorizationStatus)
    }

    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        log("⬇️ ENTERED region: \(circularRegion.identifier)")

        let locationId: UUID? = lock.withLock {
            monitoredLocationIds[circularRegion.identifier]
        }

        if let locationId = locationId {
            let event = RegionEvent(locationId: locationId, type: .entered)
            onRegionEvent?(event)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        log("⬆️ EXITED region: \(circularRegion.identifier)")

        let locationId: UUID? = lock.withLock {
            monitoredLocationIds[circularRegion.identifier]
        }

        if let locationId = locationId {
            let event = RegionEvent(locationId: locationId, type: .exited)
            onRegionEvent?(event)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isHighFrequencyTracking else { return }

        // Only report the most recent location
        if let location = locations.last {
            log("📍 Location update: (\(String(format: "%.4f", location.coordinate.latitude)), \(String(format: "%.4f", location.coordinate.longitude))) ±\(Int(location.horizontalAccuracy))m")
            onLocationUpdate?(location)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Log error but don't crash - location services may temporarily fail
        print("LocationManager error: \(error.localizedDescription)")
    }

    public func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        // Log error but continue - individual region monitoring may fail
        print("Region monitoring failed: \(region?.identifier ?? "unknown") - \(error.localizedDescription)")
    }

    public func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }

        let stateDescription: String
        switch state {
        case .inside: stateDescription = "inside"
        case .outside: stateDescription = "outside"
        case .unknown: stateDescription = "unknown"
        @unknown default: stateDescription = "unknown(\(state.rawValue))"
        }
        log("📍 Region state for '\(circularRegion.identifier)': \(stateDescription)")

        let locationId: UUID? = lock.withLock {
            monitoredLocationIds[circularRegion.identifier]
        }

        if let locationId = locationId {
            onRegionState?(locationId, state)
        }
    }
}
