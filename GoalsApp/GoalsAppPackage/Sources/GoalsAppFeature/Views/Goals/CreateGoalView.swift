import SwiftUI
import GoalsDomain
import GoalsData

/// View for creating a new data source goal
public struct CreateGoalView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDataSource: DataSourceType?
    @State private var selectedMetric: MetricInfo?
    @State private var targetValue = ""
    @State private var color: GoalColor = .blue
    @State private var isSaving = false

    // Task-specific state (for .tasks data source)
    @State private var trackAllTasks = true
    @State private var selectedTask: TaskDefinition?
    @State private var availableTasks: [TaskDefinition] = []

    var onSave: (() async -> Void)?

    public init(onSave: (() async -> Void)? = nil) {
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Step 1: Select Data Source
                Section {
                    ForEach(availableDataSources, id: \.self) { source in
                        Button {
                            selectedDataSource = source
                            selectedMetric = nil // Reset metric when source changes
                            // Reset task selection when source changes
                            trackAllTasks = true
                            selectedTask = nil
                        } label: {
                            HStack {
                                Label(source.displayName, systemImage: source.iconName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedDataSource == source {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Data Source")
                } footer: {
                    Text("Select a data source to track metrics from")
                }

                // Step 2: Select Metric (shown after data source is selected)
                if let dataSource = selectedDataSource {
                    Section {
                        ForEach(container.availableMetrics(for: dataSource)) { metric in
                            Button {
                                selectedMetric = metric
                            } label: {
                                HStack {
                                    Label(metric.name, systemImage: metric.icon)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if !metric.unit.isEmpty {
                                        Text(metric.unit)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if selectedMetric?.key == metric.key {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Metric")
                    } footer: {
                        Text("Select which metric you want to track")
                    }

                    // Step 2.5: Task Selection (shown only for .tasks data source)
                    if dataSource == .tasks {
                        Section {
                            Toggle("Track All Tasks", isOn: $trackAllTasks)

                            if !trackAllTasks {
                                if availableTasks.isEmpty {
                                    Text("No tasks available")
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(availableTasks, id: \.id) { task in
                                        Button {
                                            selectedTask = task
                                        } label: {
                                            HStack {
                                                Label(task.name, systemImage: task.icon)
                                                    .foregroundStyle(.primary)
                                                Spacer()
                                                if selectedTask?.id == task.id {
                                                    Image(systemName: "checkmark")
                                                        .foregroundStyle(.blue)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } header: {
                            Text("Task Scope")
                        } footer: {
                            if trackAllTasks {
                                Text("Goal will track metrics from all tasks combined")
                            } else if selectedTask != nil {
                                Text("Goal will track metrics from the selected task only")
                            } else {
                                Text("Select a specific task to track")
                            }
                        }
                    }
                }

                // Step 3: Set Target Value (shown after metric is selected)
                if let metric = selectedMetric {
                    Section {
                        HStack {
                            TextField("Target", text: $targetValue)
                                .keyboardType(.decimalPad)
                            if !metric.unit.isEmpty {
                                Text(metric.unit)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Target")
                    } footer: {
                        Text("Set your target for \(metric.name.lowercased())")
                    }

                    Section {
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
                    } header: {
                        Text("Appearance")
                    }
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadAvailableTasks()
            }
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
    }

    private var availableDataSources: [DataSourceType] {
        [.typeQuicker, .atCoder, .healthKitSleep, .tasks]
    }

    private var isValid: Bool {
        guard let dataSource = selectedDataSource,
              selectedMetric != nil,
              let target = Double(targetValue),
              target > 0 else {
            return false
        }

        // For tasks data source, require task selection if not tracking all tasks
        if dataSource == .tasks && !trackAllTasks && selectedTask == nil {
            return false
        }

        return true
    }

    private func createGoal() async {
        guard let dataSource = selectedDataSource,
              let metric = selectedMetric,
              let target = Double(targetValue) else {
            return
        }

        isSaving = true
        defer { isSaving = false }

        // Determine taskId and title based on task selection
        let taskId: UUID? = (dataSource == .tasks && !trackAllTasks) ? selectedTask?.id : nil
        let title: String
        if let task = selectedTask, dataSource == .tasks && !trackAllTasks {
            title = "\(task.name) \(metric.name) Goal"
        } else {
            title = "\(metric.name) Goal"
        }

        do {
            _ = try await container.createGoalUseCase.createGoal(
                title: title,
                dataSource: dataSource,
                metricKey: metric.key,
                targetValue: target,
                unit: metric.unit,
                color: color,
                taskId: taskId
            )
            // Configure data source and sync to populate the initial value
            await container.configureDataSources()
            _ = try? await container.syncDataSourcesUseCase.sync(dataSource: dataSource)
            await onSave?()
            dismiss()
        } catch {
            print("Failed to create goal: \(error)")
        }
    }

    private func loadAvailableTasks() async {
        do {
            availableTasks = try await container.taskRepository.fetchActiveTasks()
        } catch {
            print("Failed to load tasks: \(error)")
        }
    }
}

#Preview {
    CreateGoalView()
        .environment(try! AppContainer.preview())
}
