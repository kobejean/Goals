import Foundation

/// A single session with embedded location info for caching
/// Contains all location metadata needed for widget display without requiring LocationDefinition access
public struct CachedLocationSession: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let sessionId: UUID
    public let locationId: UUID
    public let locationName: String
    public let locationColorRaw: String  // LocationColor.rawValue
    public let startDate: Date
    public let endDate: Date?  // nil for active sessions

    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        locationId: UUID,
        locationName: String,
        locationColorRaw: String,
        startDate: Date,
        endDate: Date?
    ) {
        self.id = id
        self.sessionId = sessionId
        self.locationId = locationId
        self.locationName = locationName
        self.locationColorRaw = locationColorRaw
        self.startDate = startDate
        self.endDate = endDate
    }

    /// Create from a LocationSession and LocationDefinition
    public init(session: LocationSession, location: LocationDefinition) {
        self.id = UUID()
        self.sessionId = session.id
        self.locationId = location.id
        self.locationName = location.name
        self.locationColorRaw = location.color.rawValue
        self.startDate = session.startDate
        self.endDate = session.endDate
    }

    /// Duration of the session in seconds
    public var duration: TimeInterval {
        let end = endDate ?? Date()
        return end.timeIntervalSince(startDate)
    }

    /// Duration at a specific reference date (for live updates)
    public func duration(at referenceDate: Date) -> TimeInterval {
        let end = endDate ?? referenceDate
        return end.timeIntervalSince(startDate)
    }

    /// Whether this session is currently active (no end date)
    public var isActive: Bool {
        endDate == nil
    }

    /// The location color parsed from raw value
    public var locationColor: LocationColor {
        LocationColor(rawValue: locationColorRaw) ?? .blue
    }
}

/// Daily summary of location sessions (cacheable for widget access)
public struct LocationDailySummary: Codable, Sendable, Equatable, Identifiable {
    public var id: Date { date }
    public let date: Date
    public let sessions: [CachedLocationSession]

    public init(date: Date, sessions: [CachedLocationSession]) {
        self.date = date
        self.sessions = sessions
    }

    /// Create from sessions and locations (converts to cached format)
    public init(date: Date, sessions: [LocationSession], locations: [LocationDefinition]) {
        self.date = date
        self.sessions = sessions.compactMap { session in
            guard let location = locations.first(where: { $0.id == session.locationId }) else { return nil }
            return CachedLocationSession(session: session, location: location)
        }
    }

    /// Total tracked duration for the day in seconds
    public var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }

    /// Total tracked duration at a specific reference date (for live updates)
    public func totalDuration(at referenceDate: Date) -> TimeInterval {
        sessions.reduce(0) { $0 + $1.duration(at: referenceDate) }
    }

    /// Sessions grouped by location ID
    public var sessionsByLocation: [UUID: [CachedLocationSession]] {
        Dictionary(grouping: sessions) { $0.locationId }
    }
}

// MARK: - CachedLocationSession Collection Helpers

public extension Array where Element == CachedLocationSession {
    /// Total duration of all sessions in seconds
    var totalDuration: TimeInterval {
        reduce(0) { $0 + $1.duration }
    }

    /// Total duration at a specific reference date (for live updates)
    func totalDuration(at referenceDate: Date) -> TimeInterval {
        reduce(0) { $0 + $1.duration(at: referenceDate) }
    }
}

// MARK: - CacheableRecord Conformance

extension LocationDailySummary: CacheableRecord {
    public static var dataSource: DataSourceType { .locations }
    public static var recordType: String { "daily" }

    /// Shared date formatter for cache key generation (thread-safe)
    private static let cacheKeyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    public var cacheKey: String {
        "locations:daily:\(Self.cacheKeyDateFormatter.string(from: date))"
    }

    public var recordDate: Date { date }
}
