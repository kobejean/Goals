import Foundation

/// Comprehensive nutrient values for food items
/// Supports macros, fiber, sugar, sodium, and optional micronutrients
public struct NutrientValues: Sendable, Equatable, Codable {
    // MARK: - Macronutrients (required)

    /// Calories in kcal
    public var calories: Double

    /// Protein in grams
    public var protein: Double

    /// Carbohydrates in grams
    public var carbohydrates: Double

    /// Fat in grams
    public var fat: Double

    // MARK: - Additional Required Nutrients

    /// Fiber in grams
    public var fiber: Double

    /// Sugar in grams
    public var sugar: Double

    /// Sodium in milligrams
    public var sodium: Double

    // MARK: - Micronutrients (optional, as percentage of daily value)

    /// Vitamin A as percentage of daily value
    public var vitaminA: Double?

    /// Vitamin C as percentage of daily value
    public var vitaminC: Double?

    /// Vitamin D as percentage of daily value
    public var vitaminD: Double?

    /// Calcium as percentage of daily value
    public var calcium: Double?

    /// Iron as percentage of daily value
    public var iron: Double?

    /// Potassium in milligrams
    public var potassium: Double?

    public init(
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
        potassium: Double? = nil
    ) {
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
    }

    /// Returns a new NutrientValues with all values multiplied by the given factor
    public func multiplied(by factor: Double) -> NutrientValues {
        NutrientValues(
            calories: calories * factor,
            protein: protein * factor,
            carbohydrates: carbohydrates * factor,
            fat: fat * factor,
            fiber: fiber * factor,
            sugar: sugar * factor,
            sodium: sodium * factor,
            vitaminA: vitaminA.map { $0 * factor },
            vitaminC: vitaminC.map { $0 * factor },
            vitaminD: vitaminD.map { $0 * factor },
            calcium: calcium.map { $0 * factor },
            iron: iron.map { $0 * factor },
            potassium: potassium.map { $0 * factor }
        )
    }

    /// Returns a new NutrientValues with all values divided by the given divisor
    public func divided(by divisor: Double) -> NutrientValues {
        guard divisor != 0 else { return self }
        return multiplied(by: 1.0 / divisor)
    }

    /// Zero nutrients for empty state
    public static let zero = NutrientValues()
}

// MARK: - Arithmetic Operators

extension NutrientValues {
    /// Adds two NutrientValues together
    public static func + (lhs: NutrientValues, rhs: NutrientValues) -> NutrientValues {
        NutrientValues(
            calories: lhs.calories + rhs.calories,
            protein: lhs.protein + rhs.protein,
            carbohydrates: lhs.carbohydrates + rhs.carbohydrates,
            fat: lhs.fat + rhs.fat,
            fiber: lhs.fiber + rhs.fiber,
            sugar: lhs.sugar + rhs.sugar,
            sodium: lhs.sodium + rhs.sodium,
            vitaminA: addOptional(lhs.vitaminA, rhs.vitaminA),
            vitaminC: addOptional(lhs.vitaminC, rhs.vitaminC),
            vitaminD: addOptional(lhs.vitaminD, rhs.vitaminD),
            calcium: addOptional(lhs.calcium, rhs.calcium),
            iron: addOptional(lhs.iron, rhs.iron),
            potassium: addOptional(lhs.potassium, rhs.potassium)
        )
    }

    /// Helper for adding optional values
    private static func addOptional(_ lhs: Double?, _ rhs: Double?) -> Double? {
        switch (lhs, rhs) {
        case let (l?, r?): return l + r
        case let (l?, nil): return l
        case let (nil, r?): return r
        case (nil, nil): return nil
        }
    }
}

// MARK: - Computed Properties

extension NutrientValues {
    /// Total macros in grams (protein + carbs + fat)
    public var totalMacrosGrams: Double {
        protein + carbohydrates + fat
    }

    /// Protein ratio (0-1) relative to total macros
    public var proteinRatio: Double {
        guard totalMacrosGrams > 0 else { return 0 }
        return protein / totalMacrosGrams
    }

    /// Carbohydrate ratio (0-1) relative to total macros
    public var carbsRatio: Double {
        guard totalMacrosGrams > 0 else { return 0 }
        return carbohydrates / totalMacrosGrams
    }

    /// Fat ratio (0-1) relative to total macros
    public var fatRatio: Double {
        guard totalMacrosGrams > 0 else { return 0 }
        return fat / totalMacrosGrams
    }
}
