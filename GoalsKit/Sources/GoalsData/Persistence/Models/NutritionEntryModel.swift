import Foundation
import SwiftData
import GoalsDomain

/// SwiftData model for persisting NutritionEntry entities
@Model
public final class NutritionEntryModel {
    public var id: UUID = UUID()
    public var date: Date = Date()
    public var photoAssetId: String = ""
    public var name: String = ""
    public var portionMultiplier: Double = 1.0

    // Base nutrients (before portion multiplier)
    public var calories: Double = 0
    public var protein: Double = 0
    public var carbohydrates: Double = 0
    public var fat: Double = 0
    public var fiber: Double = 0
    public var sugar: Double = 0
    public var sodium: Double = 0

    // Optional micronutrients
    public var vitaminA: Double?
    public var vitaminC: Double?
    public var vitaminD: Double?
    public var calcium: Double?
    public var iron: Double?
    public var potassium: Double?

    // Metadata
    public var sourceRaw: String = "gemini"
    public var confidenceRaw: String?
    public var hasNutritionLabel: Bool = false
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        photoAssetId: String,
        name: String,
        portionMultiplier: Double = 1.0,
        calories: Double = 0,
        protein: Double = 0,
        carbohydrates: Double = 0,
        fat: Double = 0,
        fiber: Double = 0,
        sugar: Double = 0,
        sodium: Double = 0,
        vitaminA: Double? = nil,
        vitaminC: Double? = nil,
        vitaminD: Double? = nil,
        calcium: Double? = nil,
        iron: Double? = nil,
        potassium: Double? = nil,
        sourceRaw: String = "gemini",
        confidenceRaw: String? = nil,
        hasNutritionLabel: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.photoAssetId = photoAssetId
        self.name = name
        self.portionMultiplier = portionMultiplier
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.sodium = sodium
        self.vitaminA = vitaminA
        self.vitaminC = vitaminC
        self.vitaminD = vitaminD
        self.calcium = calcium
        self.iron = iron
        self.potassium = potassium
        self.sourceRaw = sourceRaw
        self.confidenceRaw = confidenceRaw
        self.hasNutritionLabel = hasNutritionLabel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Domain Conversion

public extension NutritionEntryModel {
    /// Converts SwiftData model to domain entity
    func toDomain() -> NutritionEntry {
        let baseNutrients = NutrientValues(
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat,
            fiber: fiber,
            sugar: sugar,
            sodium: sodium,
            vitaminA: vitaminA,
            vitaminC: vitaminC,
            vitaminD: vitaminD,
            calcium: calcium,
            iron: iron,
            potassium: potassium
        )

        let source = NutritionAnalysisSource(rawValue: sourceRaw) ?? .gemini
        let confidence = confidenceRaw.flatMap { NutritionConfidence(rawValue: $0) }

        return NutritionEntry(
            id: id,
            date: date,
            photoAssetId: photoAssetId,
            name: name,
            portionMultiplier: portionMultiplier,
            baseNutrients: baseNutrients,
            source: source,
            confidence: confidence,
            hasNutritionLabel: hasNutritionLabel,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Creates SwiftData model from domain entity
    static func from(_ entry: NutritionEntry) -> NutritionEntryModel {
        NutritionEntryModel(
            id: entry.id,
            date: entry.date,
            photoAssetId: entry.photoAssetId,
            name: entry.name,
            portionMultiplier: entry.portionMultiplier,
            calories: entry.baseNutrients.calories,
            protein: entry.baseNutrients.protein,
            carbohydrates: entry.baseNutrients.carbohydrates,
            fat: entry.baseNutrients.fat,
            fiber: entry.baseNutrients.fiber,
            sugar: entry.baseNutrients.sugar,
            sodium: entry.baseNutrients.sodium,
            vitaminA: entry.baseNutrients.vitaminA,
            vitaminC: entry.baseNutrients.vitaminC,
            vitaminD: entry.baseNutrients.vitaminD,
            calcium: entry.baseNutrients.calcium,
            iron: entry.baseNutrients.iron,
            potassium: entry.baseNutrients.potassium,
            sourceRaw: entry.source.rawValue,
            confidenceRaw: entry.confidence?.rawValue,
            hasNutritionLabel: entry.hasNutritionLabel,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt
        )
    }

    /// Updates model from domain entity
    func update(from entry: NutritionEntry) {
        date = entry.date
        photoAssetId = entry.photoAssetId
        name = entry.name
        portionMultiplier = entry.portionMultiplier
        calories = entry.baseNutrients.calories
        protein = entry.baseNutrients.protein
        carbohydrates = entry.baseNutrients.carbohydrates
        fat = entry.baseNutrients.fat
        fiber = entry.baseNutrients.fiber
        sugar = entry.baseNutrients.sugar
        sodium = entry.baseNutrients.sodium
        vitaminA = entry.baseNutrients.vitaminA
        vitaminC = entry.baseNutrients.vitaminC
        vitaminD = entry.baseNutrients.vitaminD
        calcium = entry.baseNutrients.calcium
        iron = entry.baseNutrients.iron
        potassium = entry.baseNutrients.potassium
        updatedAt = Date()
    }
}
