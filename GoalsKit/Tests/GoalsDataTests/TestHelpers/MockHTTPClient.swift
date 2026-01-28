import Foundation
@testable import GoalsData

/// Mock HTTP client for testing data sources
public actor MockHTTPClient {
    public var responses: [URL: Any] = [:]
    public var errors: [URL: Error] = [:]
    public var getCalls: [URL] = []

    public init() {}

    /// Sets a response for a specific URL pattern
    public func setResponse<T: Encodable>(_ response: T, for urlPattern: String) throws {
        guard let url = URL(string: urlPattern) else { return }
        responses[url] = response
    }

    /// Sets a response for any URL matching the host and path
    public func setAnyResponse<T: Encodable>(_ response: T) {
        // Store with a special key
        responses[URL(string: "mock://any")!] = response
    }

    /// Sets an error for a specific URL
    public func setError(_ error: Error, for urlPattern: String) {
        guard let url = URL(string: urlPattern) else { return }
        errors[url] = error
    }

    /// Performs a mock GET request
    public func get<T: Decodable>(_ url: URL, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        getCalls.append(url)

        // Check for error first
        if let error = errors[url] {
            throw error
        }

        // Check for specific URL response
        if let response = responses[url] as? T {
            return response
        }

        // Check for any response
        if let anyResponse = responses[URL(string: "mock://any")!] as? T {
            return anyResponse
        }

        // Try to find a matching host/path
        for (storedURL, response) in responses {
            if storedURL.host == url.host && storedURL.path == url.path {
                if let typedResponse = response as? T {
                    return typedResponse
                }
            }
        }

        throw MockHTTPError.noResponseConfigured(url: url)
    }
}

public enum MockHTTPError: Error, LocalizedError {
    case noResponseConfigured(url: URL)

    public var errorDescription: String? {
        switch self {
        case .noResponseConfigured(let url):
            return "No mock response configured for URL: \(url)"
        }
    }
}

// MARK: - Mock URLSession for Direct URLSession Usage

/// Mock URL protocol for testing URLSession-based requests
public final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) public static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    public override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    public override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: MockHTTPError.noResponseConfigured(url: request.url!))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    public override func stopLoading() {}
}

/// Creates a URLSession configured to use MockURLProtocol
public func createMockURLSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: configuration)
}
