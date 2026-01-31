import Foundation
import SwiftData
import GoalsDomain

/// Data source implementation for Wii Fit body measurements and activities.
/// Uses TCP connection to sync data from a Wii running the homebrew app,
/// with local caching via SwiftData.
public actor WiiFitDataSource: WiiFitDataSourceProtocol, CacheableDataSource {
    public let dataSourceType: DataSourceType = .wiiFit

    public nonisolated var availableMetrics: [MetricInfo] {
        [
            MetricInfo(key: "weight", name: "Weight", unit: "kg", icon: "scalemass.fill", direction: .decrease),
            MetricInfo(key: "bmi", name: "BMI", unit: "", icon: "figure.stand", direction: .decrease),
            MetricInfo(key: "balance", name: "Balance", unit: "%", icon: "figure.stand.line.dotted.figure.stand"),
            MetricInfo(key: "calories", name: "Calories", unit: "kcal", icon: "flame.fill"),
            MetricInfo(key: "duration", name: "Exercise Time", unit: "min", icon: "timer"),
        ]
    }

    public nonisolated func metricValue(for key: String, from stats: Any) -> Double? {
        if let measurement = stats as? WiiFitMeasurement {
            switch key {
            case "weight": return measurement.weightKg
            case "bmi": return measurement.bmi
            case "balance": return measurement.balancePercent
            default: return nil
            }
        } else if let activity = stats as? WiiFitActivity {
            switch key {
            case "calories": return Double(activity.caloriesBurned)
            case "duration": return Double(activity.durationMinutes)
            default: return nil
            }
        }
        return nil
    }

    // MARK: - CacheableDataSource

    public let modelContainer: ModelContainer?

    // MARK: - Configuration

    private var ipAddress: String?
    private var selectedProfile: String?
    private var lastSyncProfiles: [WiiFitProfileInfo] = []
    private let wiiConnection: WiiConnection

    /// Creates a WiiFitDataSource without caching (for testing).
    public init() {
        self.modelContainer = nil
        self.wiiConnection = WiiConnection()
    }

    /// Creates a WiiFitDataSource with caching enabled (for production).
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.wiiConnection = WiiConnection()
    }

    public func isConfigured() async -> Bool {
        ipAddress != nil && !ipAddress!.isEmpty
    }

    public func configure(settings: DataSourceSettings) async throws {
        guard settings.dataSourceType == .wiiFit else {
            throw DataSourceError.invalidConfiguration
        }

        guard let ip = settings.options["ipAddress"], !ip.isEmpty else {
            throw DataSourceError.missingCredentials
        }

        self.ipAddress = ip
        self.selectedProfile = settings.options["selectedProfile"]
    }

    public func clearConfiguration() async throws {
        ipAddress = nil
        selectedProfile = nil
        lastSyncProfiles = []
    }

    public func fetchLatestMetricValue(for metricKey: String, taskId: UUID?) async throws -> Double? {
        // Try to get from cached measurements
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate) ?? endDate

        if ["weight", "bmi", "balance"].contains(metricKey) {
            let measurements = try await fetchCachedMeasurements(from: startDate, to: endDate)
            guard let latest = measurements.latest else { return nil }
            return metricValue(for: metricKey, from: latest)
        } else if ["calories", "duration"].contains(metricKey) {
            // Sum today's activities
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

            let activities = try await fetchCachedActivities(from: today, to: tomorrow)
            switch metricKey {
            case "calories": return Double(activities.totalCalories)
            case "duration": return Double(activities.totalDurationMinutes)
            default: return nil
            }
        }

        return nil
    }

    // MARK: - WiiFitDataSourceProtocol

    public func sync() async throws -> WiiFitSyncResult {
        guard let ipAddress = ipAddress, !ipAddress.isEmpty else {
            throw DataSourceError.notConfigured
        }
        let result = try await wiiConnection.sync(ipAddress: ipAddress)

        // Filter by selected profile if set
        let filteredMeasurements: [WiiFitMeasurement]
        let filteredActivities: [WiiFitActivity]

        if let profile = selectedProfile, !profile.isEmpty {
            filteredMeasurements = result.measurements.filter { $0.profileName == profile }
            filteredActivities = result.activities.filter { $0.profileName == profile }
        } else {
            filteredMeasurements = result.measurements
            filteredActivities = result.activities
        }

        // Cache results
        if let container = modelContainer {
            try WiiFitMeasurementModel.store(filteredMeasurements, in: container)
            try WiiFitActivityModel.store(filteredActivities, in: container)
        }

        // Update last sync profiles
        lastSyncProfiles = result.profilesFound

        return WiiFitSyncResult(
            measurements: filteredMeasurements,
            activities: filteredActivities,
            profilesFound: result.profilesFound
        )
    }

    public func fetchMeasurements(from startDate: Date, to endDate: Date) async throws -> [WiiFitMeasurement] {
        // Return cached data - actual sync happens via sync() method
        return try await fetchCachedMeasurements(from: startDate, to: endDate)
    }

    public func fetchActivities(from startDate: Date, to endDate: Date) async throws -> [WiiFitActivity] {
        // Return cached data - actual sync happens via sync() method
        return try await fetchCachedActivities(from: startDate, to: endDate)
    }

    public func testConnection() async throws -> Bool {
        guard let ipAddress = ipAddress, !ipAddress.isEmpty else {
            throw DataSourceError.notConfigured
        }
        return try await wiiConnection.testConnection(ipAddress: ipAddress)
    }

    public func fetchAvailableProfiles() async throws -> [WiiFitProfileInfo] {
        return lastSyncProfiles
    }

    // MARK: - Cache Methods

    public func fetchCachedMeasurements(from startDate: Date, to endDate: Date) async throws -> [WiiFitMeasurement] {
        try fetchCached(WiiFitMeasurement.self, modelType: WiiFitMeasurementModel.self, from: startDate, to: endDate)
    }

    public func fetchCachedActivities(from startDate: Date, to endDate: Date) async throws -> [WiiFitActivity] {
        try fetchCached(WiiFitActivity.self, modelType: WiiFitActivityModel.self, from: startDate, to: endDate)
    }

    public func hasCachedData() async throws -> Bool {
        let hasMeasurements = try hasCached(WiiFitMeasurement.self, modelType: WiiFitMeasurementModel.self)
        let hasActivities = try hasCached(WiiFitActivity.self, modelType: WiiFitActivityModel.self)
        return hasMeasurements || hasActivities
    }
}

// MARK: - DataSourceConfigurable

extension WiiFitDataSource: DataSourceConfigurable {
    public static var dataSourceType: DataSourceType { .wiiFit }

    public static var optionMappings: [ConfigKeyMapping] {
        [
            ConfigKeyMapping("wiiFitIPAddress", as: "ipAddress"),
            ConfigKeyMapping("wiiFitSelectedProfile", as: "selectedProfile"),
        ]
    }

    /// Custom implementation that validates IP address is non-empty.
    public static func loadSettingsFromUserDefaults() -> DataSourceSettings? {
        var options: [String: String] = [:]
        for mapping in optionMappings {
            options[mapping.settingsKey] = UserDefaults.standard.string(forKey: mapping.userDefaultsKey) ?? ""
        }

        // Wii Fit requires IP address to be configured
        guard let ip = options["ipAddress"], !ip.isEmpty else {
            return nil
        }

        return DataSourceSettings(
            dataSourceType: dataSourceType,
            credentials: [:],
            options: options
        )
    }
}
