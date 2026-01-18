import SwiftUI

/// A circular progress ring component
public struct ProgressRingView: View {
    let progress: Double
    var lineWidth: CGFloat = 10
    var size: CGFloat = 80
    var color: Color = .blue
    var backgroundColor: Color = .gray.opacity(0.2)

    public init(
        progress: Double,
        lineWidth: CGFloat = 10,
        size: CGFloat = 80,
        color: Color = .blue,
        backgroundColor: Color = .gray.opacity(0.2)
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.size = size
        self.color = color
        self.backgroundColor = backgroundColor
    }

    public var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 20) {
        ProgressRingView(progress: 0.75)

        ProgressRingView(progress: 0.5, lineWidth: 20, size: 150, color: .green)

        ProgressRingView(progress: 1.0, color: .purple)

        ProgressRingView(progress: 0.25, color: .orange)
    }
    .padding()
}
