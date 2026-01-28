import Foundation
import GoalsDomain

/// Data source implementation for Anki learning statistics via AnkiConnect.
/// Supports optional caching via DataCache - uses DateBasedStrategy since review stats are immutable.
public actor AnkiDataSource: AnkiDataSourceProtocol, IncrementalCacheableDataSource {
    public let dataSourceType: DataSourceType = .anki

    public nonisolated var availableMetrics: [MetricInfo] {
        [
            MetricInfo(key: "reviews", name: "Daily Reviews", unit: "cards", icon: "rectangle.stack"),
            MetricInfo(key: "studyTime", name: "Study Time", unit: "min", icon: "clock"),
            MetricInfo(key: "retention", name: "Retention Rate", unit: "%", icon: "checkmark.circle"),
            MetricInfo(key: "newCards", name: "New Cards", unit: "cards", icon: "plus.circle"),
        ]
    }

    public nonisolated func metricValue(for key: String, from stats: Any) -> Double? {
        guard let stat = stats as? AnkiDailyStats else { return nil }
        switch key {
        case "reviews": return Double(stat.reviewCount)
        case "studyTime": return stat.studyTimeMinutes
        case "retention": return stat.retentionRate
        case "newCards": return Double(stat.newCardsCount)
        default: return nil
        }
    }

    // MARK: - IncrementalCacheableDataSource

    public let cache: DataCache?
    public nonisolated let cacheStrategyKey = "anki.dailyStats"

    // MARK: - Configuration

    private var host: String?
    private var port: Int?
    private var selectedDecks: [String]?
    private let urlSession: URLSession

    /// Creates an AnkiDataSource without caching (for testing).
    public init(urlSession: URLSession? = nil) {
        self.cache = nil
        self.urlSession = Self.createURLSession(urlSession)
    }

    /// Creates an AnkiDataSource with caching enabled (for production).
    public init(cache: DataCache, urlSession: URLSession? = nil) {
        self.cache = cache
        self.urlSession = Self.createURLSession(urlSession)
    }

    private static func createURLSession(_ provided: URLSession?) -> URLSession {
        if let provided = provided {
            return provided
        }
        // Use ephemeral config to avoid connection pooling issues with AnkiConnect
        // AnkiConnect is single-threaded and doesn't handle connection reuse well
        let config = URLSessionConfiguration.ephemeral
        config.httpMaximumConnectionsPerHost = 1
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }

    public func isConfigured() async -> Bool {
        host != nil && port != nil
    }

    public func configure(settings: DataSourceSettings) async throws {
        guard settings.dataSourceType == .anki else {
            throw DataSourceError.invalidConfiguration
        }

        guard let host = settings.options["host"], !host.isEmpty else {
            throw DataSourceError.missingCredentials
        }

        let portString = settings.options["port"] ?? "8765"
        guard let port = Int(portString) else {
            throw DataSourceError.invalidConfiguration
        }

        self.host = host
        self.port = port

        // Parse selected decks from comma-separated string
        if let decksString = settings.options["decks"], !decksString.isEmpty {
            self.selectedDecks = decksString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        } else {
            self.selectedDecks = nil
        }
    }

    public func clearConfiguration() async throws {
        host = nil
        port = nil
        selectedDecks = nil
    }

    public func fetchLatestMetricValue(for metricKey: String, taskId: UUID?) async throws -> Double? {
        guard let stats = try await fetchLatestStats() else { return nil }
        return metricValue(for: metricKey, from: stats)
    }

    // MARK: - AnkiDataSourceProtocol

    public func fetchDailyStats(from startDate: Date, to endDate: Date) async throws -> [AnkiDailyStats] {
        try await cachedFetch(fetcher: fetchDailyStatsFromRemote, from: startDate, to: endDate)
    }

    /// Internal method that fetches stats directly from AnkiConnect.
    private func fetchDailyStatsFromRemote(from startDate: Date, to endDate: Date) async throws -> [AnkiDailyStats] {
        // Check for cancellation immediately - avoid any work if already cancelled
        try Task.checkCancellation()

        guard let host = host, let port = port else {
            throw DataSourceError.notConfigured
        }

        // Get all deck names or use selected decks
        let decksToFetch: [String]
        if let selected = selectedDecks, !selected.isEmpty {
            decksToFetch = selected
        } else {
            decksToFetch = try await fetchDeckNames()
        }

        guard !decksToFetch.isEmpty else {
            return []
        }

        // Fetch reviews from all decks sequentially
        // AnkiConnect is single-threaded and can't handle parallel requests
        // Add small delay between requests to let AnkiConnect recover
        var allReviews: [AnkiCardReview] = []
        for (index, deck) in decksToFetch.enumerated() {
            try Task.checkCancellation()
            if index > 0 {
                try await Task.sleep(for: .milliseconds(50))
            }
            let deckReviews = try await fetchCardReviews(deck: deck, host: host, port: port)
            allReviews.append(contentsOf: deckReviews)
        }

        // Filter reviews by date range and aggregate by day
        return aggregateReviewsByDay(reviews: allReviews, from: startDate, to: endDate)
    }

    public func fetchLatestStats() async throws -> AnkiDailyStats? {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate) ?? endDate
        let stats = try await fetchDailyStats(from: startDate, to: endDate)
        return stats.last
    }

    public func fetchDeckNames() async throws -> [String] {
        guard let host = host, let port = port else {
            throw DataSourceError.notConfigured
        }

        let url = try buildURL(host: host, port: port)
        let request = AnkiConnectRequest(action: "deckNames", version: 6)
        let response: AnkiConnectResponse<[String]> = try await performRequest(url: url, request: request)

        guard let result = response.result else {
            if let error = response.error {
                throw DataSourceError.parseError(error)
            }
            return []
        }

        return result
    }

    public func testConnection() async throws -> Bool {
        guard let host = host, let port = port else {
            throw DataSourceError.notConfigured
        }

        let url = try buildURL(host: host, port: port)
        let request = AnkiConnectRequest(action: "version", version: 6)

        do {
            let _: AnkiConnectResponse<Int> = try await performRequest(url: url, request: request)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Private Helpers

    private func buildURL(host: String, port: Int) throws -> URL {
        guard let url = URL(string: "http://\(host):\(port)") else {
            throw DataSourceError.invalidURL
        }
        return url
    }

    private func performRequest<T: Decodable, R: Encodable>(url: URL, request: R) async throws -> T {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("close", forHTTPHeaderField: "Connection") // Force new connection each request
        urlRequest.httpBody = try JSONEncoder().encode(request)

        // Retry logic for transient connection failures
        var lastError: Error?
        for attempt in 1...3 {
            do {
                try Task.checkCancellation()
                let (data, response) = try await urlSession.data(for: urlRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw DataSourceError.invalidResponse
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw DataSourceError.httpError(statusCode: httpResponse.statusCode)
                }

                return try JSONDecoder().decode(T.self, from: data)
            } catch let error as URLError where error.code == .networkConnectionLost {
                lastError = error
                print("[AnkiDataSource] Connection lost (attempt \(attempt)/3), retrying...")
                if attempt < 3 {
                    try await Task.sleep(for: .milliseconds(200 * attempt))
                }
            } catch {
                throw error
            }
        }

        throw lastError ?? DataSourceError.connectionFailed("Connection lost after 3 retries")
    }

    private func fetchCardReviews(deck: String, host: String, port: Int) async throws -> [AnkiCardReview] {
        let url = try buildURL(host: host, port: port)
        let params = CardReviewsParams(deck: deck, startID: 0)
        let request = AnkiConnectRequest(
            action: "cardReviews",
            version: 6,
            params: params
        )

        let response: AnkiConnectResponse<[[Int]]> = try await performRequest(url: url, request: request)

        guard let result = response.result else {
            if let error = response.error {
                throw DataSourceError.parseError(error)
            }
            return []
        }

        // Parse card reviews: each review is [reviewTime, cardID, usn, buttonPressed, newInterval, previousInterval, newFactor, reviewDuration, reviewType]
        return result.compactMap { review -> AnkiCardReview? in
            guard review.count >= 9 else {
                return nil
            }

            let reviewTimeMs = review[0]
            let buttonPressed = review[3]
            let reviewDurationMs = review[7]
            let reviewType = review[8]

            let reviewDate = Date(timeIntervalSince1970: Double(reviewTimeMs) / 1000.0)
            let isCorrect = buttonPressed >= 2 // Button 2+ means "Good" or better
            let isNewCard = reviewType == 0 // reviewType 0 = learning/new

            return AnkiCardReview(
                date: reviewDate,
                durationSeconds: reviewDurationMs / 1000,
                isCorrect: isCorrect,
                isNewCard: isNewCard
            )
        }
    }

    private func aggregateReviewsByDay(reviews: [AnkiCardReview], from startDate: Date, to endDate: Date) -> [AnkiDailyStats] {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        // Filter reviews within date range
        let filteredReviews = reviews.filter { review in
            let reviewDay = calendar.startOfDay(for: review.date)
            return reviewDay >= startDay && reviewDay <= endDay
        }

        // Group by day
        let grouped = Dictionary(grouping: filteredReviews) { review in
            calendar.startOfDay(for: review.date)
        }

        // Convert to AnkiDailyStats
        return grouped.map { (date, dayReviews) in
            let reviewCount = dayReviews.count
            let studyTimeSeconds = dayReviews.reduce(0) { $0 + $1.durationSeconds }
            let correctCount = dayReviews.filter { $0.isCorrect }.count
            let newCardsCount = dayReviews.filter { $0.isNewCard }.count

            return AnkiDailyStats(
                date: date,
                reviewCount: reviewCount,
                studyTimeSeconds: studyTimeSeconds,
                correctCount: correctCount,
                newCardsCount: newCardsCount
            )
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Cache-Only Methods (for instant display)

    public func fetchCachedDailyStats(from startDate: Date, to endDate: Date) async throws -> [AnkiDailyStats] {
        try await fetchCached(AnkiDailyStats.self, from: startDate, to: endDate)
    }

    public func hasCachedData() async throws -> Bool {
        try await hasCached(AnkiDailyStats.self)
    }
}

// MARK: - API Models

/// AnkiConnect request structure
private struct AnkiConnectRequest<T: Encodable>: Encodable {
    let action: String
    let version: Int
    let params: T?

    init(action: String, version: Int, params: T? = nil) {
        self.action = action
        self.version = version
        self.params = params
    }
}

extension AnkiConnectRequest where T == EmptyParams {
    init(action: String, version: Int) {
        self.action = action
        self.version = version
        self.params = nil
    }
}

/// Empty params placeholder
private struct EmptyParams: Encodable {}

/// Parameters for cardReviews action
private struct CardReviewsParams: Encodable {
    let deck: String
    let startID: Int
}

/// AnkiConnect response structure
private struct AnkiConnectResponse<T: Decodable>: Decodable {
    let result: T?
    let error: String?
}

/// Internal model for card review data
private struct AnkiCardReview {
    let date: Date
    let durationSeconds: Int
    let isCorrect: Bool
    let isNewCard: Bool
}
