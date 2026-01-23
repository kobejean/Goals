import SwiftUI
import GoalsData

/// Settings view for managing iCloud backup
public struct BackupSettingsView: View {
    @Environment(AppContainer.self) private var container

    @State private var syncStatus: SyncStatus = .idle
    @State private var backupStats: BackupStats?
    @State private var isCloudKitAvailable = false
    @State private var isSyncing = false
    @State private var isLoadingStats = true
    @State private var showRestoreConfirmation = false
    @State private var isRestoring = false
    @State private var restoreResult: RestoreResult?
    @State private var showRestoreResult = false

    public init() {}

    public var body: some View {
        Form {
            statusSection
            backupContentsSection
            actionsSection
        }
        .navigationTitle("Backup & Restore")
        .task {
            await loadBackupInfo()
        }
        .alert("Restore from Backup", isPresented: $showRestoreConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Restore", role: .destructive) {
                Task { await performRestore() }
            }
        } message: {
            Text("This will replace all local data with data from iCloud backup. This action cannot be undone.")
        }
        .alert("Restore Complete", isPresented: $showRestoreResult) {
            Button("OK") {}
        } message: {
            if let result = restoreResult {
                Text("Restored \(result.totalRestored) items.\(result.hasErrors ? " Some items failed to restore." : "")")
            }
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

    private var backupContentsSection: some View {
        Section {
            if isLoadingStats {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let stats = backupStats, stats.hasData {
                if stats.goalCount > 0 {
                    HStack {
                        Label("Goals", systemImage: "target")
                        Spacer()
                        Text("\(stats.goalCount)")
                            .foregroundStyle(.secondary)
                    }
                }
                if stats.taskCount > 0 {
                    HStack {
                        Label("Tasks", systemImage: "checkmark.circle")
                        Spacer()
                        Text("\(stats.taskCount)")
                            .foregroundStyle(.secondary)
                    }
                }
                if stats.sessionCount > 0 {
                    HStack {
                        Label("Sessions", systemImage: "clock")
                        Spacer()
                        Text("\(stats.sessionCount)")
                            .foregroundStyle(.secondary)
                    }
                }
                if stats.badgeCount > 0 {
                    HStack {
                        Label("Badges", systemImage: "star")
                        Spacer()
                        Text("\(stats.badgeCount)")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("No backup data found")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Backup Contents")
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

            Button {
                showRestoreConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    if isRestoring {
                        ProgressView()
                            .padding(.trailing, 8)
                    }
                    Text("Restore from Backup")
                    Spacer()
                }
            }
            .disabled(!isCloudKitAvailable || backupStats?.hasData != true || isRestoring)
        } header: {
            Text("Actions")
        } footer: {
            Text("Backup automatically syncs your goals, tasks, sessions, and badges to iCloud. Restore will replace local data with backup data.")
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
        } else if let error = syncStatus.lastError {
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
        isLoadingStats = true

        // Check CloudKit availability
        if let scheduler = container.cloudSyncScheduler {
            isCloudKitAvailable = await container.cloudBackupService?.isAvailable() ?? false
            syncStatus = await scheduler.getStatus()
        }

        // Load backup stats
        if let recoveryService = container.dataRecoveryService {
            backupStats = await recoveryService.getBackupStats()
        }

        isLoadingStats = false
    }

    private func syncNow() async {
        isSyncing = true
        if let scheduler = container.cloudSyncScheduler {
            await scheduler.syncNow()
            syncStatus = await scheduler.getStatus()
        }
        await loadBackupInfo()
        isSyncing = false
    }

    private func performRestore() async {
        isRestoring = true
        if let recoveryService = container.dataRecoveryService {
            do {
                restoreResult = try await recoveryService.restoreFromBackup()
                showRestoreResult = true
            } catch {
                restoreResult = RestoreResult(errors: [error.localizedDescription])
                showRestoreResult = true
            }
        }
        isRestoring = false
    }
}

#Preview {
    NavigationStack {
        BackupSettingsView()
            .environment(try! AppContainer.preview())
    }
}
