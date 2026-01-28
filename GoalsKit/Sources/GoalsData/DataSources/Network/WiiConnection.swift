import Foundation
import Network
import GoalsDomain

/// Actor for TCP communication with the Wii Fit Sync homebrew app
public actor WiiConnection {
    /// Default TCP port for Wii Fit Sync
    public static let defaultPort: UInt16 = 8888

    /// Connection timeout in seconds
    public static let connectionTimeout: TimeInterval = 10

    /// Receive timeout in seconds
    public static let receiveTimeout: TimeInterval = 30

    // MARK: - Response Models

    /// Response from the Wii Fit Sync app
    struct SyncResponse: Codable {
        let version: Int
        let profiles: [ProfileData]?
        let error: ErrorData?

        struct ProfileData: Codable {
            let name: String
            let height_cm: Int
            let dob: String
            let measurements: [MeasurementData]
            let activities: [ActivityData]
        }

        struct MeasurementData: Codable {
            let date: String
            let weight_kg: Double
            let bmi: Double
            let balance_percent: Double
        }

        struct ActivityData: Codable {
            let date: String
            let type: String
            let name: String
            let duration_min: Int
            let calories: Int
            let score: Int
        }

        struct ErrorData: Codable {
            let code: Int
            let message: String
        }
    }

    /// Request to send to the Wii
    struct SyncRequest: Codable {
        let action: String
    }

    // MARK: - Public API

    /// Tests if a Wii is reachable at the given IP address
    /// - Parameters:
    ///   - ipAddress: IP address of the Wii
    ///   - port: TCP port (default 8888)
    /// - Returns: true if connection successful
    public func testConnection(ipAddress: String, port: UInt16 = defaultPort) async throws -> Bool {
        let connection = try await connect(to: ipAddress, port: port)
        defer { connection.cancel() }

        // Send a simple sync request and check for valid response
        let request = SyncRequest(action: "sync")
        let requestData = try JSONEncoder().encode(request)

        try await send(data: requestData, on: connection)

        let responseData = try await receive(on: connection)
        let response = try JSONDecoder().decode(SyncResponse.self, from: responseData)

        // Send acknowledgment
        let ackRequest = SyncRequest(action: "ack")
        let ackData = try JSONEncoder().encode(ackRequest)
        try? await send(data: ackData, on: connection)

        // Connection is valid if we got a version 2 response
        return response.version == 2
    }

    /// Syncs data from a Wii running the homebrew app
    /// - Parameters:
    ///   - ipAddress: IP address of the Wii
    ///   - port: TCP port (default 8888)
    /// - Returns: Parsed sync result
    public func sync(ipAddress: String, port: UInt16 = defaultPort) async throws -> WiiFitSyncResult {
        let connection = try await connect(to: ipAddress, port: port)
        defer { connection.cancel() }

        // Send sync request
        let request = SyncRequest(action: "sync")
        let requestData = try JSONEncoder().encode(request)

        try await send(data: requestData, on: connection)

        // Receive response
        let responseData = try await receive(on: connection)
        let response = try JSONDecoder().decode(SyncResponse.self, from: responseData)

        // Send acknowledgment
        let ackRequest = SyncRequest(action: "ack")
        let ackData = try JSONEncoder().encode(ackRequest)
        try? await send(data: ackData, on: connection)

        // Check for error
        if let error = response.error {
            throw WiiConnectionError.serverError(code: error.code, message: error.message)
        }

        // Parse response
        return parseResponse(response)
    }

    // MARK: - Private Implementation

    private func connect(to ipAddress: String, port: UInt16) async throws -> NWConnection {
        let host = NWEndpoint.Host(ipAddress)

        let port = NWEndpoint.Port(integerLiteral: port)
        let connection = NWConnection(host: host, port: port, using: .tcp)

        return try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume(returning: connection)
                case .failed(let error):
                    continuation.resume(throwing: WiiConnectionError.connectionFailed(error.localizedDescription))
                case .cancelled:
                    continuation.resume(throwing: WiiConnectionError.cancelled)
                default:
                    break
                }
            }

            connection.start(queue: .global())

            // Timeout
            Task {
                try await Task.sleep(for: .seconds(Self.connectionTimeout))
                if connection.state != .ready {
                    connection.cancel()
                }
            }
        }
    }

    private func send(data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: WiiConnectionError.sendFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func receive(on connection: NWConnection) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            // Receive with a larger buffer for JSON data
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { content, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: WiiConnectionError.receiveFailed(error.localizedDescription))
                    return
                }

                guard let data = content, !data.isEmpty else {
                    if isComplete {
                        continuation.resume(throwing: WiiConnectionError.connectionClosed)
                    } else {
                        continuation.resume(throwing: WiiConnectionError.noData)
                    }
                    return
                }

                continuation.resume(returning: data)
            }

            // Timeout
            Task {
                try await Task.sleep(for: .seconds(Self.receiveTimeout))
            }
        }
    }

    private func parseResponse(_ response: SyncResponse) -> WiiFitSyncResult {
        var measurements: [WiiFitMeasurement] = []
        var activities: [WiiFitActivity] = []
        var profiles: [WiiFitProfileInfo] = []

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Also try without fractional seconds
        let dateFormatterSimple = DateFormatter()
        dateFormatterSimple.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        func parseDate(_ string: String) -> Date? {
            dateFormatter.date(from: string) ?? dateFormatterSimple.date(from: string)
        }

        for profile in response.profiles ?? [] {
            // Parse measurements
            for m in profile.measurements {
                if let date = parseDate(m.date) {
                    measurements.append(WiiFitMeasurement(
                        date: date,
                        weightKg: m.weight_kg,
                        bmi: m.bmi,
                        balancePercent: m.balance_percent,
                        profileName: profile.name
                    ))
                }
            }

            // Parse activities
            for a in profile.activities {
                if let date = parseDate(a.date) {
                    activities.append(WiiFitActivity(
                        date: date,
                        activityType: WiiFitActivityType(rawValue: a.type) ?? .training,
                        name: a.name,
                        durationMinutes: a.duration_min,
                        caloriesBurned: a.calories,
                        score: a.score,
                        profileName: profile.name
                    ))
                }
            }

            // Profile info
            profiles.append(WiiFitProfileInfo(
                name: profile.name,
                heightCm: profile.height_cm,
                measurementCount: profile.measurements.count,
                activityCount: profile.activities.count
            ))
        }

        return WiiFitSyncResult(
            measurements: measurements,
            activities: activities,
            profilesFound: profiles
        )
    }
}

// MARK: - Errors

/// Errors that can occur during Wii connection
public enum WiiConnectionError: Error, LocalizedError {
    case invalidAddress
    case connectionFailed(String)
    case sendFailed(String)
    case receiveFailed(String)
    case connectionClosed
    case noData
    case cancelled
    case serverError(code: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "Invalid IP address"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .sendFailed(let reason):
            return "Send failed: \(reason)"
        case .receiveFailed(let reason):
            return "Receive failed: \(reason)"
        case .connectionClosed:
            return "Connection was closed by the Wii"
        case .noData:
            return "No data received"
        case .cancelled:
            return "Connection was cancelled"
        case .serverError(let code, let message):
            return "Wii error (\(code)): \(message)"
        }
    }
}
