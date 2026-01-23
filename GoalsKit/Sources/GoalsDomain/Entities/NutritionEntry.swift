import Foundation

/// Source of nutrition data analysis
public enum NutritionAnalysisSource: String, Sendable, Equatable, Codable {
    /// Analyzed by Gemini VLM
    case gemini

    /// Manually entered by user
    case manual
}

/// Confidence level of Gemini analysis
public enum NutritionConfidence: String, Sendable, Equatable, Codable, CaseIterable {
    /// High confidence - clear nutrition label or well-known food
    case high

    /// Medium confidence - reasonable estimate based on visible food
    case medium

    /// Low confidence - significant uncertainty in identification or portion
    case low

    /// Unable to identify - could not analyze the image
    case unableToIdentify = "unable_to_identify"
}

/// A single nutrition entry representing one logged meal or food item
public struct NutritionEntry: Sendable, Equatable, Codable, Identifiable {
    public let id: UUID

    /// Date when this entry was logged
    public let date: Date

    /// Photo asset ID from PhotoKit (PHAsset.localIdentifier)
    public let photoAssetId: String

    /// Thumbnail image data (JPEG, ~200px) for fast display without Photo Library access
    public let thumbnailData: Data?

    /// Name/description of the food
    public var name: String

    /// Portion multiplier (default 1.0, allows 0.5x, 1.5x, 2x adjustments)
    public var portionMultiplier: Double

    /// Base nutrient values (before portion multiplier)
    public var baseNutrients: NutrientValues

    /// Source of the nutrition analysis
    public let source: NutritionAnalysisSource

    /// Confidence level of the analysis (only for Gemini source)
    public let confidence: NutritionConfidence?

    /// Whether a nutrition label was detected in the image
    public let hasNutritionLabel: Bool

    /// Timestamp when this entry was created
    public let createdAt: Date

    /// Timestamp when this entry was last modified
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        photoAssetId: String,
        thumbnailData: Data? = nil,
        name: String,
        portionMultiplier: Double = 1.0,
        baseNutrients: NutrientValues,
        source: NutritionAnalysisSource,
        confidence: NutritionConfidence? = nil,
        hasNutritionLabel: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.photoAssetId = photoAssetId
        self.thumbnailData = thumbnailData
        self.name = name
        self.portionMultiplier = portionMultiplier
        self.baseNutrients = baseNutrients
        self.source = source
        self.confidence = confidence
        self.hasNutritionLabel = hasNutritionLabel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Effective nutrient values after applying portion multiplier
    public var effectiveNutrients: NutrientValues {
        baseNutrients.multiplied(by: portionMultiplier)
    }
}

// MARK: - Portion Multiplier Presets

extension NutritionEntry {
    /// Common portion multiplier presets
    public static let portionPresets: [Double] = [0.5, 1.0, 1.5, 2.0]

    /// Formats a portion multiplier for display
    /// - Parameter value: The portion multiplier value
    /// - Returns: A formatted string like "½", "1x", "1½x", or "2x"
    public static func formatMultiplier(_ value: Double) -> String {
        if value == 1.0 {
            return "1x"
        } else if value == 0.5 {
            return "½"
        } else if value == 1.5 {
            return "1½x"
        } else {
            return "\(Int(value))x"
        }
    }
}
