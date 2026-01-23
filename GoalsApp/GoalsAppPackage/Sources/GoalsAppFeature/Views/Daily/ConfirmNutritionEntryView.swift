import SwiftUI
import GoalsDomain
import GoalsData

#if canImport(UIKit)
import UIKit
#endif

/// View for confirming and adjusting Gemini nutrition analysis before saving
struct ConfirmNutritionEntryView: View {
    let analysis: PendingNutritionAnalysis
    let onConfirm: (NutritionEntry) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var portionMultiplier: Double = 1.0

    init(
        analysis: PendingNutritionAnalysis,
        onConfirm: @escaping (NutritionEntry) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.analysis = analysis
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self._name = State(initialValue: analysis.analysisResult.name)
    }

    private var effectiveNutrients: NutrientValues {
        analysis.analysisResult.nutrients.multiplied(by: portionMultiplier)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Photo preview
                    #if canImport(UIKit)
                    if let uiImage = UIImage(data: analysis.imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    #endif

                    // Confidence indicator
                    confidenceIndicator

                    // Editable name
                    TextField("Food name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(.headline)

                    // Portion adjustment
                    portionAdjustmentSection

                    // Nutrition details
                    nutritionDetailsSection
                }
                .padding()
            }
            .navigationTitle("Confirm Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        confirmEntry()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var confidenceIndicator: some View {
        HStack {
            Image(systemName: confidenceIcon)
                .foregroundStyle(confidenceColor)

            Text(confidenceText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if analysis.analysisResult.hasNutritionLabel {
                Spacer()
                Label("From label", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(confidenceColor.opacity(0.1))
        )
    }

    private var confidenceIcon: String {
        switch analysis.analysisResult.confidence {
        case .high: return "checkmark.circle.fill"
        case .medium: return "questionmark.circle.fill"
        case .low: return "exclamationmark.circle.fill"
        case .unableToIdentify: return "xmark.circle.fill"
        }
    }

    private var confidenceColor: Color {
        switch analysis.analysisResult.confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        case .unableToIdentify: return .gray
        }
    }

    private var confidenceText: String {
        switch analysis.analysisResult.confidence {
        case .high: return "High confidence"
        case .medium: return "Medium confidence - verify values"
        case .low: return "Low confidence - values may be inaccurate"
        case .unableToIdentify: return "Unable to identify"
        }
    }

    private var portionAdjustmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Portion Size")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(NutritionEntry.portionPresets, id: \.self) { preset in
                    Button {
                        portionMultiplier = preset
                    } label: {
                        Text(NutritionEntry.formatMultiplier(preset))
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(portionMultiplier == preset ? Color.accentColor : Color.gray.opacity(0.15))
                            )
                            .foregroundStyle(portionMultiplier == preset ? .white : .primary)
                    }
                }
            }
        }
    }

    private var nutritionDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nutrition Facts")
                .font(.headline)

            VStack(spacing: 8) {
                NutritionRow(label: "Calories", value: "\(Int(effectiveNutrients.calories))", unit: "kcal", isHighlighted: true)

                Divider()

                NutritionRow(label: "Protein", value: String(format: "%.1f", effectiveNutrients.protein), unit: "g")
                NutritionRow(label: "Carbohydrates", value: String(format: "%.1f", effectiveNutrients.carbohydrates), unit: "g")
                NutritionRow(label: "Fat", value: String(format: "%.1f", effectiveNutrients.fat), unit: "g")

                Divider()

                NutritionRow(label: "Fiber", value: String(format: "%.1f", effectiveNutrients.fiber), unit: "g")
                NutritionRow(label: "Sugar", value: String(format: "%.1f", effectiveNutrients.sugar), unit: "g")
                NutritionRow(label: "Sodium", value: String(format: "%.0f", effectiveNutrients.sodium), unit: "mg")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.15))
            )

            // Optional micronutrients
            if hasMicronutrients {
                micronutrientsSection
            }
        }
    }

    private var hasMicronutrients: Bool {
        effectiveNutrients.vitaminA != nil ||
        effectiveNutrients.vitaminC != nil ||
        effectiveNutrients.vitaminD != nil ||
        effectiveNutrients.calcium != nil ||
        effectiveNutrients.iron != nil ||
        effectiveNutrients.potassium != nil
    }

    private var micronutrientsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vitamins & Minerals")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                if let vitA = effectiveNutrients.vitaminA {
                    NutritionRow(label: "Vitamin A", value: String(format: "%.0f", vitA), unit: "% DV")
                }
                if let vitC = effectiveNutrients.vitaminC {
                    NutritionRow(label: "Vitamin C", value: String(format: "%.0f", vitC), unit: "% DV")
                }
                if let vitD = effectiveNutrients.vitaminD {
                    NutritionRow(label: "Vitamin D", value: String(format: "%.0f", vitD), unit: "% DV")
                }
                if let calcium = effectiveNutrients.calcium {
                    NutritionRow(label: "Calcium", value: String(format: "%.0f", calcium), unit: "% DV")
                }
                if let iron = effectiveNutrients.iron {
                    NutritionRow(label: "Iron", value: String(format: "%.0f", iron), unit: "% DV")
                }
                if let potassium = effectiveNutrients.potassium {
                    NutritionRow(label: "Potassium", value: String(format: "%.0f", potassium), unit: "mg")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.15))
            )
        }
    }

    private func confirmEntry() {
        let entry = NutritionEntry(
            date: Date(),
            photoAssetId: analysis.photoAssetId,
            name: name,
            portionMultiplier: portionMultiplier,
            baseNutrients: analysis.analysisResult.nutrients,
            source: .gemini,
            confidence: analysis.analysisResult.confidence,
            hasNutritionLabel: analysis.analysisResult.hasNutritionLabel
        )
        onConfirm(entry)
    }
}

/// Row for displaying a nutrition value
private struct NutritionRow: View {
    let label: String
    let value: String
    let unit: String
    var isHighlighted: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(isHighlighted ? .headline : .subheadline)

            Spacer()

            Text("\(value) \(unit)")
                .font(isHighlighted ? .headline.monospacedDigit() : .subheadline.monospacedDigit())
                .foregroundStyle(isHighlighted ? .primary : .secondary)
        }
    }
}
