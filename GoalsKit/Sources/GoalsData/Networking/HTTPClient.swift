import Foundation

/// Lightweight HTTP client for making network requests
public actor HTTPClient {
    private let urlSession: URLSession

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    /// Performs a GET request and decodes the response
    public func get<T: Decodable>(_ url: URL, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        let (data, response) = try await urlSession.data(from: url)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DataSourceError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw DataSourceError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    /// JSONDecoder configured for snake_case to camelCase conversion
    public static var snakeCaseDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
