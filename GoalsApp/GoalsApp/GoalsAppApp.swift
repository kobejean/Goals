import SwiftUI
import SwiftData
import GoalsAppFeature

@main
struct GoalsAppApp: App {
    @State private var container: AppContainer?
    @State private var initError: Error?

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
            container = try AppContainer()
        } catch {
            initError = error
            print("Failed to initialize AppContainer: \(error)")
        }
    }
}
