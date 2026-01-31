import SwiftUI
import SwiftData
import GoalsAppFeature

@main
struct GoalsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var container: AppContainer?
    @State private var initError: Error?
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = container {
                    ContentView()
                        .environment(container)
                        .modelContainer(container.modelContainer)
                } else if let error = initError {
                    errorView(error)
                } else {
                    loadingView
                }
            }
            .task {
                await initializeApp()
            }
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        guard let _ = container else { return }

        switch phase {
        case .active:
            // TODO: Re-enable BGM player when ready
            // Resume BGM when app becomes active
            // if container.bgmPlayer.state == .stopped {
            //     do {
            //         try container.bgmPlayer.play(playlist: [
            //             .init(.bowlingResults, loopCount: 5),
            //             .init(.tennisResults, loopCount: 3),
            //             .init(.golfCourseSelect, loopCount: 5),
            //             .init(.golfGameResults, loopCount: 3),
            //             .init(.konohaNoHiru, loopCount: 2)
            //         ].shuffled())
            //     } catch {
            //         print("Failed to play BGM: \(error)")
            //     }
            // } else {
            //     container.bgmPlayer.resumeWithFadeIn()
            // }
            break
        case .inactive, .background:
            // Fade out BGM when app goes to background
            // container.bgmPlayer.fadeOutAndPause()
            break
        @unknown default:
            break
        }
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading...")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)

            Text("Failed to initialize app")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    @MainActor
    private func initializeApp() async {
        do {
            let appContainer = try AppContainer()
            container = appContainer

            // Configure cloud backup (runs asynchronously)
            await appContainer.configureCloudBackup()

            // Schedule background refresh for widget data
            AppDelegate.scheduleBackgroundRefresh()

            // Schedule cloud sync
            AppDelegate.scheduleCloudSync()
        } catch {
            initError = error
            print("Failed to initialize AppContainer: \(error)")
        }
    }
}
