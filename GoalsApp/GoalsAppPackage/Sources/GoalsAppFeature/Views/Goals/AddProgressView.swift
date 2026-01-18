import SwiftUI
import GoalsDomain
import GoalsData

/// View for adding progress to a goal
public struct AddProgressView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    let goal: Goal
    let onSave: () async -> Void

    @State private var value = ""
    @State private var note = ""
    @State private var isIncremental = true
    @State private var isSaving = false

    public init(goal: Goal, onSave: @escaping () async -> Void) {
        self.goal = goal
        self.onSave = onSave
    }

    public var body: some View {
        Form {
            Section {
                TextField("Value", text: $value)
                    .keyboardType(.decimalPad)

                if goal.type == .numeric {
                    Picker("Mode", selection: $isIncremental) {
                        Text("Add to current").tag(true)
                        Text("Set as current").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                if let unit = goal.unit {
                    Text("Enter progress in \(unit)")
                }
            } footer: {
                if goal.type == .numeric {
                    if isIncremental {
                        Text("This will add to your current progress")
                    } else {
                        Text("This will replace your current progress")
                    }
                }
            }

            Section("Note (optional)") {
                TextField("Add a note", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }

            // Current status
            Section("Current Progress") {
                if goal.type == .numeric {
                    if let current = goal.currentValue, let target = goal.targetValue, let unit = goal.unit {
                        HStack {
                            Text("Current")
                            Spacer()
                            Text("\(Int(current)) \(unit)")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Target")
                            Spacer()
                            Text("\(Int(target)) \(unit)")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Progress")
                            Spacer()
                            Text("\(Int(goal.progress * 100))%")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Add Progress")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await saveProgress()
                    }
                }
                .disabled(!isValid || isSaving)
            }
        }
    }

    private var isValid: Bool {
        guard let numValue = Double(value), numValue > 0 else { return false }
        return true
    }

    private func saveProgress() async {
        guard let numValue = Double(value) else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            if isIncremental {
                try await container.trackProgressUseCase.recordIncrementalProgress(
                    goalId: goal.id,
                    increment: numValue,
                    note: note.isEmpty ? nil : note
                )
            } else {
                try await container.trackProgressUseCase.recordNumericProgress(
                    goalId: goal.id,
                    value: numValue,
                    note: note.isEmpty ? nil : note
                )
            }

            await onSave()
            dismiss()
        } catch {
            print("Failed to save progress: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        AddProgressView(
            goal: Goal(
                title: "Save Money",
                type: .numeric,
                targetValue: 10000,
                currentValue: 4500,
                unit: "USD"
            )
        ) { }
    }
    .environment(try! AppContainer.preview())
}
