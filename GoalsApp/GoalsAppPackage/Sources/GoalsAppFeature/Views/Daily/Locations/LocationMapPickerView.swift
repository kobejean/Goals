import SwiftUI
import MapKit

/// Map view for selecting a location with visual radius preview
public struct LocationMapPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let initialCoordinate: CLLocationCoordinate2D?
    let radius: Double
    let onSelect: (CLLocationCoordinate2D) -> Void

    @State private var position: MapCameraPosition
    @State private var selectedCoordinate: CLLocationCoordinate2D?

    public init(
        initialCoordinate: CLLocationCoordinate2D?,
        radius: Double,
        onSelect: @escaping (CLLocationCoordinate2D) -> Void
    ) {
        self.initialCoordinate = initialCoordinate
        self.radius = radius
        self.onSelect = onSelect

        // Initialize with provided coordinate or a default location
        let coord = initialCoordinate ?? CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503) // Tokyo
        _position = State(initialValue: .camera(MapCamera(
            centerCoordinate: coord,
            distance: 1000 // ~1km view distance
        )))
        _selectedCoordinate = State(initialValue: initialCoordinate)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                MapReader { proxy in
                    Map(position: $position) {
                        // Show radius circle if coordinate is selected
                        if let coord = selectedCoordinate {
                            MapCircle(center: coord, radius: radius)
                                .foregroundStyle(.blue.opacity(0.2))
                                .stroke(.blue, lineWidth: 2)

                            Annotation("", coordinate: coord) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .mapStyle(.standard)
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                        MapScaleView()
                    }
                    .onTapGesture { screenPoint in
                        if let coordinate = proxy.convert(screenPoint, from: .local) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCoordinate = coordinate
                            }
                        }
                    }
                }

                // Crosshair overlay
                VStack {
                    Spacer()

                    HStack {
                        Spacer()

                        if selectedCoordinate == nil {
                            VStack(spacing: 8) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.title2)
                                Text("Tap to select location")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }

                        Spacer()
                    }

                    Spacer()
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Select") {
                        if let coord = selectedCoordinate {
                            onSelect(coord)
                            dismiss()
                        }
                    }
                    .disabled(selectedCoordinate == nil)
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    if let coord = selectedCoordinate {
                        Text(String(format: "%.4f, %.4f", coord.latitude, coord.longitude))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    LocationMapPickerView(
        initialCoordinate: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
        radius: 100
    ) { _ in }
}
