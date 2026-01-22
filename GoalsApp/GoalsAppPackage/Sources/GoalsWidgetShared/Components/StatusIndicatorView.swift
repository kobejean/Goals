import SwiftUI

/// Status of data fetching for an insight
public enum InsightFetchStatus: Sendable {
    case idle
    case loading
    case success
    case error
}

/// A small dot indicator showing fetch status
/// - Green: success
/// - Blinking yellow: loading
/// - Red: error
public struct StatusIndicatorView: View {
    public let status: InsightFetchStatus

    @State private var isBlinking = false

    private let dotSize: CGFloat = 6

    public init(status: InsightFetchStatus) {
        self.status = status
    }

    public var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: dotSize, height: dotSize)
            .opacity(blinkOpacity)
            .animation(blinkAnimation, value: isBlinking)
            .onAppear {
                if status == .loading {
                    isBlinking = true
                }
            }
            .onChange(of: status) { _, newStatus in
                isBlinking = newStatus == .loading
            }
    }

    private var statusColor: Color {
        switch status {
        case .idle:
            return .gray
        case .loading:
            return .yellow
        case .success:
            return .green
        case .error:
            return .red
        }
    }

    private var blinkOpacity: Double {
        if status == .loading {
            return isBlinking ? 0.3 : 1.0
        }
        return 1.0
    }

    private var blinkAnimation: Animation? {
        if status == .loading {
            return .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
        }
        return nil
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            Text("Idle")
            Spacer()
            StatusIndicatorView(status: .idle)
        }
        HStack {
            Text("Loading")
            Spacer()
            StatusIndicatorView(status: .loading)
        }
        HStack {
            Text("Success")
            Spacer()
            StatusIndicatorView(status: .success)
        }
        HStack {
            Text("Error")
            Spacer()
            StatusIndicatorView(status: .error)
        }
    }
    .padding()
}
