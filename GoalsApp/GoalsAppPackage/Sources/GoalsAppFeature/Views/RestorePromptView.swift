import SwiftUI

/// Modal view shown when backup is detected and local data is empty
public struct RestorePromptView: View {
    @Environment(\.dismiss) private var dismiss

    let stats: BackupStats
    let onRestore: () async -> Void
    let onStartFresh: () -> Void

    @State private var isRestoring = false
    @State private var restoreComplete = false

    public init(
        stats: BackupStats,
        onRestore: @escaping () async -> Void,
        onStartFresh: @escaping () -> Void
    ) {
        self.stats = stats
        self.onRestore = onRestore
        self.onStartFresh = onStartFresh
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                    .padding(.top, 32)

                // Title
                Text("Restore from Backup?")
                    .font(.title.bold())

                // Description
                Text("We found a backup of your data in iCloud. Would you like to restore it?")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Backup contents
                VStack(alignment: .leading, spacing: 12) {
                    Text("Backup contains:")
                        .font(.headline)

                    if stats.goalCount > 0 {
                        Label("\(stats.goalCount) goals", systemImage: "target")
                    }
                    if stats.taskCount > 0 {
                        Label("\(stats.taskCount) tasks", systemImage: "checkmark.circle")
                    }
                    if stats.sessionCount > 0 {
                        Label("\(stats.sessionCount) sessions", systemImage: "clock")
                    }
                    if stats.badgeCount > 0 {
                        Label("\(stats.badgeCount) badges", systemImage: "star")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    Button {
                        Task {
                            isRestoring = true
                            await onRestore()
                            isRestoring = false
                            restoreComplete = true
                        }
                    } label: {
                        if isRestoring {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Restore from Backup")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isRestoring)

                    Button {
                        onStartFresh()
                        dismiss()
                    } label: {
                        Text("Start Fresh")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isRestoring)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isRestoring)
            .onChange(of: restoreComplete) { _, complete in
                if complete {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    RestorePromptView(
        stats: BackupStats(recordCounts: [
            "Goal": 5,
            "TaskDefinition": 3,
            "TaskSession": 25,
            "EarnedBadge": 8
        ]),
        onRestore: {},
        onStartFresh: {}
    )
}
