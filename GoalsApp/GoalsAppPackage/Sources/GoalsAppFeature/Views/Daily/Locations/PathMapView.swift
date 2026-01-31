import SwiftUI
import MapKit
import GoalsDomain

/// Displays a path visualization on a map showing daily movement
struct PathMapView: View {
    let pathEntries: [PathEntry]
    let locations: [LocationDefinition]

    @State private var position: MapCameraPosition = .automatic

    private var sortedPath: [PathEntry] {
        pathEntries.sortedByTime
    }

    private var pathCoordinates: [CLLocationCoordinate2D] {
        sortedPath.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        Map(position: $position) {
            // Draw the path as a polyline
            if pathCoordinates.count >= 2 {
                MapPolyline(coordinates: pathCoordinates)
                    .stroke(.cyan.opacity(0.8), lineWidth: 3)
            }

            // Show path points with time-based gradient
            ForEach(Array(sortedPath.enumerated()), id: \.element.id) { index, entry in
                let progress = Double(index) / Double(max(sortedPath.count - 1, 1))
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude)) {
                    Circle()
                        .fill(pathGradientColor(progress: progress))
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                }
            }

            // Show configured locations as markers
            ForEach(locations) { location in
                Annotation(location.name, coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)) {
                    ZStack {
                        Circle()
                            .fill(location.color.swiftUIColor.opacity(0.3))
                            .frame(width: 32, height: 32)
                        Image(systemName: location.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(location.color.swiftUIColor)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    /// Returns a color based on time progress (blue = early, cyan = mid, green = recent)
    private func pathGradientColor(progress: Double) -> Color {
        if progress < 0.5 {
            // Blue to cyan
            return Color(
                red: 0.0,
                green: 0.5 + progress,
                blue: 1.0 - progress * 0.5
            )
        } else {
            // Cyan to green
            let adjustedProgress = (progress - 0.5) * 2
            return Color(
                red: 0.0,
                green: 0.8 + adjustedProgress * 0.2,
                blue: 0.5 - adjustedProgress * 0.5
            )
        }
    }
}

// MARK: - Path Stats View

/// Shows statistics about the path data
struct PathStatsView: View {
    let pathEntries: [PathEntry]

    private var sortedPath: [PathEntry] {
        pathEntries.sortedByTime
    }

    private var timeRange: String {
        guard let first = sortedPath.first, let last = sortedPath.last else {
            return "No data"
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: first.timestamp)) - \(formatter.string(from: last.timestamp))"
    }

    private var totalDistance: Double {
        guard sortedPath.count >= 2 else { return 0 }
        var distance: Double = 0
        for i in 1..<sortedPath.count {
            let prev = CLLocation(latitude: sortedPath[i-1].latitude, longitude: sortedPath[i-1].longitude)
            let curr = CLLocation(latitude: sortedPath[i].latitude, longitude: sortedPath[i].longitude)
            distance += prev.distance(from: curr)
        }
        return distance
    }

    private var formattedDistance: String {
        if totalDistance >= 1000 {
            return String(format: "%.1f km", totalDistance / 1000)
        } else {
            return String(format: "%.0f m", totalDistance)
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            StatItem(icon: "point.topleft.down.to.point.bottomright.curvepath", value: "\(pathEntries.count)", label: "Points")
            StatItem(icon: "clock", value: timeRange, label: "Time Range")
            StatItem(icon: "arrow.left.and.right", value: formattedDistance, label: "Distance")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

private struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    let samplePath = (0..<20).map { i in
        PathEntry(
            timestamp: Date().addingTimeInterval(TimeInterval(-3600 + i * 180)),
            latitude: 35.6762 + Double(i) * 0.001,
            longitude: 139.6503 + Double(i) * 0.0015,
            horizontalAccuracy: 10
        )
    }

    let sampleLocations = [
        LocationDefinition(name: "Home", latitude: 35.6762, longitude: 139.6503, color: .blue, icon: "house.fill"),
        LocationDefinition(name: "Office", latitude: 35.695, longitude: 139.68, color: .green, icon: "building.2.fill")
    ]

    return VStack {
        PathMapView(pathEntries: samplePath, locations: sampleLocations)
        PathStatsView(pathEntries: samplePath)
    }
    .padding()
}
