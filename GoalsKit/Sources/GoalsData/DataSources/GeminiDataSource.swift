import Foundation
import GoalsDomain

#if canImport(UIKit)
import UIKit
#endif

/// Error types specific to Gemini API operations
public enum GeminiError: Error, Sendable {
    /// No API key configured
    case notConfigured

    /// Invalid or expired API key
    case invalidAPIKey

    /// Rate limit exceeded (free tier: 15 RPM)
    case rateLimited(retryAfterSeconds: Int?)

    /// Unable to identify food in the image
    case unableToIdentify

    /// Network request failed
    case networkError(String)

    /// Failed to parse response
    case parseError(String)

    /// General API error with message
    case apiError(String)
}

/// Result of Gemini food analysis
public struct GeminiFoodAnalysisResult: Sendable, Equatable, Codable {
    /// Name/description of the identified food
    public let name: String

    /// Confidence level of the analysis
    public let confidence: NutritionConfidence

    /// Whether a nutrition label was detected
    public let hasNutritionLabel: Bool

    /// Analyzed nutrient values
    public let nutrients: NutrientValues

    public init(
        name: String,
        confidence: NutritionConfidence,
        hasNutritionLabel: Bool,
        nutrients: NutrientValues
    ) {
        self.name = name
        self.confidence = confidence
        self.hasNutritionLabel = hasNutritionLabel
        self.nutrients = nutrients
    }
}

/// Data source for analyzing food photos using Gemini Flash VLM
public actor GeminiDataSource {
    private var apiKey: String?
    private var lastRequestTime: Date?
    private let urlSession: URLSession
    private let minimumRequestInterval: TimeInterval = 4.0 // Free tier: 15 RPM

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

    public init(urlSession: URLSession? = nil) {
        if let urlSession = urlSession {
            self.urlSession = urlSession
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 60
            config.timeoutIntervalForResource = 120
            self.urlSession = URLSession(configuration: config)
        }
    }

    /// Configure with API key
    public func configure(apiKey: String) {
        self.apiKey = apiKey
        print("[GeminiDataSource] Configured with API key (\(apiKey.count) chars)")
    }

    /// Check if configured
    public func isConfigured() -> Bool {
        let configured = apiKey != nil && !(apiKey?.isEmpty ?? true)
        print("[GeminiDataSource] isConfigured: \(configured)")
        return configured
    }

    /// Clear configuration
    public func clearConfiguration() {
        apiKey = nil
    }

    /// Analyze a food photo and return nutrition estimates
    /// - Parameter imageData: JPEG or PNG image data
    /// - Returns: Analysis result with food name and nutrition values
    public func analyzeFood(imageData: Data) async throws -> GeminiFoodAnalysisResult {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            print("[GeminiDataSource] ERROR: API key not configured")
            throw GeminiError.notConfigured
        }

        print("[GeminiDataSource] Starting food analysis...")
        print("[GeminiDataSource] API key length: \(apiKey.count) chars")
        print("[GeminiDataSource] Original image size: \(imageData.count) bytes")

        // Rate limiting for free tier
        try await enforceRateLimit()

        // Resize large images to reduce token usage and avoid TPM limits
        let processedImageData = resizeImageIfNeeded(imageData, maxDimension: 1024)
        print("[GeminiDataSource] Processed image size: \(processedImageData.count) bytes")

        let request = try buildRequest(imageData: processedImageData, apiKey: apiKey)
        print("[GeminiDataSource] Sending request to: \(request.url?.absoluteString ?? "nil")")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[GeminiDataSource] ERROR: Invalid response type")
            throw GeminiError.networkError("Invalid response type")
        }

        print("[GeminiDataSource] Response status: \(httpResponse.statusCode)")

        // Handle specific status codes
        switch httpResponse.statusCode {
        case 200...299:
            print("[GeminiDataSource] Success!")
            break
        case 401, 403:
            let message = String(data: data, encoding: .utf8) ?? "No message"
            print("[GeminiDataSource] ERROR: Invalid API key. Response: \(message)")
            throw GeminiError.invalidAPIKey
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Int($0) }
            let message = String(data: data, encoding: .utf8) ?? "No message"
            print("[GeminiDataSource] ERROR: Rate limited. Retry after: \(retryAfter ?? -1)s. Response: \(message)")
            throw GeminiError.rateLimited(retryAfterSeconds: retryAfter)
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[GeminiDataSource] ERROR: HTTP \(httpResponse.statusCode): \(message)")
            throw GeminiError.apiError("HTTP \(httpResponse.statusCode): \(message)")
        }

        return try parseResponse(data: data)
    }

    // MARK: - Private Helpers

    private func enforceRateLimit() async throws {
        if let lastRequest = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastRequest)
            if elapsed < minimumRequestInterval {
                let delay = minimumRequestInterval - elapsed
                try await Task.sleep(for: .seconds(delay))
            }
        }
        lastRequestTime = Date()
    }

    private func buildRequest(imageData: Data, apiKey: String) throws -> URLRequest {
        guard var urlComponents = URLComponents(string: baseURL) else {
            throw GeminiError.networkError("Invalid URL")
        }
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        guard let url = urlComponents.url else {
            throw GeminiError.networkError("Failed to build URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let base64Image = imageData.base64EncodedString()
        let mimeType = detectMimeType(imageData: imageData)

        let prompt = buildAnalysisPrompt()

        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(parts: [
                    GeminiPart(text: prompt, inlineData: nil),
                    GeminiPart(text: nil, inlineData: GeminiInlineData(mimeType: mimeType, data: base64Image))
                ])
            ],
            generationConfig: GeminiGenerationConfig(
                responseMimeType: "application/json",
                responseSchema: buildResponseSchema()
            )
        )

        request.httpBody = try JSONEncoder().encode(requestBody)
        return request
    }

    private func buildAnalysisPrompt() -> String {
        """
        Analyze this food image and provide nutrition information.

        Instructions:
        1. If a nutrition label is visible in the image:
           - Extract values directly from the label
           - Translate values if not in English
           - Set hasNutritionLabel to true
           - Set confidence to "high"

        2. If no nutrition label is visible:
           - Identify the food items in the image
           - Estimate portion sizes based on visual cues
           - Calculate total nutrition based on standard food databases
           - Set hasNutritionLabel to false
           - Set confidence based on how identifiable the food is:
             - "high": Well-known, clearly visible food
             - "medium": Recognizable food with some uncertainty in portions
             - "low": Uncertain identification or portion estimation
             - "unable_to_identify": Cannot identify food in image

        3. Provide all values for a single serving as shown in the image.

        Return a JSON object with the nutrition analysis.
        """
    }

    private func buildResponseSchema() -> GeminiResponseSchema {
        GeminiResponseSchema(
            type: "object",
            properties: [
                "name": SchemaProperty(type: "string", description: "Name/description of the food"),
                "confidence": SchemaProperty(type: "string", description: "Confidence level: high, medium, low, or unable_to_identify", enumValues: ["high", "medium", "low", "unable_to_identify"]),
                "hasNutritionLabel": SchemaProperty(type: "boolean", description: "Whether a nutrition label was detected"),
                "calories": SchemaProperty(type: "number", description: "Calories in kcal"),
                "protein": SchemaProperty(type: "number", description: "Protein in grams"),
                "carbohydrates": SchemaProperty(type: "number", description: "Carbohydrates in grams"),
                "fat": SchemaProperty(type: "number", description: "Fat in grams"),
                "fiber": SchemaProperty(type: "number", description: "Fiber in grams"),
                "sugar": SchemaProperty(type: "number", description: "Sugar in grams"),
                "sodium": SchemaProperty(type: "number", description: "Sodium in milligrams"),
                "vitaminA": SchemaProperty(type: "number", description: "Vitamin A as % daily value (optional)"),
                "vitaminC": SchemaProperty(type: "number", description: "Vitamin C as % daily value (optional)"),
                "vitaminD": SchemaProperty(type: "number", description: "Vitamin D as % daily value (optional)"),
                "calcium": SchemaProperty(type: "number", description: "Calcium as % daily value (optional)"),
                "iron": SchemaProperty(type: "number", description: "Iron as % daily value (optional)"),
                "potassium": SchemaProperty(type: "number", description: "Potassium in milligrams (optional)")
            ],
            required: ["name", "confidence", "hasNutritionLabel", "calories", "protein", "carbohydrates", "fat", "fiber", "sugar", "sodium"]
        )
    }

    private func detectMimeType(imageData: Data) -> String {
        guard imageData.count >= 4 else { return "image/jpeg" }
        let bytes = [UInt8](imageData.prefix(4))
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "image/png"
        }
        return "image/jpeg"
    }

    /// Resize image if it exceeds the maximum dimension to reduce API token usage
    /// - Parameters:
    ///   - imageData: Original image data
    ///   - maxDimension: Maximum width or height in pixels
    /// - Returns: Resized image data as JPEG, or original data if resizing fails/not needed
    private func resizeImageIfNeeded(_ imageData: Data, maxDimension: CGFloat) -> Data {
        #if canImport(UIKit) && !os(watchOS)
        guard let image = UIImage(data: imageData) else {
            return imageData
        }

        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else {
            return imageData
        }

        // Calculate new size maintaining aspect ratio
        let scale: CGFloat
        if size.width > size.height {
            scale = maxDimension / size.width
        } else {
            scale = maxDimension / size.height
        }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        // Resize the image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        // Return as JPEG with 0.8 quality
        return resizedImage.jpegData(compressionQuality: 0.8) ?? imageData
        #else
        // On platforms without UIKit, return original data
        return imageData
        #endif
    }

    private func parseResponse(data: Data) throws -> GeminiFoodAnalysisResult {
        print("[GeminiDataSource] Parsing response (\(data.count) bytes)")

        let response: GeminiResponse
        do {
            response = try JSONDecoder().decode(GeminiResponse.self, from: data)
        } catch {
            let rawResponse = String(data: data, encoding: .utf8) ?? "Unable to decode"
            print("[GeminiDataSource] ERROR: Failed to decode response: \(error)")
            print("[GeminiDataSource] Raw response: \(rawResponse.prefix(500))")
            throw GeminiError.parseError("Failed to decode response: \(error.localizedDescription)")
        }

        guard let candidate = response.candidates?.first,
              let part = candidate.content?.parts?.first,
              let jsonText = part.text else {
            let rawResponse = String(data: data, encoding: .utf8) ?? "Unable to decode"
            print("[GeminiDataSource] ERROR: No content in response. Raw: \(rawResponse.prefix(500))")
            throw GeminiError.parseError("No content in response")
        }

        print("[GeminiDataSource] Got JSON text: \(jsonText.prefix(200))...")

        // Parse the JSON text from Gemini's response
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw GeminiError.parseError("Failed to convert response to data")
        }

        let analysisResult: GeminiAnalysisResult
        do {
            analysisResult = try JSONDecoder().decode(GeminiAnalysisResult.self, from: jsonData)
        } catch {
            print("[GeminiDataSource] ERROR: Failed to decode analysis result: \(error)")
            print("[GeminiDataSource] JSON text was: \(jsonText)")
            throw GeminiError.parseError("Failed to decode analysis: \(error.localizedDescription)")
        }

        // Check for unable to identify
        let confidence = NutritionConfidence(rawValue: analysisResult.confidence) ?? .low
        if confidence == .unableToIdentify {
            throw GeminiError.unableToIdentify
        }

        let nutrients = NutrientValues(
            calories: analysisResult.calories,
            protein: analysisResult.protein,
            carbohydrates: analysisResult.carbohydrates,
            fat: analysisResult.fat,
            fiber: analysisResult.fiber,
            sugar: analysisResult.sugar,
            sodium: analysisResult.sodium,
            vitaminA: analysisResult.vitaminA,
            vitaminC: analysisResult.vitaminC,
            vitaminD: analysisResult.vitaminD,
            calcium: analysisResult.calcium,
            iron: analysisResult.iron,
            potassium: analysisResult.potassium
        )

        return GeminiFoodAnalysisResult(
            name: analysisResult.name,
            confidence: confidence,
            hasNutritionLabel: analysisResult.hasNutritionLabel,
            nutrients: nutrients
        )
    }
}

// MARK: - Request Models

private struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

private struct GeminiContent: Encodable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Encodable {
    let text: String?
    let inlineData: GeminiInlineData?

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let text = text {
            try container.encode(text, forKey: .text)
        }
        if let inlineData = inlineData {
            try container.encode(inlineData, forKey: .inlineData)
        }
    }
}

private struct GeminiInlineData: Encodable {
    let mimeType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

private struct GeminiGenerationConfig: Encodable {
    let responseMimeType: String
    let responseSchema: GeminiResponseSchema
}

private struct GeminiResponseSchema: Encodable {
    let type: String
    let properties: [String: SchemaProperty]
    let required: [String]
}

private struct SchemaProperty: Encodable {
    let type: String
    let description: String
    var enumValues: [String]?

    enum CodingKeys: String, CodingKey {
        case type, description
        case enumValues = "enum"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(description, forKey: .description)
        if let enumValues = enumValues {
            try container.encode(enumValues, forKey: .enumValues)
        }
    }
}

// MARK: - Response Models

private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]?
}

private struct GeminiCandidate: Decodable {
    let content: GeminiResponseContent?
}

private struct GeminiResponseContent: Decodable {
    let parts: [GeminiResponsePart]?
}

private struct GeminiResponsePart: Decodable {
    let text: String?
}

private struct GeminiAnalysisResult: Decodable {
    let name: String
    let confidence: String
    let hasNutritionLabel: Bool
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let sodium: Double
    let vitaminA: Double?
    let vitaminC: Double?
    let vitaminD: Double?
    let calcium: Double?
    let iron: Double?
    let potassium: Double?
}
