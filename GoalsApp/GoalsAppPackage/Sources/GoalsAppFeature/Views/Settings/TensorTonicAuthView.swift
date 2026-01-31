import SwiftUI
import WebKit
import GoalsDomain
import GoalsData

/// View that handles TensorTonic authentication via embedded WebView
public struct TensorTonicAuthView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container

    let onAuthenticated: (String, String) -> Void

    @State private var isLoading = true
    @State private var authState: AuthState = .loading

    enum AuthState {
        case loading
        case authenticating
        case extractingCredentials
        case success
        case error(String)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                TensorTonicWebView(
                    onAuthenticated: handleAuthentication,
                    onLoadingChanged: { isLoading = $0 }
                )

                if isLoading {
                    ProgressView("Loading...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                if case .extractingCredentials = authState {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Extracting credentials...")
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                if case .success = authState {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        Text("Authenticated!")
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                if case .error(let message) = authState {
                    VStack(spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text(message)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("Sign in to TensorTonic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func handleAuthentication(sessionToken: String) {
        authState = .extractingCredentials

        Task {
            do {
                // Fetch user info from session endpoint
                let userId = try await fetchUserId(sessionToken: sessionToken)

                // Configure the data source
                let settings = DataSourceSettings(
                    dataSourceType: .tensorTonic,
                    credentials: ["userId": userId, "sessionToken": sessionToken]
                )
                try await container.tensorTonicDataSource.configure(settings: settings)

                // Save to UserDefaults
                UserDefaults.standard.tensorTonicUserId = userId
                UserDefaults.standard.tensorTonicSessionToken = sessionToken

                container.notifySettingsChanged()

                authState = .success
                onAuthenticated(userId, sessionToken)

                try? await Task.sleep(for: .seconds(1))
                dismiss()
            } catch {
                authState = .error("Failed to get user info: \(error.localizedDescription)")
            }
        }
    }

    private func fetchUserId(sessionToken: String) async throws -> String {
        let url = URL(string: "https://www.tensortonic.com/api/auth/get-session")!
        var request = URLRequest(url: url)
        request.setValue("__Secure-better-auth.session_token=\(sessionToken)", forHTTPHeaderField: "Cookie")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.sessionFetchFailed
        }

        let sessionResponse = try JSONDecoder().decode(SessionResponse.self, from: data)
        return sessionResponse.user.id
    }

    enum AuthError: Error, LocalizedError {
        case sessionFetchFailed

        var errorDescription: String? {
            switch self {
            case .sessionFetchFailed:
                return "Failed to fetch session information"
            }
        }
    }
}

// MARK: - Session Response Model

private struct SessionResponse: Decodable {
    let session: Session
    let user: User

    struct Session: Decodable {
        let token: String
        let userId: String
        let expiresAt: String
    }

    struct User: Decodable {
        let id: String
        let name: String
        let email: String
        let username: String?
    }
}

// MARK: - WebView

struct TensorTonicWebView: UIViewRepresentable {
    let onAuthenticated: (String) -> Void
    let onLoadingChanged: (Bool) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Load TensorTonic login page
        let url = URL(string: "https://www.tensortonic.com/login")!
        webView.load(URLRequest(url: url))

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onAuthenticated: onAuthenticated, onLoadingChanged: onLoadingChanged)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let onAuthenticated: (String) -> Void
        let onLoadingChanged: (Bool) -> Void
        private var hasExtractedCredentials = false

        init(onAuthenticated: @escaping (String) -> Void, onLoadingChanged: @escaping (Bool) -> Void) {
            self.onAuthenticated = onAuthenticated
            self.onLoadingChanged = onLoadingChanged
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            onLoadingChanged(true)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onLoadingChanged(false)

            // Check if we've landed on a page that indicates successful login
            guard let url = webView.url else { return }

            // User is authenticated if they reach profile, dashboard, or main pages
            let authenticatedPaths = ["/profile", "/dashboard", "/problems", "/research", "/leaderboard"]
            let isAuthenticated = authenticatedPaths.contains { url.path.hasPrefix($0) }

            // Also check if we're on home page but not login page
            let isHomePage = url.path == "/" || url.path.isEmpty
            let isLoginPage = url.path.contains("/login")

            if (isAuthenticated || (isHomePage && !isLoginPage)) && !hasExtractedCredentials {
                extractSessionCookie(from: webView)
            }
        }

        private func extractSessionCookie(from webView: WKWebView) {
            hasExtractedCredentials = true

            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
                // Look for the session token cookie
                for cookie in cookies {
                    if cookie.name == "__Secure-better-auth.session_token" {
                        // The cookie value contains the full token (including signature)
                        let sessionToken = cookie.value
                        DispatchQueue.main.async {
                            self?.onAuthenticated(sessionToken)
                        }
                        return
                    }
                }

                // Cookie not found - user might not be fully logged in
                DispatchQueue.main.async {
                    self?.hasExtractedCredentials = false
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onLoadingChanged(false)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onLoadingChanged(false)
        }
    }
}
