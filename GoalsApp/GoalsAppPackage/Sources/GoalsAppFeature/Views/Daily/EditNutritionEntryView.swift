import SwiftUI
import GoalsDomain
import GoalsWidgetShared

/// View for editing an existing nutrition entry
struct EditNutritionEntryView: View {
    let entry: NutritionEntry
    let onSave: (NutritionEntry) -> Void
    let onCancel: () -> Void

    // Per-meal macro targets in grams (daily targets / 3 meals)
    private let mealMacroTargets = (protein: 50.0, carbs: 83.0, fat: 22.0)

    @State private var name: String
    @State private var portionMultiplier: Double
    @State private var calories: String
    @State private var protein: String
    @State private var carbohydrates: String
    @State private var fat: String
    @State private var fiber: String
    @State private var sugar: String
    @State private var sodium: String

    init(
        entry: NutritionEntry,
        onSave: @escaping (NutritionEntry) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.entry = entry
        self.onSave = onSave
        self.onCancel = onCancel

        self._name = State(initialValue: entry.name)
        self._portionMultiplier = State(initialValue: entry.portionMultiplier)
        self._calories = State(initialValue: String(format: "%.0f", entry.baseNutrients.calories))
        self._protein = State(initialValue: String(format: "%.1f", entry.baseNutrients.protein))
        self._carbohydrates = State(initialValue: String(format: "%.1f", entry.baseNutrients.carbohydrates))
        self._fat = State(initialValue: String(format: "%.1f", entry.baseNutrients.fat))
        self._fiber = State(initialValue: String(format: "%.1f", entry.baseNutrients.fiber))
        self._sugar = State(initialValue: String(format: "%.1f", entry.baseNutrients.sugar))
        self._sodium = State(initialValue: String(format: "%.0f", entry.baseNutrients.sodium))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                }

                Section("Portion Size") {
                    Picker("Portion", selection: $portionMultiplier) {
                        ForEach(NutritionEntry.portionPresets, id: \.self) { preset in
                            Text(NutritionEntry.formatMultiplier(preset)).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Macronutrients") {
                    NutritionTextField(label: "Calories", value: $calories, unit: "kcal")
                    NutritionTextField(label: "Protein", value: $protein, unit: "g")
                    NutritionTextField(label: "Carbohydrates", value: $carbohydrates, unit: "g")
                    NutritionTextField(label: "Fat", value: $fat, unit: "g")
                }

                Section {
                    MacroRadarChart(
                        current: (
                            (Double(protein) ?? 0) * portionMultiplier,
                            (Double(carbohydrates) ?? 0) * portionMultiplier,
                            (Double(fat) ?? 0) * portionMultiplier
                        ),
                        ideal: mealMacroTargets
                    )
                    .frame(height: 180)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                Section("Additional") {
                    NutritionTextField(label: "Fiber", value: $fiber, unit: "g")
                    NutritionTextField(label: "Sugar", value: $sugar, unit: "g")
                    NutritionTextField(label: "Sodium", value: $sodium, unit: "mg")
                }

                if entry.source == .gemini, let confidence = entry.confidence {
                    Section("Analysis Info") {
                        HStack {
                            Text("Source")
                            Spacer()
                            Text("Gemini AI")
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Confidence")
                            Spacer()
                            Text(confidence.rawValue.capitalized)
                                .foregroundStyle(.secondary)
                        }
                        if entry.hasNutritionLabel {
                            HStack {
                                Text("From Label")
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Entry")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEntry()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func saveEntry() {
        let baseNutrients = NutrientValues(
            calories: Double(calories) ?? entry.baseNutrients.calories,
            protein: Double(protein) ?? entry.baseNutrients.protein,
            carbohydrates: Double(carbohydrates) ?? entry.baseNutrients.carbohydrates,
            fat: Double(fat) ?? entry.baseNutrients.fat,
            fiber: Double(fiber) ?? entry.baseNutrients.fiber,
            sugar: Double(sugar) ?? entry.baseNutrients.sugar,
            sodium: Double(sodium) ?? entry.baseNutrients.sodium,
            vitaminA: entry.baseNutrients.vitaminA,
            vitaminC: entry.baseNutrients.vitaminC,
            vitaminD: entry.baseNutrients.vitaminD,
            calcium: entry.baseNutrients.calcium,
            iron: entry.baseNutrients.iron,
            potassium: entry.baseNutrients.potassium
        )

        var updatedEntry = entry
        updatedEntry.name = name
        updatedEntry.portionMultiplier = portionMultiplier
        updatedEntry.baseNutrients = baseNutrients
        updatedEntry.updatedAt = Date()

        onSave(updatedEntry)
    }
}

/// TextField for nutrition values with label and unit
private struct NutritionTextField: View {
    let label: String
    @Binding var value: String
    let unit: String

    var body: some View {
        HStack {
            Text(label)

            Spacer()

            TextField("0", text: $value)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .multilineTextAlignment(.trailing)
                .frame(width: 80)

            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
        }
    }
}
