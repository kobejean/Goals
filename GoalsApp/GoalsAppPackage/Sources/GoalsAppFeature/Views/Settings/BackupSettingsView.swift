import SwiftUI
import GoalsData

/// Settings view for managing iCloud backup
public struct BackupSettingsView: View {
    @Environment(AppContainer.self) private var container

    @State private var syncStatus: SyncStatus = .idle
    @State private var isCloudKitAvailable = false
    @State private var isSyncing = false

    public init() {}

    public var body: some View {
        Form {
            statusSection
            actionsSection
        }
        .navigationTitle("Backup")
        .task {
            await loadBackupInfo()
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section {
            HStack {
                Label("iCloud", systemImage: "icloud")
                Spacer()
                if isCloudKitAvailable {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Available")
                            .foregroundStyle(.green)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("Unavailable")
                            .foregroundStyle(.red)
                    }
                }
            }

            HStack {
                Label("Sync Status", systemImage: "arrow.triangle.2.circlepath")
                Spacer()
                syncStatusView
            }

            if syncStatus.lastSyncAt != nil || syncStatus.pendingCount > 0 {
                HStack {
                    Label("Pending Changes", systemImage: "clock.arrow.circlepath")
                    Spacer()
                    Text("\(syncStatus.pendingCount)")
                        .foregroundStyle(.secondary)
                }
            }

            if let lastSync = syncStatus.lastSyncAt {
                HStack {
                    Label("Last Backup", systemImage: "clock")
                    Spacer()
                    Text(lastSync, style: .relative)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Status")
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                Task { await syncNow() }
            } label: {
                HStack {
                    Spacer()
                    if isSyncing {
                        ProgressView()
                            .padding(.trailing, 8)
                    }
                    Text("Backup Now")
                    Spacer()
                }
            }
            .disabled(!isCloudKitAvailable || isSyncing)
        } header: {
            Text("Actions")
        } footer: {
            Text("Backup automatically syncs your goals, tasks, sessions, and badges to iCloud.")
        }
    }

    @ViewBuilder
    private var syncStatusView: some View {
        if syncStatus.isProcessing {
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Syncing...")
                    .foregroundStyle(.secondary)
            }
        } else if syncStatus.hasPendingOperations {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                Text("Pending")
                    .foregroundStyle(.orange)
            }
        } else if syncStatus.lastError != nil {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Error")
                    .foregroundStyle(.red)
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Up to date")
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Actions

    private func loadBackupInfo() async {
        // Check CloudKit availability
        if let scheduler = container.cloudSyncScheduler {
            isCloudKitAvailable = await container.cloudBackupService?.isAvailable() ?? false
            syncStatus = await scheduler.getStatus()
        }
    }

    private func syncNow() async {
        isSyncing = true
        if let scheduler = container.cloudSyncScheduler {
            await scheduler.syncNow()
            syncStatus = await scheduler.getStatus()
        }
        isSyncing = false
    }
}

#Preview {
    NavigationStack {
        BackupSettingsView()
            .environment(try! AppContainer.preview())
    }
}
