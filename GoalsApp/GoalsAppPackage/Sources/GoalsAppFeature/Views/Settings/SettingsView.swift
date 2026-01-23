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
    @State private var zoteroAPIKey = ""
    @State private var zoteroUserID = ""
    @State private var zoteroToReadCollection = ""
    @State private var zoteroInProgressCollection = ""
    @State private var zoteroReadCollection = ""
    @State private var zoteroConnectionStatus: ZoteroConnectionStatus = .unknown
    @State private var geminiAPIKey = ""
    @State private var typeQuickerSaveState: SaveState = .idle
    @State private var atCoderSaveState: SaveState = .idle
    @State private var ankiSaveState: SaveState = .idle
    @State private var zoteroSaveState: SaveState = .idle

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

    enum ZoteroConnectionStatus {
        case unknown
        case testing
        case connected
        case disconnected
        case unauthorized  // Invalid API key or permissions
    }

    public var body: some View {
        NavigationStack {
            Form {
                dataSourcesSection
                ankiSection
                zoteroSection
                geminiSection
                backupSection
                aboutSection
            }
            .navigationTitle("Settings")
            .task {
                await loadSettings()
            }
            .onChange(of: typeQuickerUsername) { _, newValue in
                Task { await saveTypeQuickerSettings(username: newValue) }
            }
            .onChange(of: atCoderUsername) { _, newValue in
                Task { await saveAtCoderSettings(username: newValue) }
            }
            .onChange(of: ankiHost) { _, _ in Task { await saveAnkiSettings() } }
            .onChange(of: ankiPort) { _, _ in Task { await saveAnkiSettings() } }
            .onChange(of: ankiDecks) { _, _ in Task { await saveAnkiSettings() } }
            .onChange(of: zoteroAPIKey) { _, _ in Task { await saveZoteroSettings() } }
            .onChange(of: zoteroUserID) { _, _ in Task { await saveZoteroSettings() } }
            .onChange(of: zoteroToReadCollection) { _, _ in Task { await saveZoteroSettings() } }
            .onChange(of: zoteroInProgressCollection) { _, _ in Task { await saveZoteroSettings() } }
            .onChange(of: zoteroReadCollection) { _, _ in Task { await saveZoteroSettings() } }
            .onChange(of: geminiAPIKey) { _, newValue in Task { await saveGeminiSettings(apiKey: newValue) } }
        }
    }

    // MARK: - Section Views

    private var dataSourcesSection: some View {
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
        }
    }

    private var ankiSection: some View {
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
                Task { await testAnkiConnection() }
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
    }

    private var zoteroSection: some View {
        Section {
            HStack {
                Label("API Key", systemImage: "key")
                Spacer()
                SecureField("Enter API key", text: $zoteroAPIKey)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.secondary)
            }
            HStack {
                Label("User ID", systemImage: "person")
                Spacer()
                TextField("Enter user ID", text: $zoteroUserID)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Label("To Read", systemImage: "book.closed")
                Spacer()
                TextField("Collection key", text: $zoteroToReadCollection)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.secondary)
            }
            HStack {
                Label("In Progress", systemImage: "book")
                Spacer()
                TextField("Collection key", text: $zoteroInProgressCollection)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.secondary)
            }
            HStack {
                Label("Read", systemImage: "checkmark.circle")
                Spacer()
                TextField("Collection key", text: $zoteroReadCollection)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Status")
                Spacer()
                zoteroStatusView
            }
            Button {
                Task { await testZoteroConnection() }
            } label: {
                HStack {
                    Spacer()
                    Text("Test Connection")
                    Spacer()
                }
            }
            .disabled(zoteroAPIKey.isEmpty || zoteroUserID.isEmpty)
        } header: {
            Text("Zotero")
        } footer: {
            Text("Get your API key at zotero.org/settings/keys. Collection keys are found in collection URLs (e.g., zotero.org/users/123/collections/ABC).")
        }
    }

    private var geminiSection: some View {
        Section {
            HStack {
                Label("API Key", systemImage: "key.fill")
                Spacer()
                SecureField("Enter API key", text: $geminiAPIKey)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Gemini AI")
        } footer: {
            Text("Get your API key at aistudio.google.com. Used for nutrition photo analysis.")
        }
    }

    private var backupSection: some View {
        Section {
            NavigationLink {
                BackupSettingsView()
            } label: {
                Label("Backup & Restore", systemImage: "icloud")
            }
        } header: {
            Text("iCloud")
        }
    }

    private var aboutSection: some View {
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

    @ViewBuilder
    private var zoteroStatusView: some View {
        switch zoteroConnectionStatus {
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
        case .unauthorized:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Invalid credentials")
                    .foregroundStyle(.orange)
            }
        }
    }

    private func loadSettings() async {
        typeQuickerUsername = UserDefaults.standard.typeQuickerUsername ?? ""
        atCoderUsername = UserDefaults.standard.atCoderUsername ?? ""
        ankiHost = UserDefaults.standard.ankiHost ?? ""
        ankiPort = UserDefaults.standard.ankiPort ?? "8765"
        ankiDecks = UserDefaults.standard.ankiDecks ?? ""
        zoteroAPIKey = UserDefaults.standard.zoteroAPIKey ?? ""
        zoteroUserID = UserDefaults.standard.zoteroUserID ?? ""
        zoteroToReadCollection = UserDefaults.standard.zoteroToReadCollection ?? ""
        zoteroInProgressCollection = UserDefaults.standard.zoteroInProgressCollection ?? ""
        zoteroReadCollection = UserDefaults.standard.zoteroReadCollection ?? ""
        geminiAPIKey = UserDefaults.standard.geminiAPIKey ?? ""
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

    private func saveZoteroSettings() async {
        zoteroSaveState = .saving
        UserDefaults.standard.zoteroAPIKey = zoteroAPIKey
        UserDefaults.standard.zoteroUserID = zoteroUserID
        UserDefaults.standard.zoteroToReadCollection = zoteroToReadCollection
        UserDefaults.standard.zoteroInProgressCollection = zoteroInProgressCollection
        UserDefaults.standard.zoteroReadCollection = zoteroReadCollection

        if !zoteroAPIKey.isEmpty && !zoteroUserID.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .zotero,
                credentials: ["apiKey": zoteroAPIKey, "userID": zoteroUserID],
                options: [
                    "toReadCollection": zoteroToReadCollection,
                    "inProgressCollection": zoteroInProgressCollection,
                    "readCollection": zoteroReadCollection
                ]
            )
            try? await container.zoteroDataSource.configure(settings: settings)
        }

        container.notifySettingsChanged()
        zoteroSaveState = .saved
        try? await Task.sleep(for: .seconds(1.5))
        zoteroSaveState = .idle
    }

    private func testZoteroConnection() async {
        zoteroConnectionStatus = .testing

        // Configure first if not already
        if !zoteroAPIKey.isEmpty && !zoteroUserID.isEmpty {
            let settings = DataSourceSettings(
                dataSourceType: .zotero,
                credentials: ["apiKey": zoteroAPIKey, "userID": zoteroUserID],
                options: [
                    "toReadCollection": zoteroToReadCollection,
                    "inProgressCollection": zoteroInProgressCollection,
                    "readCollection": zoteroReadCollection
                ]
            )
            try? await container.zoteroDataSource.configure(settings: settings)
        }

        // Test connection
        do {
            let connected = try await container.zoteroDataSource.testConnection()
            zoteroConnectionStatus = connected ? .connected : .disconnected
        } catch DataSourceError.unauthorized {
            zoteroConnectionStatus = .unauthorized
        } catch {
            zoteroConnectionStatus = .disconnected
        }
    }

    private func saveGeminiSettings(apiKey: String) async {
        UserDefaults.standard.geminiAPIKey = apiKey

        if !apiKey.isEmpty {
            await container.geminiDataSource.configure(apiKey: apiKey)
        } else {
            await container.geminiDataSource.clearConfiguration()
        }

        container.notifySettingsChanged()
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
