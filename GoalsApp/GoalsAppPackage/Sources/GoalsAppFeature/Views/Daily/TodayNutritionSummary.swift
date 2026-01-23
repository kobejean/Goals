import SwiftUI
import GoalsDomain
import GoalsWidgetShared

#if canImport(UIKit)
import UIKit
#endif

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
            List {
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
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
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
            .listStyle(.plain)
            .frame(minHeight: CGFloat(entries.count) * 80)
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
            // Thumbnail or placeholder
            thumbnailView
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))

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

                    // Confidence indicator
                    Circle()
                        .fill(confidenceColor)
                        .frame(width: 6, height: 6)
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
                    .foregroundStyle(.tint)
            }

            // Edit button
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(.tint)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
        )
    }

    @ViewBuilder
    private var thumbnailView: some View {
        #if canImport(UIKit)
        if let data = entry.thumbnailData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            placeholderView
        }
        #else
        placeholderView
        #endif
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "fork.knife")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

/// Card showing macro ratio as a radar chart visualization
struct MacroRatioCard: View {
    let nutrients: NutrientValues

    // Daily macro targets in grams
    private let idealMacros = (protein: 150.0, carbs: 250.0, fat: 65.0)

    private var totalMacros: Double {
        nutrients.protein + nutrients.carbohydrates + nutrients.fat
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Macro Ratio")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if totalMacros > 0 {
                MacroRadarChart(
                    current: (nutrients.protein, nutrients.carbohydrates, nutrients.fat),
                    ideal: idealMacros
                )
                .frame(height: 180)
            } else {
                Text("No macros logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
        )
    }
}

