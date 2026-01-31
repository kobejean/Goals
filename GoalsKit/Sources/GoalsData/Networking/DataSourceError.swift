import Foundation

/// Errors that can occur with data sources
public enum DataSourceError: Error, Sendable {
    case notConfigured
    case invalidConfiguration
    case missingCredentials
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case parseError(String)
    case connectionFailed(String)
    case unauthorized  // 401/403 - invalid API key or permissions
    case rateLimited   // 429 - rate limit exceeded
}
