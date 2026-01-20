import SwiftUI
import GoalsDomain
import GoalsData

/// Settings view for app configuration
public struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var typeQuickerUsername = ""
    @State private var atCoderUsername = ""
    @State private var ankiHost = ""
    @State private var ankiPort = "8765"
    @State private var ankiDecks = ""
    @State private var ankiConnectionStatus: AnkiConnectionStatus = .unknown
    @State private var typeQuickerSaveState: SaveState = .idle
    @State private var atCoderSaveState: SaveState = .idle
    @State private var ankiSaveState: SaveState = .idle

    enum SaveState {
        case idle
        case saving
        case saved
    }

    enum AnkiConnectionStatus {
        case unknown
        case testing
        case connected
        case disconnected
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
                        placeholder: "Enter username"
                    )

                    DataSourceRow(
                        title: "AtCoder",
                        icon: "chevron.left.forwardslash.chevron.right",
                        username: $atCoderUsername,
                        placeholder: "Enter username"
                    )
                } header: {
                    Text("Data Sources")
                } footer: {
                }

                // Anki Settings
                Section {
                    HStack {
                        Label("Host", systemImage: "network")
                        Spacer()
                        TextField("localhost", text: $ankiHost)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Port", systemImage: "number")
                        Spacer()
                        TextField("8765", text: $ankiPort)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Decks", systemImage: "rectangle.stack")
                        Spacer()
                        TextField("All decks", text: $ankiDecks)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Status")
                        Spacer()
                        ankiStatusView
                    }

                    Button {
                        Task {
                            await testAnkiConnection()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Test Connection")
                            Spacer()
                        }
                    }
                    .disabled(ankiHost.isEmpty)
                } header: {
                    Text("Anki")
                } footer: {
                    Text("Enter comma-separated deck names to track specific decks, or leave empty for all decks. Anki must be running with AnkiConnect installed.")
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/kobejean/Goals")!) {
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
            .onChange(of: ankiHost) { _, _ in
                Task {
                    await saveAnkiSettings()
                }
            }
            .onChange(of: ankiPort) { _, _ in
                Task {
                    await saveAnkiSettings()
                }
            }
            .onChange(of: ankiDecks) { _, _ in
                Task {
                    await saveAnkiSettings()
                }
            }
        }
    }

    @ViewBuilder
    private var ankiStatusView: some View {
        switch ankiConnectionStatus {
        case .unknown:
            Text("Not tested")
                .foregroundStyle(.secondary)
        case .testing:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Testing...")
                    .foregroundStyle(.secondary)
            }
        case .connected:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Connected")
                    .foregroundStyle(.green)
            }
        case .disconnected:
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Disconnected")
                    .foregroundStyle(.red)
            }
        }
    }

    private func loadSettings() async {
        typeQuickerUsername = UserDefaults.standard.typeQuickerUsername ?? ""
        atCoderUsername = UserDefaults.standard.atCoderUsername ?? ""
        ankiHost = UserDefaults.standard.ankiHost ?? ""
        ankiPort = UserDefaults.standard.ankiPort ?? "8765"
        ankiDecks = UserDefaults.standard.ankiDecks ?? ""
    }

    private func saveTypeQuickerSettings(username: String) async {
        typeQuickerSaveState = .saving
        UserDefaults.standard.typeQuickerUsername = username

        if !username.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .typeQuicker,
                credentials: ["username": username]
            )
            try? await container.typeQuickerDataSource.configure(settings: settings)
        }

        container.notifySettingsChanged()
        typeQuickerSaveState = .saved
        try? await Task.sleep(for: .seconds(1.5))
        typeQuickerSaveState = .idle
    }

    private func saveAtCoderSettings(username: String) async {
        atCoderSaveState = .saving
        UserDefaults.standard.atCoderUsername = username

        if !username.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .atCoder,
                credentials: ["username": username]
            )
            try? await container.atCoderDataSource.configure(settings: settings)
        }

        container.notifySettingsChanged()
        atCoderSaveState = .saved
        try? await Task.sleep(for: .seconds(1.5))
        atCoderSaveState = .idle
    }

    private func saveAnkiSettings() async {
        ankiSaveState = .saving
        UserDefaults.standard.ankiHost = ankiHost
        UserDefaults.standard.ankiPort = ankiPort
        UserDefaults.standard.ankiDecks = ankiDecks

        if !ankiHost.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .anki,
                options: ["host": ankiHost, "port": ankiPort, "decks": ankiDecks]
            )
            try? await container.ankiDataSource.configure(settings: settings)
        }

        container.notifySettingsChanged()
        ankiSaveState = .saved
        try? await Task.sleep(for: .seconds(1.5))
        ankiSaveState = .idle
    }

    private func testAnkiConnection() async {
        ankiConnectionStatus = .testing

        // Configure first if not already
        if !ankiHost.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .anki,
                options: ["host": ankiHost, "port": ankiPort, "decks": ankiDecks]
            )
            try? await container.ankiDataSource.configure(settings: settings)
        }

        // Test connection
        do {
            let connected = try await container.ankiDataSource.testConnection()
            ankiConnectionStatus = connected ? .connected : .disconnected
        } catch {
            ankiConnectionStatus = .disconnected
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

    var body: some View {
        HStack {
            Label(title, systemImage: icon)

            Spacer()

            TextField(placeholder, text: $username)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.secondary)

        }
    }
}

#Preview {
    SettingsView()
        .environment(try! AppContainer.preview())
}
