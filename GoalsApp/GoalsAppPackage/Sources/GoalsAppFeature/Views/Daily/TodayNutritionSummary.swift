import SwiftUI
import GoalsDomain

/// Summary of today's nutrition entries with edit and delete actions
struct TodayNutritionSummary: View {
    let entries: [NutritionEntry]
    let onDelete: (NutritionEntry) async -> Void
    let onEdit: (NutritionEntry) -> Void
    let onUpdatePortion: (NutritionEntry, Double) async -> Void

    private var totalNutrients: NutrientValues {
        entries.reduce(.zero) { $0 + $1.effectiveNutrients }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with totals
            headerSection

            // Macro ratio card
            MacroRatioCard(nutrients: totalNutrients)

            // Entry list
            VStack(spacing: 8) {
                ForEach(entries) { entry in
                    NutritionEntryRow(
                        entry: entry,
                        onEdit: { onEdit(entry) },
                        onUpdatePortion: { multiplier in
                            Task {
                                await onUpdatePortion(entry, multiplier)
                            }
                        }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task {
                                await onDelete(entry)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today's Nutrition")
                    .font(.headline)

                Spacer()

                Text("\(Int(totalNutrients.calories)) kcal")
                    .font(.title2.weight(.semibold).monospacedDigit())
            }

            HStack(spacing: 16) {
                MacroLabel(name: "Protein", value: totalNutrients.protein, color: .blue)
                MacroLabel(name: "Carbs", value: totalNutrients.carbohydrates, color: .green)
                MacroLabel(name: "Fat", value: totalNutrients.fat, color: .orange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.15))
        )
    }
}

/// Small label showing a macro value
private struct MacroLabel: View {
    let name: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(Int(value))g")
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(color)
        }
    }
}

/// Row displaying a single nutrition entry
private struct NutritionEntryRow: View {
    let entry: NutritionEntry
    let onEdit: () -> Void
    let onUpdatePortion: (Double) -> Void

    @State private var showingPortionPicker = false

    var body: some View {
        HStack(spacing: 12) {
            // Confidence indicator
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("\(Int(entry.effectiveNutrients.calories)) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if entry.portionMultiplier != 1.0 {
                        Text("(\(NutritionEntry.formatMultiplier(entry.portionMultiplier)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Portion adjustment button
            Menu {
                ForEach(NutritionEntry.portionPresets, id: \.self) { preset in
                    Button {
                        onUpdatePortion(preset)
                    } label: {
                        HStack {
                            Text(NutritionEntry.formatMultiplier(preset))
                            if entry.portionMultiplier == preset {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.secondary)
            }

            // Edit button
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
        )
    }

    private var confidenceColor: Color {
        switch entry.confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        case .unableToIdentify, .none: return .gray
        }
    }

}

/// Card showing macro ratio as a simple visualization
struct MacroRatioCard: View {
    let nutrients: NutrientValues

    private var totalMacros: Double {
        nutrients.protein + nutrients.carbohydrates + nutrients.fat
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Macro Ratio")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if totalMacros > 0 {
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        // Protein bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * nutrients.proteinRatio)

                        // Carbs bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: geometry.size.width * nutrients.carbsRatio)

                        // Fat bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange)
                            .frame(width: geometry.size.width * nutrients.fatRatio)
                    }
                }
                .frame(height: 12)

                // Legend
                HStack(spacing: 16) {
                    MacroLegendItem(color: .blue, label: "P", percentage: nutrients.proteinRatio)
                    MacroLegendItem(color: .green, label: "C", percentage: nutrients.carbsRatio)
                    MacroLegendItem(color: .orange, label: "F", percentage: nutrients.fatRatio)
                }
            } else {
                Text("No macros logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
        )
    }
}

/// Legend item for macro ratio
private struct MacroLegendItem: View {
    let color: Color
    let label: String
    let percentage: Double

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text("\(label) \(Int(percentage * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
