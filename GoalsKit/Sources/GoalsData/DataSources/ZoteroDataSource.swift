import Foundation
import GoalsDomain

/// Data source implementation for Zotero reading and annotation statistics via Zotero API
public actor ZoteroDataSource: ZoteroDataSourceProtocol {
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

    private var apiKey: String?
    private var userID: String?
    private var toReadCollectionKey: String?
    private var inProgressCollectionKey: String?
    private var readCollectionKey: String?
    private let urlSession: URLSession

    private static let baseURL = "https://api.zotero.org"
    private static let maxItemsPerPage = 100

    public init(urlSession: URLSession = .shared) {
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
        guard let apiKey = apiKey, let userID = userID else {
            throw DataSourceError.notConfigured
        }

        // Fetch all annotations created in the date range
        let annotations = try await fetchAnnotations(apiKey: apiKey, userID: userID, from: startDate, to: endDate)

        // Fetch all notes created in the date range
        let notes = try await fetchNotes(apiKey: apiKey, userID: userID, from: startDate, to: endDate)

        // Aggregate by day
        return aggregateByDay(annotations: annotations, notes: notes, from: startDate, to: endDate)
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

        async let toReadCount = fetchCollectionItemCount(apiKey: apiKey, userID: userID, collectionKey: toReadKey)
        async let inProgressCount = fetchCollectionItemCount(apiKey: apiKey, userID: userID, collectionKey: inProgressKey)
        async let readCount = fetchCollectionItemCount(apiKey: apiKey, userID: userID, collectionKey: readKey)

        return ZoteroReadingStatus(
            date: Date(),
            toReadCount: try await toReadCount,
            inProgressCount: try await inProgressCount,
            readCount: try await readCount
        )
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
            let (_, _) = try await performRequestWithTotalCount(url: url, apiKey: apiKey)
            // If we get here without throwing, the connection works
            return true
        } catch let error as DataSourceError {
            // Re-throw so caller can show appropriate message
            throw error
        } catch {
            throw DataSourceError.connectionFailed(error.localizedDescription)
        }
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

    private func performRequest<T: Decodable>(url: URL, apiKey: String) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Zotero-API-Key")
        request.setValue("3", forHTTPHeaderField: "Zotero-API-Version")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DataSourceError.invalidResponse
        }

        // Handle rate limiting
        if httpResponse.statusCode == 429 {
            let backoffSeconds = Int(httpResponse.value(forHTTPHeaderField: "Backoff") ?? "5") ?? 5
            try await Task.sleep(for: .seconds(backoffSeconds))
            return try await performRequest(url: url, apiKey: apiKey)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DataSourceError.httpError(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func performRequestWithTotalCount(url: URL, apiKey: String) async throws -> (data: Data, totalResults: Int) {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Zotero-API-Key")
        request.setValue("3", forHTTPHeaderField: "Zotero-API-Version")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DataSourceError.invalidResponse
        }

        // Handle rate limiting
        if httpResponse.statusCode == 429 {
            let backoffSeconds = Int(httpResponse.value(forHTTPHeaderField: "Backoff") ?? "5") ?? 5
            try await Task.sleep(for: .seconds(backoffSeconds))
            return try await performRequestWithTotalCount(url: url, apiKey: apiKey)
        }

        // Handle authentication errors specifically
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw DataSourceError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DataSourceError.httpError(statusCode: httpResponse.statusCode)
        }

        let totalResults = Int(httpResponse.value(forHTTPHeaderField: "Total-Results") ?? "0") ?? 0

        return (data, totalResults)
    }

    private func fetchAnnotations(apiKey: String, userID: String, from startDate: Date, to endDate: Date) async throws -> [ZoteroItem] {
        var allItems: [ZoteroItem] = []
        var start = 0

        while true {
            let url = try buildURL(path: "/users/\(userID)/items", queryItems: [
                URLQueryItem(name: "itemType", value: "annotation"),
                URLQueryItem(name: "since", value: "0"),
                URLQueryItem(name: "sort", value: "dateAdded"),
                URLQueryItem(name: "direction", value: "asc"),
                URLQueryItem(name: "start", value: "\(start)"),
                URLQueryItem(name: "limit", value: "\(Self.maxItemsPerPage)")
            ])

            let (data, totalResults) = try await performRequestWithTotalCount(url: url, apiKey: apiKey)
            let items = try JSONDecoder().decode([ZoteroItem].self, from: data)

            // Filter items within date range
            let filteredItems = items.filter { item in
                guard let dateAdded = item.data.dateAdded else { return false }
                return dateAdded >= startDate && dateAdded <= endDate
            }

            allItems.append(contentsOf: filteredItems)

            start += items.count
            if start >= totalResults || items.isEmpty {
                break
            }

            // If the last item is past our end date, we can stop
            if let lastDate = items.last?.data.dateAdded, lastDate > endDate {
                break
            }
        }

        return allItems
    }

    private func fetchNotes(apiKey: String, userID: String, from startDate: Date, to endDate: Date) async throws -> [ZoteroItem] {
        var allItems: [ZoteroItem] = []
        var start = 0

        while true {
            let url = try buildURL(path: "/users/\(userID)/items", queryItems: [
                URLQueryItem(name: "itemType", value: "note"),
                URLQueryItem(name: "since", value: "0"),
                URLQueryItem(name: "sort", value: "dateAdded"),
                URLQueryItem(name: "direction", value: "asc"),
                URLQueryItem(name: "start", value: "\(start)"),
                URLQueryItem(name: "limit", value: "\(Self.maxItemsPerPage)")
            ])

            let (data, totalResults) = try await performRequestWithTotalCount(url: url, apiKey: apiKey)
            let items = try JSONDecoder().decode([ZoteroItem].self, from: data)

            // Filter items within date range
            let filteredItems = items.filter { item in
                guard let dateAdded = item.data.dateAdded else { return false }
                return dateAdded >= startDate && dateAdded <= endDate
            }

            allItems.append(contentsOf: filteredItems)

            start += items.count
            if start >= totalResults || items.isEmpty {
                break
            }

            // If the last item is past our end date, we can stop
            if let lastDate = items.last?.data.dateAdded, lastDate > endDate {
                break
            }
        }

        return allItems
    }

    private func fetchCollectionItemCount(apiKey: String, userID: String, collectionKey: String) async throws -> Int {
        // Use itemType=-attachment to exclude attachments (PDFs, snapshots, etc.)
        // This ensures we count only actual items (papers, books, etc.), not their attachments
        let url = try buildURL(path: "/users/\(userID)/collections/\(collectionKey)/items", queryItems: [
            URLQueryItem(name: "itemType", value: "-attachment"),
            URLQueryItem(name: "limit", value: "1")
        ])

        let (_, totalResults) = try await performRequestWithTotalCount(url: url, apiKey: apiKey)
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
