import SwiftUI
import GoalsDomain
import GoalsData

/// Settings view for app configuration
public struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var typeQuickerUsername = ""
    @State private var atCoderUsername = ""
    @State private var typeQuickerSaveState: SaveState = .idle
    @State private var atCoderSaveState: SaveState = .idle

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
        }
    }

    private func loadSettings() async {
        typeQuickerUsername = UserDefaults.standard.string(forKey: "typeQuickerUsername") ?? ""
        atCoderUsername = UserDefaults.standard.string(forKey: "atCoderUsername") ?? ""
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

        container.notifySettingsChanged()
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

        container.notifySettingsChanged()
        atCoderSaveState = .saved
        try? await Task.sleep(for: .seconds(1.5))
        atCoderSaveState = .idle
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
