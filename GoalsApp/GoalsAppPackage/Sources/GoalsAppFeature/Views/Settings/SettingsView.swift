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
            Label(title, systemImage: icon)

            Spacer()

            TextField(placeholder, text: $username)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.secondary)

            // Save status indicator
            switch saveState {
            case .idle:
                EmptyView()
                    .frame(width: 0)
            case .saving:
                ProgressView()
                    .scaleEffect(0.7)
            case .saved:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(try! AppContainer.preview())
}
