import Foundation
import Network
import GoalsDomain

private extension UInt8 {
    var isWhitespace: Bool {
        self == 0x20 || self == 0x09 || self == 0x0A || self == 0x0D // space, tab, newline, carriage return
    }
}

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
        print("[WiiConnection] testConnection starting: \(ipAddress):\(port)")

        let connection = try await connect(to: ipAddress, port: port)
        print("[WiiConnection] Connected successfully")
        defer {
            print("[WiiConnection] Closing connection")
            connection.cancel()
        }

        // Send a simple sync request and check for valid response
        let request = SyncRequest(action: "sync")
        let requestData = try JSONEncoder().encode(request)
        print("[WiiConnection] Sending sync request: \(String(data: requestData, encoding: .utf8) ?? "?")")

        try await send(data: requestData, on: connection)
        print("[WiiConnection] Sync request sent, waiting for response...")

        let responseData = try await receive(on: connection)
        let responsePreview = String(data: responseData.prefix(200), encoding: .utf8) ?? "binary"
        let responseSuffix = String(data: responseData.suffix(100), encoding: .utf8) ?? "binary"
        print("[WiiConnection] Received \(responseData.count) bytes")
        print("[WiiConnection] Start: \(responsePreview)")
        print("[WiiConnection] End: \(responseSuffix)")

        let response: SyncResponse
        do {
            response = try JSONDecoder().decode(SyncResponse.self, from: responseData)
            print("[WiiConnection] Decoded response, version: \(response.version), profiles: \(response.profiles?.count ?? 0)")
        } catch {
            print("[WiiConnection] JSON decode error: \(error)")

            // Extract error position from the error message
            var errorPosition = responseData.count / 2  // Default to middle
            if let decodingError = error as? DecodingError,
               case .dataCorrupted(let context) = decodingError,
               let nsError = context.underlyingError as NSError?,
               let index = nsError.userInfo["NSJSONSerializationErrorIndex"] as? Int {
                errorPosition = index
            }

            let start = max(0, errorPosition - 60)
            let end = min(responseData.count, errorPosition + 60)
            if end > start {
                let debugSlice = responseData[start..<end]
                let debugStr = String(data: debugSlice, encoding: .utf8) ?? "binary"
                print("[WiiConnection] Around pos \(errorPosition): ...\(debugStr)...")
            }

            // Check for duplicate "version" strings
            if let str = String(data: responseData, encoding: .utf8) {
                var versionPositions: [Int] = []
                var searchStart = str.startIndex
                while let range = str.range(of: "\"version\"", range: searchStart..<str.endIndex) {
                    versionPositions.append(str.distance(from: str.startIndex, to: range.lowerBound))
                    searchStart = range.upperBound
                }
                print("[WiiConnection] 'version' positions: \(versionPositions)")
            }

            throw error
        }

        // Send acknowledgment
        let ackRequest = SyncRequest(action: "ack")
        let ackData = try JSONEncoder().encode(ackRequest)
        print("[WiiConnection] Sending ack")
        try? await send(data: ackData, on: connection)

        // Connection is valid if we got a version 2 response
        print("[WiiConnection] Test complete, version valid: \(response.version == 2)")
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
        print("[WiiConnection] Creating connection to \(ipAddress):\(port)")

        return try await withCheckedThrowingContinuation { continuation in
            let resumeGuard = ContinuationResumeGuard()

            connection.stateUpdateHandler = { [weak connection] state in
                print("[WiiConnection] State changed: \(state)")
                guard resumeGuard.tryResume() else {
                    print("[WiiConnection] Already resumed, ignoring state: \(state)")
                    return
                }

                switch state {
                case .ready:
                    print("[WiiConnection] Connection ready!")
                    connection?.stateUpdateHandler = nil
                    continuation.resume(returning: connection!)
                case .failed(let error):
                    print("[WiiConnection] Connection failed: \(error)")
                    connection?.stateUpdateHandler = nil
                    continuation.resume(throwing: WiiConnectionError.connectionFailed(error.localizedDescription))
                case .cancelled:
                    print("[WiiConnection] Connection cancelled")
                    connection?.stateUpdateHandler = nil
                    continuation.resume(throwing: WiiConnectionError.cancelled)
                default:
                    print("[WiiConnection] Intermediate state, resetting guard")
                    resumeGuard.reset()
                }
            }

            connection.start(queue: .global())

            // Timeout
            Task {
                try await Task.sleep(for: .seconds(Self.connectionTimeout))
                if resumeGuard.tryResume() {
                    print("[WiiConnection] Connection timeout!")
                    connection.stateUpdateHandler = nil
                    connection.cancel()
                    continuation.resume(throwing: WiiConnectionError.connectionFailed("Connection timeout"))
                }
            }
        }
    }

    private func send(data: Data, on connection: NWConnection) async throws {
        print("[WiiConnection] Sending \(data.count) bytes...")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    print("[WiiConnection] Send error: \(error)")
                    continuation.resume(throwing: WiiConnectionError.sendFailed(error.localizedDescription))
                } else {
                    print("[WiiConnection] Send completed")
                    continuation.resume()
                }
            })
        }
    }

    private func receive(on connection: NWConnection) async throws -> Data {
        print("[WiiConnection] Waiting to receive data...")

        var accumulatedData = Data()
        let startTime = Date()

        while true {
            let chunk = try await receiveChunk(on: connection)

            if let chunk = chunk {
                accumulatedData.append(chunk)
                print("[WiiConnection] Accumulated \(accumulatedData.count) bytes total")

                // Check if we have complete JSON (starts with { and ends with })
                if accumulatedData.first == UInt8(ascii: "{") {
                    if let lastNonWhitespace = accumulatedData.last(where: { !$0.isWhitespace }) {
                        if lastNonWhitespace == UInt8(ascii: "}") {
                            print("[WiiConnection] JSON appears complete")
                            return accumulatedData
                        }
                    }
                }
            }

            // Check timeout
            if Date().timeIntervalSince(startTime) > Self.receiveTimeout {
                print("[WiiConnection] Receive timeout after \(accumulatedData.count) bytes")
                if !accumulatedData.isEmpty {
                    return accumulatedData
                }
                throw WiiConnectionError.receiveFailed("Receive timeout")
            }

            // Small delay before next read attempt
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private func receiveChunk(on connection: NWConnection) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { content, context, isComplete, error in
                print("[WiiConnection] Receive callback: content=\(content?.count ?? 0) bytes, isComplete=\(isComplete), error=\(String(describing: error))")

                if let error = error {
                    print("[WiiConnection] Receive error: \(error)")
                    continuation.resume(throwing: WiiConnectionError.receiveFailed(error.localizedDescription))
                    return
                }

                if let data = content, !data.isEmpty {
                    print("[WiiConnection] Received chunk: \(data.count) bytes")
                    continuation.resume(returning: data)
                } else if isComplete {
                    print("[WiiConnection] Connection closed by remote")
                    continuation.resume(returning: nil)
                } else {
                    // No data yet but connection still open
                    continuation.resume(returning: Data())
                }
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
/// Thread-safe guard to ensure continuation is only resumed once
private final class ContinuationResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var hasResumed = false

    /// Attempts to claim the resume. Returns true if this is the first call, false otherwise.
    func tryResume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if hasResumed { return false }
        hasResumed = true
        return true
    }

    /// Resets the guard (used when state handler fires for non-terminal states)
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        hasResumed = false
    }
}

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
