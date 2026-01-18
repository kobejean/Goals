import SwiftUI
import GoalsDomain
import GoalsData

/// Settings view for app configuration
public struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var typeQuickerUsername = ""
    @State private var atCoderUsername = ""
    @State private var isSyncing = false
    @State private var lastSyncResult: String?
    @State private var typeQuickerSaveState: SaveState = .idle
    @State private var atCoderSaveState: SaveState = .idle

    // TypeQuicker goals
    @State private var wpmGoal: Double = 0
    @State private var accuracyGoal: Double = 0
    @State private var timeGoal: Double = 0

    enum SaveState {
        case idle
        case saving
        case saved
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Data Sources
                Section {
                    DataSourceRow(
                        title: "TypeQuicker",
                        icon: "keyboard",
                        username: $typeQuickerUsername,
                        placeholder: "Enter username",
                        saveState: typeQuickerSaveState
                    )

                    DataSourceRow(
                        title: "AtCoder",
                        icon: "chevron.left.forwardslash.chevron.right",
                        username: $atCoderUsername,
                        placeholder: "Enter username",
                        saveState: atCoderSaveState
                    )
                } header: {
                    Text("Data Sources")
                } footer: {
                    Text("Settings are saved automatically")
                }

                // TypeQuicker Goals
                Section {
                    GoalInputRow(
                        label: "WPM Goal",
                        value: $wpmGoal,
                        unit: "WPM",
                        icon: "speedometer",
                        color: .blue
                    )

                    GoalInputRow(
                        label: "Accuracy Goal",
                        value: $accuracyGoal,
                        unit: "%",
                        icon: "target",
                        color: .green
                    )

                    GoalInputRow(
                        label: "Daily Practice Goal",
                        value: $timeGoal,
                        unit: "min",
                        icon: "clock",
                        color: .orange
                    )
                } header: {
                    Text("TypeQuicker Goals")
                } footer: {
                    Text("Set targets to display on your charts. Set to 0 to hide.")
                }

                // Sync
                Section {
                    Button {
                        Task {
                            await syncDataSources()
                        }
                    } label: {
                        HStack {
                            Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            if isSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSyncing)

                    if let result = lastSyncResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Sync fetches latest data from configured sources")
                }

                // iCloud
                Section {
                    HStack {
                        Label("iCloud Sync", systemImage: "icloud")
                        Spacer()
                        Text("Automatic")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Your goals sync automatically across all your devices via iCloud")
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com")!) {
                        HStack {
                            Text("Source Code")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                await loadSettings()
            }
            .onChange(of: typeQuickerUsername) { _, newValue in
                Task {
                    await saveTypeQuickerSettings(username: newValue)
                }
            }
            .onChange(of: atCoderUsername) { _, newValue in
                Task {
                    await saveAtCoderSettings(username: newValue)
                }
            }
            .onChange(of: wpmGoal) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "typeQuickerWpmGoal")
            }
            .onChange(of: accuracyGoal) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "typeQuickerAccuracyGoal")
            }
            .onChange(of: timeGoal) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "typeQuickerTimeGoal")
            }
        }
    }

    private func loadSettings() async {
        typeQuickerUsername = UserDefaults.standard.string(forKey: "typeQuickerUsername") ?? ""
        atCoderUsername = UserDefaults.standard.string(forKey: "atCoderUsername") ?? ""

        // Load TypeQuicker goals
        wpmGoal = UserDefaults.standard.double(forKey: "typeQuickerWpmGoal")
        accuracyGoal = UserDefaults.standard.double(forKey: "typeQuickerAccuracyGoal")
        timeGoal = UserDefaults.standard.double(forKey: "typeQuickerTimeGoal")
    }

    private func saveTypeQuickerSettings(username: String) async {
        typeQuickerSaveState = .saving
        UserDefaults.standard.set(username, forKey: "typeQuickerUsername")

        if !username.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .typeQuicker,
                credentials: ["username": username]
            )
            try? await container.typeQuickerDataSource.configure(settings: settings)
        }

        typeQuickerSaveState = .saved
        try? await Task.sleep(for: .seconds(1.5))
        typeQuickerSaveState = .idle
    }

    private func saveAtCoderSettings(username: String) async {
        atCoderSaveState = .saving
        UserDefaults.standard.set(username, forKey: "atCoderUsername")

        if !username.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .atCoder,
                credentials: ["username": username]
            )
            try? await container.atCoderDataSource.configure(settings: settings)
        }

        atCoderSaveState = .saved
        try? await Task.sleep(for: .seconds(1.5))
        atCoderSaveState = .idle
    }

    private func syncDataSources() async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            let result = try await container.syncDataSourcesUseCase.syncAll()

            if result.allSuccessful {
                lastSyncResult = "Synced \(result.totalDataPointsCreated) data points"
            } else {
                let failed = result.sourceResults.filter { !$0.value.success }.keys
                lastSyncResult = "Some sources failed: \(failed.map { $0.displayName }.joined(separator: ", "))"
            }
        } catch {
            lastSyncResult = "Sync failed: \(error.localizedDescription)"
        }
    }

    public init() {}
}

/// Row for configuring a data source
struct DataSourceRow: View {
    let title: String
    let icon: String
    @Binding var username: String
    let placeholder: String
    let saveState: SettingsView.SaveState

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)

                TextField(placeholder, text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Spacer()

            // Save status indicator
            Group {
                switch saveState {
                case .idle:
                    EmptyView()
                case .saving:
                    ProgressView()
                        .scaleEffect(0.7)
                case .saved:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .frame(width: 24)
        }
        .padding(.vertical, 4)
    }
}

/// Row for setting a numeric goal
struct GoalInputRow: View {
    let label: String
    @Binding var value: Double
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(label)

            Spacer()

            TextField("0", value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
                .frame(width: 80)
                .multilineTextAlignment(.trailing)

            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
        }
    }
}

#Preview {
    SettingsView()
        .environment(try! AppContainer.preview())
}
