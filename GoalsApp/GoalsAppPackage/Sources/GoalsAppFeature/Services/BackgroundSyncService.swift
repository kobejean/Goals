import Foundation
import SwiftData
import WidgetKit
import GoalsDomain
import GoalsData
import GoalsWidgetShared

/// Service for performing background data sync to keep widget data fresh.
/// This service is non-MainActor to allow execution in background tasks.
public final class BackgroundSyncService: Sendable {
    private let dataCache: DataCache
    private let httpClient: HTTPClient
    private let typeQuickerDataSource: TypeQuickerDataSource
    private let atCoderDataSource: AtCoderDataSource
    private let ankiDataSource: AnkiDataSource
    private let healthKitSleepDataSource: HealthKitSleepDataSource

    /// Creates a BackgroundSyncService with its own dependencies
    /// Uses the shared App Group container with unified schema
    public init() throws {
        // Create container using unified schema (same as main app)
        let unifiedSchema = UnifiedSchema.createSchema()
        let configuration: ModelConfiguration

        if let storeURL = SharedStorage.sharedMainStoreURL {
            configuration = ModelConfiguration(
                schema: unifiedSchema,
                url: storeURL,
                cloudKitDatabase: .none
            )
        } else {
            // Fallback - shouldn't happen in production
            configuration = ModelConfiguration(
                schema: unifiedSchema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        }

        let container = try ModelContainer(
            for: unifiedSchema,
            configurations: [configuration]
        )

        self.dataCache = DataCache(modelContainer: container)
        self.httpClient = HTTPClient()

        // Create data sources with caching enabled
        self.typeQuickerDataSource = TypeQuickerDataSource(cache: dataCache, httpClient: httpClient)
        self.atCoderDataSource = AtCoderDataSource(cache: dataCache, httpClient: httpClient)
        self.ankiDataSource = AnkiDataSource(cache: dataCache)
        self.healthKitSleepDataSource = HealthKitSleepDataSource(cache: dataCache)
    }

    /// Performs the background sync operation
    /// Syncs all configured data sources to the shared cache
    public func performSync() async throws {
        // Configure data sources from UserDefaults (shared suite)
        await configureDataSources()

        // Sync data sources in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.syncTypeQuicker() }
            group.addTask { await self.syncAtCoder() }
            group.addTask { await self.syncAnki() }
            group.addTask { await self.syncSleep() }
        }

        // Reload widget timelines
        await MainActor.run {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Private

    private func configureDataSources() async {
        let defaults = SharedStorage.sharedDefaults ?? .standard

        // Configure TypeQuicker
        if let username = defaults.string(forKey: UserDefaultsKeys.typeQuickerUsername), !username.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .typeQuicker,
                credentials: ["username": username]
            )
            try? await typeQuickerDataSource.configure(settings: settings)
        }

        // Configure AtCoder
        if let username = defaults.string(forKey: UserDefaultsKeys.atCoderUsername), !username.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .atCoder,
                credentials: ["username": username]
            )
            try? await atCoderDataSource.configure(settings: settings)
        }

        // Configure Anki
        if let host = defaults.string(forKey: UserDefaultsKeys.ankiHost), !host.isEmpty {
            let port = defaults.string(forKey: UserDefaultsKeys.ankiPort) ?? "8765"
            let decks = defaults.string(forKey: UserDefaultsKeys.ankiDecks) ?? ""
            let settings = DataSourceSettings(
                dataSourceType: .anki,
                options: ["host": host, "port": port, "decks": decks]
            )
            try? await ankiDataSource.configure(settings: settings)
        }
    }

    private func syncTypeQuicker() async {
        guard await typeQuickerDataSource.isConfigured() else { return }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate) ?? endDate

        do {
            // Fetching stats will update the cache automatically
            _ = try await typeQuickerDataSource.fetchStats(from: startDate, to: endDate)
        } catch {
            // Log error but don't fail the entire sync
            print("BackgroundSyncService: TypeQuicker sync failed: \(error)")
        }
    }

    private func syncAtCoder() async {
        guard await atCoderDataSource.isConfigured() else { return }

        do {
            // Use combined method to avoid redundant ranking API calls
            _ = try await atCoderDataSource.fetchStatsAndContestHistory()
            // Fetch daily effort for activity grid (submissions + difficulty calculation)
            _ = try await atCoderDataSource.fetchDailyEffort(from: nil)
        } catch {
            print("BackgroundSyncService: AtCoder sync failed: \(error)")
        }
    }

    private func syncAnki() async {
        guard await ankiDataSource.isConfigured() else { return }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate) ?? endDate

        do {
            // Fetching daily stats will update the cache automatically
            _ = try await ankiDataSource.fetchDailyStats(from: startDate, to: endDate)
        } catch {
            print("BackgroundSyncService: Anki sync failed: \(error)")
        }
    }

    private func syncSleep() async {
        // HealthKit doesn't require configuration - uses system authorization
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate

        do {
            // Fetching sleep data will update the cache automatically
            _ = try await healthKitSleepDataSource.fetchSleepData(from: startDate, to: endDate)
        } catch {
            print("BackgroundSyncService: Sleep sync failed: \(error)")
        }
    }
}
