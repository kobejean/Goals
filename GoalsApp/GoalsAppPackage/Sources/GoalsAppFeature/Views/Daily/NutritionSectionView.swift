import SwiftUI
import PhotosUI
import GoalsDomain
import GoalsData

/// State for nutrition analysis flow
enum NutritionAnalysisState: Equatable {
    case idle
    case analyzing
    case error(String)
}

/// Section view for nutrition tracking within the Daily tab
public struct NutritionSectionView: View {
    @Environment(AppContainer.self) private var container
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var analysisState: NutritionAnalysisState = .idle
    @State private var pendingAnalysis: PendingNutritionAnalysis?
    @State private var showingConfirmSheet = false
    @State private var todayEntries: [NutritionEntry] = []
    @State private var editingEntry: NutritionEntry?

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Photo picker button
                addFoodSection

                // Analysis state indicator
                if case .analyzing = analysisState {
                    AnalyzingIndicator()
                }

                if case .error(let message) = analysisState {
                    ErrorBanner(message: message) {
                        analysisState = .idle
                    }
                }

                // Today's entries
                if !todayEntries.isEmpty {
                    TodayNutritionSummary(
                        entries: todayEntries,
                        onDelete: deleteEntry,
                        onEdit: { entry in
                            editingEntry = entry
                        },
                        onUpdatePortion: updateEntryPortion
                    )
                } else if analysisState == .idle {
                    EmptyNutritionView()
                }
            }
            .padding()
        }
        .task {
            // Ensure Gemini is configured from saved settings
            await container.configureDataSources()
            await loadTodayEntries()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            if let item = newItem {
                Task {
                    await analyzePhoto(item: item)
                }
            }
        }
        .sheet(isPresented: $showingConfirmSheet) {
            if let pending = pendingAnalysis {
                ConfirmNutritionEntryView(
                    analysis: pending,
                    onConfirm: { entry in
                        Task {
                            await saveEntry(entry)
                        }
                        showingConfirmSheet = false
                        pendingAnalysis = nil
                    },
                    onCancel: {
                        showingConfirmSheet = false
                        pendingAnalysis = nil
                        selectedPhotoItem = nil
                    }
                )
            }
        }
        .sheet(item: $editingEntry) { entry in
            EditNutritionEntryView(
                entry: entry,
                onSave: { updatedEntry in
                    Task {
                        await updateEntry(updatedEntry)
                    }
                    editingEntry = nil
                },
                onCancel: {
                    editingEntry = nil
                }
            )
        }
    }

    private var addFoodSection: some View {
        PhotosPicker(
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Label("Add Food Photo", systemImage: "camera.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.accentColor.opacity(0.1))
                )
        }
        .disabled(analysisState == .analyzing)
    }

    // MARK: - Actions

    private func loadTodayEntries() async {
        do {
            todayEntries = try await container.nutritionRepository.fetchEntries(for: Date())
        } catch {
            todayEntries = []
        }
    }

    private func analyzePhoto(item: PhotosPickerItem) async {
        analysisState = .analyzing

        do {
            // Load image data from PhotosPickerItem
            guard let imageData = try await item.loadTransferable(type: Data.self) else {
                throw GeminiError.parseError("Failed to load image data")
            }

            // Get the photo asset ID
            let assetId = item.itemIdentifier ?? UUID().uuidString

            // Analyze with Gemini
            let result = try await container.geminiDataSource.analyzeFood(imageData: imageData)

            // Create pending analysis for confirmation
            pendingAnalysis = PendingNutritionAnalysis(
                photoAssetId: assetId,
                imageData: imageData,
                analysisResult: result
            )

            analysisState = .idle
            showingConfirmSheet = true

        } catch GeminiError.notConfigured {
            analysisState = .error("Please configure your Gemini API key in Settings.")
        } catch GeminiError.invalidAPIKey {
            analysisState = .error("Invalid Gemini API key. Please check Settings.")
        } catch GeminiError.rateLimited {
            analysisState = .error("Rate limit exceeded. Please wait and try again.")
        } catch GeminiError.unableToIdentify {
            analysisState = .error("Unable to identify food in the image. Please try a different photo.")
        } catch {
            analysisState = .error("Analysis failed: \(error.localizedDescription)")
        }

        selectedPhotoItem = nil
    }

    private func saveEntry(_ entry: NutritionEntry) async {
        do {
            try await container.nutritionRepository.createEntry(entry)
            await loadTodayEntries()
        } catch {
            analysisState = .error("Failed to save entry: \(error.localizedDescription)")
        }
    }

    private func deleteEntry(_ entry: NutritionEntry) async {
        do {
            try await container.nutritionRepository.deleteEntry(id: entry.id)
            await loadTodayEntries()
        } catch {
            analysisState = .error("Failed to delete entry: \(error.localizedDescription)")
        }
    }

    private func updateEntry(_ entry: NutritionEntry) async {
        do {
            try await container.nutritionRepository.updateEntry(entry)
            await loadTodayEntries()
        } catch {
            analysisState = .error("Failed to update entry: \(error.localizedDescription)")
        }
    }

    private func updateEntryPortion(_ entry: NutritionEntry, _ multiplier: Double) async {
        var updated = entry
        updated.portionMultiplier = multiplier
        await updateEntry(updated)
    }

    public init() {}
}

/// Pending analysis awaiting user confirmation
struct PendingNutritionAnalysis {
    let photoAssetId: String
    let imageData: Data
    let analysisResult: GeminiFoodAnalysisResult
}

/// Empty state for nutrition section
private struct EmptyNutritionView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Food Logged Today")
                .font(.headline)

            Text("Take a photo of your food to track nutrition")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}

/// Analyzing indicator
private struct AnalyzingIndicator: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Analyzing food...")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
        )
    }
}

/// Error banner with dismiss action
private struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
    }
}

#Preview {
    NavigationStack {
        NutritionSectionView()
    }
    .environment(try! AppContainer.preview())
}
