import SwiftUI
import GoalsDomain
import GoalsData

/// View for creating a new goal
public struct CreateGoalView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var goalType: GoalType = .numeric
    @State private var dataSource: DataSourceType = .manual
    @State private var color: GoalColor = .blue

    // Numeric goal fields
    @State private var targetValue = ""
    @State private var unit = ""

    // Habit goal fields
    @State private var frequency: HabitFrequency = .daily
    @State private var targetCount = "1"

    // Common fields
    @State private var hasDeadline = false
    @State private var deadline = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now

    @State private var isSaving = false

    public var body: some View {
        Form {
            // Basic info
            Section("Goal Info") {
                TextField("Title", text: $title)

                TextField("Description (optional)", text: $description, axis: .vertical)
                    .lineLimit(3...6)

                Picker("Type", selection: $goalType) {
                    ForEach(GoalType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.iconName)
                            .tag(type)
                    }
                }

                Picker("Data Source", selection: $dataSource) {
                    ForEach(DataSourceType.allCases, id: \.self) { source in
                        Label(source.displayName, systemImage: source.iconName)
                            .tag(source)
                    }
                }

                Picker("Color", selection: $color) {
                    ForEach(GoalColor.allCases, id: \.self) { goalColor in
                        HStack {
                            Circle()
                                .fill(goalColor.swiftUIColor)
                                .frame(width: 16, height: 16)
                            Text(goalColor.displayName)
                        }
                        .tag(goalColor)
                    }
                }
            }

            // Type-specific fields
            switch goalType {
            case .numeric:
                Section("Target") {
                    TextField("Target Value", text: $targetValue)
                        .keyboardType(.decimalPad)

                    TextField("Unit (e.g., USD, km, hours)", text: $unit)
                }

            case .habit:
                Section("Habit Settings") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(HabitFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }

                    Stepper("Target: \(Int(targetCount) ?? 1)x per \(frequency.rawValue)", value: Binding(
                        get: { Int(targetCount) ?? 1 },
                        set: { targetCount = String($0) }
                    ), in: 1...31)
                }

            case .milestone:
                Section("Milestone") {
                    Text("Track completion of a one-time achievement")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            case .compound:
                Section("Compound Goal") {
                    Text("Sub-goals can be added after creation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Deadline
            Section {
                Toggle("Set Deadline", isOn: $hasDeadline)

                if hasDeadline {
                    DatePicker("Deadline", selection: $deadline, displayedComponents: .date)
                }
            }
        }
        .navigationTitle("New Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    Task {
                        await createGoal()
                    }
                }
                .disabled(!isValid || isSaving)
            }
        }
    }

    private var isValid: Bool {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return false }

        switch goalType {
        case .numeric:
            guard let target = Double(targetValue), target > 0 else { return false }
            guard !unit.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
            return true

        case .habit:
            guard let count = Int(targetCount), count > 0 else { return false }
            return true

        case .milestone, .compound:
            return true
        }
    }

    private func createGoal() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let goalDeadline = hasDeadline ? deadline : nil

            switch goalType {
            case .numeric:
                guard let target = Double(targetValue) else { return }
                _ = try await container.createGoalUseCase.createNumericGoal(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    targetValue: target,
                    unit: unit,
                    dataSource: dataSource,
                    deadline: goalDeadline,
                    color: color
                )

            case .habit:
                guard let count = Int(targetCount) else { return }
                _ = try await container.createGoalUseCase.createHabitGoal(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    frequency: frequency,
                    targetCount: count,
                    dataSource: dataSource,
                    color: color
                )

            case .milestone:
                _ = try await container.createGoalUseCase.createMilestoneGoal(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    dataSource: dataSource,
                    deadline: goalDeadline,
                    color: color
                )

            case .compound:
                _ = try await container.createGoalUseCase.createCompoundGoal(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    subGoalIds: [],
                    deadline: goalDeadline,
                    color: color
                )
            }

            dismiss()
        } catch {
            print("Failed to create goal: \(error)")
        }
    }

    public init() {}
}

#Preview {
    NavigationStack {
        CreateGoalView()
    }
    .environment(try! AppContainer.preview())
}
