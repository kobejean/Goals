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

    public var body: some View {
        NavigationStack {
            Form {
                // Data Sources
                Section("Data Sources") {
                    dataSourceRow(
                        title: "TypeQuicker",
                        icon: "keyboard",
                        username: $typeQuickerUsername,
                        placeholder: "Enter username"
                    )

                    dataSourceRow(
                        title: "AtCoder",
                        icon: "chevron.left.forwardslash.chevron.right",
                        username: $atCoderUsername,
                        placeholder: "Enter username"
                    )
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
        }
    }

    @ViewBuilder
    private func dataSourceRow(
        title: String,
        icon: String,
        username: Binding<String>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(title)
                    .fontWeight(.medium)
            }

            TextField(placeholder, text: username)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .autocorrectionDisabled()

            Button("Save") {
                Task {
                    await saveDataSourceSettings(title: title, username: username.wrappedValue)
                }
            }
            .font(.caption)
            .disabled(username.wrappedValue.isEmpty)
        }
        .padding(.vertical, 4)
    }

    private func loadSettings() async {
        // Load saved settings from UserDefaults or Keychain
        typeQuickerUsername = UserDefaults.standard.string(forKey: "typeQuickerUsername") ?? ""
        atCoderUsername = UserDefaults.standard.string(forKey: "atCoderUsername") ?? ""
    }

    private func saveDataSourceSettings(title: String, username: String) async {
        switch title {
        case "TypeQuicker":
            UserDefaults.standard.set(username, forKey: "typeQuickerUsername")
            let settings = DataSourceSettings(
                dataSourceType: .typeQuicker,
                credentials: ["username": username]
            )
            try? await container.typeQuickerDataSource.configure(settings: settings)

        case "AtCoder":
            UserDefaults.standard.set(username, forKey: "atCoderUsername")
            let settings = DataSourceSettings(
                dataSourceType: .atCoder,
                credentials: ["username": username]
            )
            try? await container.atCoderDataSource.configure(settings: settings)

        default:
            break
        }
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

#Preview {
    SettingsView()
        .environment(try! AppContainer.preview())
}
