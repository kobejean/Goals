import Foundation
import SwiftData
import GoalsDomain

/// Data source implementation for Zotero reading and annotation statistics via Zotero API.
/// Supports optional caching via ModelContainer - uses VersionBasedStrategy since annotations can be edited.
public actor ZoteroDataSource: ZoteroDataSourceProtocol, CacheableDataSource {
    public let dataSourceType: DataSourceType = .zotero

    public nonisolated var availableMetrics: [MetricInfo] {
        [
            MetricInfo(key: "annotations", name: "Daily Annotations", unit: "items", icon: "pencil.line"),
            MetricInfo(key: "notes", name: "Daily Notes", unit: "items", icon: "note.text"),
            MetricInfo(key: "toRead", name: "To Read", unit: "items", icon: "book.closed"),
            MetricInfo(key: "inProgress", name: "In Progress", unit: "items", icon: "book"),
            MetricInfo(key: "read", name: "Read", unit: "items", icon: "checkmark.circle"),
        ]
    }

    public nonisolated func metricValue(for key: String, from stats: Any) -> Double? {
        if let dailyStats = stats as? ZoteroDailyStats {
            switch key {
            case "annotations": return Double(dailyStats.annotationCount)
            case "notes": return Double(dailyStats.noteCount)
            default: return nil
            }
        } else if let readingStatus = stats as? ZoteroReadingStatus {
            switch key {
            case "toRead": return Double(readingStatus.toReadCount)
            case "inProgress": return Double(readingStatus.inProgressCount)
            case "read": return Double(readingStatus.readCount)
            default: return nil
            }
        }
        return nil
    }

    // MARK: - CacheableDataSource

    public let modelContainer: ModelContainer?

    /// Strategy for version-based incremental fetching.
    /// Zotero annotations are mutable and the API supports version-based sync.
    private let versionStrategy = VersionBasedStrategy(strategyKey: "zotero.dailyStats")

    // MARK: - Configuration

    private var apiKey: String?
    private var userID: String?
    private var toReadCollectionKey: String?
    private var inProgressCollectionKey: String?
    private var readCollectionKey: String?
    private let urlSession: URLSession

    private static let baseURL = "https://api.zotero.org"
    private static let maxItemsPerPage = 100

    /// Creates a ZoteroDataSource without caching (for testing).
    public init(urlSession: URLSession = .shared) {
        self.modelContainer = nil
        self.urlSession = urlSession
    }

    /// Creates a ZoteroDataSource with caching enabled (for production).
    public init(modelContainer: ModelContainer, urlSession: URLSession = .shared) {
        self.modelContainer = modelContainer
        self.urlSession = urlSession
    }

    public func isConfigured() async -> Bool {
        apiKey != nil && userID != nil
    }

    public func configure(settings: DataSourceSettings) async throws {
        guard settings.dataSourceType == .zotero else {
            throw DataSourceError.invalidConfiguration
        }

        guard let apiKey = settings.credentials["apiKey"], !apiKey.isEmpty else {
            throw DataSourceError.missingCredentials
        }

        guard let userID = settings.credentials["userID"], !userID.isEmpty else {
            throw DataSourceError.missingCredentials
        }

        self.apiKey = apiKey
        self.userID = userID

        // Collection keys are optional - if not set, reading status won't be available
        self.toReadCollectionKey = settings.options["toReadCollection"]
        self.inProgressCollectionKey = settings.options["inProgressCollection"]
        self.readCollectionKey = settings.options["readCollection"]
    }

    public func clearConfiguration() async throws {
        apiKey = nil
        userID = nil
        toReadCollectionKey = nil
        inProgressCollectionKey = nil
        readCollectionKey = nil
    }

    public func fetchLatestMetricValue(for metricKey: String, taskId: UUID?) async throws -> Double? {
        switch metricKey {
        case "annotations", "notes":
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate) ?? endDate
            let stats = try await fetchDailyStats(from: startDate, to: endDate)
            guard let latest = stats.last else { return nil }
            return metricValue(for: metricKey, from: latest)
        case "toRead", "inProgress", "read":
            guard let status = try await fetchReadingStatus() else { return nil }
            return metricValue(for: metricKey, from: status)
        default:
            return nil
        }
    }

    // MARK: - ZoteroDataSourceProtocol

    public func fetchDailyStats(from startDate: Date, to endDate: Date) async throws -> [ZoteroDailyStats] {
        guard let container = modelContainer else {
            // No caching - just fetch and return
            let (stats, _) = try await fetchDailyStatsWithVersion(from: startDate, to: endDate, sinceVersion: nil)
            return stats
        }

        // Get current cached data
        let cachedStats = try fetchCached(ZoteroDailyStats.self, modelType: ZoteroDailyStatsModel.self, from: startDate, to: endDate)

        // Get version for incremental fetch
        let metadata = try? fetchStrategyMetadata(for: versionStrategy)
        let sinceVersion = versionStrategy.versionForIncrementalFetch(metadata: metadata)

        do {
            // Use version-based incremental sync
            // - If we have sinceVersion, only fetch items modified since then
            // - If not, do a full fetch (first time or after cache clear)
            let (remoteStats, newLibraryVersion) = try await fetchDailyStatsWithVersion(
                from: startDate,
                to: endDate,
                sinceVersion: sinceVersion
            )

            if !remoteStats.isEmpty {
                // Merge new stats with existing cached data
                // For incremental sync, we need to combine counts for the same day
                let mergedStats = mergeStats(existing: cachedStats, new: remoteStats)
                try storeInCache(mergedStats, modelType: ZoteroDailyStatsModel.self)
            }

            // Update library version on success
            if newLibraryVersion > 0 {
                let updatedMetadata = versionStrategy.updateMetadata(
                    previous: metadata,
                    fetchedRange: (startDate, endDate),
                    fetchedAt: Date(),
                    newVersion: newLibraryVersion
                )
                try storeStrategyMetadata(updatedMetadata, for: versionStrategy)
            }
        } catch {
            // Don't fail if we already have cached data - use what we have
            // This is graceful degradation for when Zotero API isn't available
            if cachedStats.isEmpty {
                throw error
            }
        }

        // Fetch fresh reading status first so we have today's snapshot for progress calculation
        _ = try? await fetchReadingStatus()

        // Compute reading progress scores from reading status snapshots and merge into stats
        let statsFromCache = try fetchCached(ZoteroDailyStats.self, modelType: ZoteroDailyStatsModel.self, from: startDate, to: endDate)
        let progressScores = try computeReadingProgressScores(from: startDate, to: endDate, container: container)
        let statsWithProgress = mergeReadingProgress(stats: statsFromCache, progressScores: progressScores)

        // Store the merged stats back to cache
        if !progressScores.isEmpty {
            try storeInCache(statsWithProgress, modelType: ZoteroDailyStatsModel.self)
        }

        return statsWithProgress
    }

    /// Fetches daily stats with version-based incremental sync support.
    /// - Parameters:
    ///   - startDate: Start of date range
    ///   - endDate: End of date range
    ///   - sinceVersion: If provided, only fetches items modified since this library version
    /// - Returns: Tuple of daily stats and the current library version from the API
    public func fetchDailyStatsWithVersion(
        from startDate: Date,
        to endDate: Date,
        sinceVersion: Int?
    ) async throws -> (stats: [ZoteroDailyStats], libraryVersion: Int) {
        guard let apiKey = apiKey, let userID = userID else {
            throw DataSourceError.notConfigured
        }

        // Fetch annotations and notes in parallel
        async let annotationsResult = fetchAnnotations(
            apiKey: apiKey,
            userID: userID,
            from: startDate,
            to: endDate,
            sinceVersion: sinceVersion
        )
        async let notesResult = fetchNotes(
            apiKey: apiKey,
            userID: userID,
            from: startDate,
            to: endDate,
            sinceVersion: sinceVersion
        )

        let (annotations, annotationsVersion) = try await annotationsResult
        let (notes, notesVersion) = try await notesResult

        // Use the maximum library version from both requests
        let libraryVersion = max(annotationsVersion, notesVersion)

        // Aggregate by day
        let stats = aggregateByDay(annotations: annotations, notes: notes, from: startDate, to: endDate)
        return (stats, libraryVersion)
    }

    public func fetchReadingStatus() async throws -> ZoteroReadingStatus? {
        guard let apiKey = apiKey, let userID = userID else {
            throw DataSourceError.notConfigured
        }

        // All collection keys must be configured for reading status
        guard let toReadKey = toReadCollectionKey, !toReadKey.isEmpty,
              let inProgressKey = inProgressCollectionKey, !inProgressKey.isEmpty,
              let readKey = readCollectionKey, !readKey.isEmpty else {
            return nil
        }

        // Reading status is a point-in-time snapshot, so always try to fetch fresh
        // But cache it for widget access
        do {
            async let toReadCount = fetchCollectionItemCount(apiKey: apiKey, userID: userID, collectionKey: toReadKey)
            async let inProgressCount = fetchCollectionItemCount(apiKey: apiKey, userID: userID, collectionKey: inProgressKey)
            async let readCount = fetchCollectionItemCount(apiKey: apiKey, userID: userID, collectionKey: readKey)

            let status = ZoteroReadingStatus(
                date: Date(),
                toReadCount: try await toReadCount,
                inProgressCount: try await inProgressCount,
                readCount: try await readCount
            )

            // Cache the reading status
            try storeInCache([status], modelType: ZoteroReadingStatusModel.self)

            return status
        } catch {
            // Fall back to cached reading status on error
            return try await fetchCachedReadingStatus()
        }
    }

    public func testConnection() async throws -> Bool {
        guard let apiKey = apiKey, let userID = userID else {
            throw DataSourceError.notConfigured
        }

        // Test connection by fetching user info
        let url = try buildURL(path: "/users/\(userID)/items", queryItems: [
            URLQueryItem(name: "limit", value: "1")
        ])

        do {
            // Just check if the request succeeds - don't need to decode the response
            let (_, _, _) = try await performRequestWithTotalCount(url: url, apiKey: apiKey)
            // If we get here without throwing, the connection works
            return true
        } catch let error as DataSourceError {
            // Re-throw so caller can show appropriate message
            throw error
        } catch {
            throw DataSourceError.connectionFailed(error.localizedDescription)
        }
    }

    // MARK: - Cache-Only Methods (for instant display)

    public func fetchCachedDailyStats(from startDate: Date, to endDate: Date) throws -> [ZoteroDailyStats] {
        try fetchCached(ZoteroDailyStats.self, modelType: ZoteroDailyStatsModel.self, from: startDate, to: endDate)
    }

    public func fetchCachedReadingStatus() async throws -> ZoteroReadingStatus? {
        // Get the most recent reading status from cache
        let cachedStatuses = try fetchCached(ZoteroReadingStatus.self, modelType: ZoteroReadingStatusModel.self)
        return cachedStatuses.max { $0.date < $1.date }
    }

    public func hasCachedData() throws -> Bool {
        try hasCached(ZoteroDailyStats.self, modelType: ZoteroDailyStatsModel.self)
    }

    // MARK: - Merge Helpers

    /// Compute reading progress delta scores from cached reading status snapshots.
    /// Returns the change in reading progress from the previous day (delta).
    /// Score formula: toRead×0.25 + inProgress×0.5 + read×1.0
    private func computeReadingProgressScores(from startDate: Date, to endDate: Date, container: ModelContainer) throws -> [Date: Double] {
        let snapshots = try ZoteroReadingStatusModel.fetch(from: startDate, to: endDate, in: container)
        guard !snapshots.isEmpty else {
            return [:]
        }

        let calendar = Calendar.current
        var scores: [Date: Double] = [:]

        // Sort snapshots by date to compute deltas
        let sortedSnapshots = snapshots.sorted { $0.date < $1.date }

        // Compute absolute score for each snapshot
        func absoluteScore(for snapshot: ZoteroReadingStatus) -> Double {
            Double(snapshot.toReadCount) * 0.25 +
            Double(snapshot.inProgressCount) * 0.5 +
            Double(snapshot.readCount) * 1.0
        }

        var previousScore: Double? = nil

        for snapshot in sortedSnapshots {
            let day = calendar.startOfDay(for: snapshot.date)
            let currentScore = absoluteScore(for: snapshot)

            // Delta = current - previous (how much progress made today)
            // For first snapshot, assume previous score was 0 (empty state)
            let prevScore = previousScore ?? 0
            let delta = currentScore - prevScore
            // Only record positive deltas (progress), ignore negative (items removed)
            scores[day] = max(0, delta)

            previousScore = currentScore
        }

        return scores
    }

    /// Merge computed reading progress scores into daily stats.
    private func mergeReadingProgress(stats: [ZoteroDailyStats], progressScores: [Date: Double]) -> [ZoteroDailyStats] {
        guard !progressScores.isEmpty else {
            return stats
        }

        let calendar = Calendar.current
        var statsByDay: [Date: ZoteroDailyStats] = [:]

        // Index existing stats by day
        for stat in stats {
            let day = calendar.startOfDay(for: stat.date)
            statsByDay[day] = stat
        }

        // Merge reading progress scores
        for (day, score) in progressScores {
            if let existingStat = statsByDay[day] {
                // Update existing stat with reading progress score
                statsByDay[day] = ZoteroDailyStats(
                    date: existingStat.date,
                    annotationCount: existingStat.annotationCount,
                    noteCount: existingStat.noteCount,
                    readingProgressScore: score
                )
            } else {
                // Create new stat entry for reading progress only
                statsByDay[day] = ZoteroDailyStats(
                    date: day,
                    annotationCount: 0,
                    noteCount: 0,
                    readingProgressScore: score
                )
            }
        }

        return statsByDay.values.sorted { $0.date < $1.date }
    }

    /// Merges new stats with existing cached stats.
    /// For incremental sync, new stats may include modified items that were already counted.
    /// To avoid double-counting: only add stats for dates that didn't exist before,
    /// and for today's date (which is volatile and may have genuinely new items).
    private func mergeStats(existing: [ZoteroDailyStats], new: [ZoteroDailyStats]) -> [ZoteroDailyStats] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var statsByDay: [Date: ZoteroDailyStats] = [:]

        // First, add all existing stats
        for stat in existing {
            let day = calendar.startOfDay(for: stat.date)
            statsByDay[day] = stat
        }

        // Then merge in new stats
        for stat in new {
            let day = calendar.startOfDay(for: stat.date)
            if let existingStat = statsByDay[day] {
                // For today's date, add to existing counts (genuinely new items likely)
                // For past dates, the incremental data might include modified items
                // we already counted, so only add if it's today
                if day == today {
                    statsByDay[day] = ZoteroDailyStats(
                        date: existingStat.date,
                        annotationCount: existingStat.annotationCount + stat.annotationCount,
                        noteCount: existingStat.noteCount + stat.noteCount,
                        readingProgressScore: existingStat.readingProgressScore
                    )
                }
                // For past dates, skip - they're likely modified items we already counted
            } else {
                // New date we haven't seen before - add it
                statsByDay[day] = stat
            }
        }

        return statsByDay.values.sorted { $0.date < $1.date }
    }

    // MARK: - Private Helpers

    private func buildURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        var components = URLComponents(string: Self.baseURL + path)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else {
            throw DataSourceError.invalidURL
        }
        return url
    }

    /// Executes an HTTP request with Zotero API headers and handles rate limiting.
    /// Returns raw data and the HTTP response for further processing.
    private func executeRequest(url: URL, apiKey: String) async throws -> (data: Data, response: HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Zotero-API-Key")
        request.setValue("3", forHTTPHeaderField: "Zotero-API-Version")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DataSourceError.invalidResponse
        }

        // Handle rate limiting with automatic retry
        if httpResponse.statusCode == 429 {
            let backoffSeconds = Int(httpResponse.value(forHTTPHeaderField: "Backoff") ?? "5") ?? 5
            try await Task.sleep(for: .seconds(backoffSeconds))
            return try await executeRequest(url: url, apiKey: apiKey)
        }

        // Handle authentication errors
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw DataSourceError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DataSourceError.httpError(statusCode: httpResponse.statusCode)
        }

        return (data, httpResponse)
    }

    private func performRequest<T: Decodable>(url: URL, apiKey: String) async throws -> T {
        let (data, _) = try await executeRequest(url: url, apiKey: apiKey)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func performRequestWithTotalCount(url: URL, apiKey: String) async throws -> (data: Data, totalResults: Int, libraryVersion: Int) {
        let (data, httpResponse) = try await executeRequest(url: url, apiKey: apiKey)
        let totalResults = Int(httpResponse.value(forHTTPHeaderField: "Total-Results") ?? "0") ?? 0
        let libraryVersion = Int(httpResponse.value(forHTTPHeaderField: "Last-Modified-Version") ?? "0") ?? 0
        return (data, totalResults, libraryVersion)
    }

    private func fetchAnnotations(
        apiKey: String,
        userID: String,
        from startDate: Date,
        to endDate: Date,
        sinceVersion: Int? = nil
    ) async throws -> (items: [ZoteroItem], libraryVersion: Int) {
        var allItems: [ZoteroItem] = []
        var start = 0
        var latestLibraryVersion = 0

        while true {
            try Task.checkCancellation()

            var queryItems = [
                URLQueryItem(name: "itemType", value: "annotation"),
                URLQueryItem(name: "sort", value: "dateAdded"),
                URLQueryItem(name: "direction", value: "asc"),
                URLQueryItem(name: "start", value: "\(start)"),
                URLQueryItem(name: "limit", value: "\(Self.maxItemsPerPage)")
            ]

            // Use version-based sync if we have a previous version, otherwise fetch all
            if let version = sinceVersion {
                queryItems.append(URLQueryItem(name: "since", value: "\(version)"))
            }

            let url = try buildURL(path: "/users/\(userID)/items", queryItems: queryItems)

            let (data, totalResults, libraryVersion) = try await performRequestWithTotalCount(url: url, apiKey: apiKey)
            latestLibraryVersion = max(latestLibraryVersion, libraryVersion)
            let items = try JSONDecoder().decode([ZoteroItem].self, from: data)

            // When using incremental sync (sinceVersion provided), we get all changed items
            // and need to filter by date. When doing full fetch, also filter by date.
            let filteredItems = items.filter { item in
                guard let dateAdded = item.data.dateAdded else { return false }
                return dateAdded >= startDate && dateAdded <= endDate
            }

            allItems.append(contentsOf: filteredItems)

            start += items.count
            if start >= totalResults || items.isEmpty {
                break
            }

            // If the last item is past our end date, we can stop (only for full fetches)
            if sinceVersion == nil, let lastDate = items.last?.data.dateAdded, lastDate > endDate {
                break
            }
        }

        return (allItems, latestLibraryVersion)
    }

    private func fetchNotes(
        apiKey: String,
        userID: String,
        from startDate: Date,
        to endDate: Date,
        sinceVersion: Int? = nil
    ) async throws -> (items: [ZoteroItem], libraryVersion: Int) {
        var allItems: [ZoteroItem] = []
        var start = 0
        var latestLibraryVersion = 0

        while true {
            try Task.checkCancellation()

            var queryItems = [
                URLQueryItem(name: "itemType", value: "note"),
                URLQueryItem(name: "sort", value: "dateAdded"),
                URLQueryItem(name: "direction", value: "asc"),
                URLQueryItem(name: "start", value: "\(start)"),
                URLQueryItem(name: "limit", value: "\(Self.maxItemsPerPage)")
            ]

            // Use version-based sync if we have a previous version, otherwise fetch all
            if let version = sinceVersion {
                queryItems.append(URLQueryItem(name: "since", value: "\(version)"))
            }

            let url = try buildURL(path: "/users/\(userID)/items", queryItems: queryItems)

            let (data, totalResults, libraryVersion) = try await performRequestWithTotalCount(url: url, apiKey: apiKey)
            latestLibraryVersion = max(latestLibraryVersion, libraryVersion)
            let items = try JSONDecoder().decode([ZoteroItem].self, from: data)

            // When using incremental sync (sinceVersion provided), we get all changed items
            // and need to filter by date. When doing full fetch, also filter by date.
            let filteredItems = items.filter { item in
                guard let dateAdded = item.data.dateAdded else { return false }
                return dateAdded >= startDate && dateAdded <= endDate
            }

            allItems.append(contentsOf: filteredItems)

            start += items.count
            if start >= totalResults || items.isEmpty {
                break
            }

            // If the last item is past our end date, we can stop (only for full fetches)
            if sinceVersion == nil, let lastDate = items.last?.data.dateAdded, lastDate > endDate {
                break
            }
        }

        return (allItems, latestLibraryVersion)
    }

    private func fetchCollectionItemCount(apiKey: String, userID: String, collectionKey: String) async throws -> Int {
        // Use itemType=-attachment to exclude attachments (PDFs, snapshots, etc.)
        // This ensures we count only actual items (papers, books, etc.), not their attachments
        let url = try buildURL(path: "/users/\(userID)/collections/\(collectionKey)/items", queryItems: [
            URLQueryItem(name: "itemType", value: "-attachment"),
            URLQueryItem(name: "limit", value: "1")
        ])

        let (_, totalResults, _) = try await performRequestWithTotalCount(url: url, apiKey: apiKey)
        return totalResults
    }

    private func aggregateByDay(annotations: [ZoteroItem], notes: [ZoteroItem], from startDate: Date, to endDate: Date) -> [ZoteroDailyStats] {
        let calendar = Calendar.current

        // Group annotations by day
        var annotationsByDay: [Date: Int] = [:]
        for annotation in annotations {
            if let dateAdded = annotation.data.dateAdded {
                let day = calendar.startOfDay(for: dateAdded)
                annotationsByDay[day, default: 0] += 1
            }
        }

        // Group notes by day
        var notesByDay: [Date: Int] = [:]
        for note in notes {
            if let dateAdded = note.data.dateAdded {
                let day = calendar.startOfDay(for: dateAdded)
                notesByDay[day, default: 0] += 1
            }
        }

        // Get all days in range that have activity
        let allDays = Set(annotationsByDay.keys).union(Set(notesByDay.keys))

        return allDays.map { day in
            ZoteroDailyStats(
                date: day,
                annotationCount: annotationsByDay[day] ?? 0,
                noteCount: notesByDay[day] ?? 0
            )
        }.sorted { $0.date < $1.date }
    }
}

// MARK: - API Models

/// Wrapper for items response (used for type inference)
private struct ZoteroItemsResponse: Decodable {
    // The response is just an array, but we use this for explicit type inference
}

/// Zotero API item structure
private struct ZoteroItem: Decodable {
    let key: String
    let data: ZoteroItemData
}

/// Zotero item data structure
private struct ZoteroItemData: Decodable {
    let itemType: String
    let dateAdded: Date?

    enum CodingKeys: String, CodingKey {
        case itemType
        case dateAdded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemType = try container.decode(String.self, forKey: .itemType)

        // Parse ISO8601 date string
        if let dateString = try container.decodeIfPresent(String.self, forKey: .dateAdded) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                dateAdded = date
            } else {
                // Try without fractional seconds
                formatter.formatOptions = [.withInternetDateTime]
                dateAdded = formatter.date(from: dateString)
            }
        } else {
            dateAdded = nil
        }
    }
}
