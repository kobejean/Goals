import SwiftUI

/// Badge displaying a trend percentage with visual indicator
struct TrendBadge: View {
    let trend: Double

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
            Text(String(format: "%.1f%%", abs(trend)))
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(trend >= 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
        .foregroundStyle(trend >= 0 ? .green : .red)
        .clipShape(Capsule())
    }
}
