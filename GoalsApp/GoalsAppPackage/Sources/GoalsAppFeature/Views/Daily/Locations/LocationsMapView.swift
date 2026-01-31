import SwiftUI
import MapKit
import GoalsDomain

/// Map view showing user location and configured location regions
struct LocationsMapView: View {
    let locations: [LocationDefinition]
    let activeLocationId: UUID?

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var isExpanded = false

    private var mapHeight: CGFloat {
        isExpanded ? 400 : 200
    }

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $position) {
                // User location is shown automatically when authorized
                UserAnnotation()

                // Show all configured locations with their radii
                ForEach(locations) { location in
                    let isActive = location.id == activeLocationId
                    let coordinate = CLLocationCoordinate2D(
                        latitude: location.latitude,
                        longitude: location.longitude
                    )

                    // Radius circle
                    MapCircle(center: coordinate, radius: location.radiusMeters)
                        .foregroundStyle(location.color.swiftUIColor.opacity(isActive ? 0.35 : 0.2))
                        .stroke(location.color.swiftUIColor, lineWidth: isActive ? 3 : 2)

                    // Location marker
                    Annotation(location.name, coordinate: coordinate) {
                        LocationMarker(
                            icon: location.icon,
                            color: location.color.swiftUIColor,
                            isActive: isActive
                        )
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .frame(height: mapHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .animation(.easeInOut(duration: 0.3), value: isExpanded)

            // Expand/collapse button
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                    Text(isExpanded ? "Show Less" : "Show More")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
            }
        }
        .onAppear {
            // If we have locations, fit the map to show all of them
            if !locations.isEmpty {
                fitToLocations()
            }
        }
        .onChange(of: locations) { _, newLocations in
            if !newLocations.isEmpty {
                fitToLocations()
            }
        }
    }

    private func fitToLocations() {
        guard !locations.isEmpty else { return }

        // Calculate bounding region for all locations
        let coordinates = locations.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }

        let minLat = coordinates.map(\.latitude).min() ?? 0
        let maxLat = coordinates.map(\.latitude).max() ?? 0
        let minLon = coordinates.map(\.longitude).min() ?? 0
        let maxLon = coordinates.map(\.longitude).max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        // Calculate span with some padding
        let latDelta = max((maxLat - minLat) * 1.5, 0.01)
        let lonDelta = max((maxLon - minLon) * 1.5, 0.01)

        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )

        withAnimation {
            position = .region(region)
        }
    }
}

/// Custom marker for location annotations
private struct LocationMarker: View {
    let icon: String
    let color: Color
    let isActive: Bool

    var body: some View {
        ZStack {
            // Outer ring for active state
            if isActive {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 44, height: 44)
            }

            // Main marker
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)

            // Icon
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .animation(.easeInOut(duration: 0.3), value: isActive)
    }
}

#Preview {
    LocationsMapView(
        locations: [
            LocationDefinition(
                name: "Home",
                latitude: 35.6762,
                longitude: 139.6503,
                radiusMeters: 100,
                color: .blue,
                icon: "house.fill"
            ),
            LocationDefinition(
                name: "Office",
                latitude: 35.6812,
                longitude: 139.7671,
                radiusMeters: 150,
                color: .green,
                icon: "building.2.fill"
            ),
            LocationDefinition(
                name: "Gym",
                latitude: 35.6895,
                longitude: 139.6917,
                radiusMeters: 80,
                color: .orange,
                icon: "dumbbell.fill"
            )
        ],
        activeLocationId: nil
    )
    .padding()
}
