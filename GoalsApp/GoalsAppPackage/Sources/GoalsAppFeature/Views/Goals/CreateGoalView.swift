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
                        ForEach(metricsForDataSource(dataSource)) { metric in
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
        [.typeQuicker, .atCoder]
    }

    private func metricsForDataSource(_ dataSource: DataSourceType) -> [MetricInfo] {
        switch dataSource {
        case .typeQuicker:
            return container.typeQuickerDataSource.availableMetrics
        case .atCoder:
            return container.atCoderDataSource.availableMetrics
        }
    }

    private var isValid: Bool {
        guard selectedDataSource != nil,
              selectedMetric != nil,
              let target = Double(targetValue),
              target > 0 else {
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

        do {
            _ = try await container.createGoalUseCase.createGoal(
                title: "\(metric.name) Goal",
                dataSource: dataSource,
                metricKey: metric.key,
                targetValue: target,
                unit: metric.unit,
                color: color
            )
            await onSave?()
            dismiss()
        } catch {
            print("Failed to create goal: \(error)")
        }
    }
}

#Preview {
    CreateGoalView()
        .environment(try! AppContainer.preview())
}
