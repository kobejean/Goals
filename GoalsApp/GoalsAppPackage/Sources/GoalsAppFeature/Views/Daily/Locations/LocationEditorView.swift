import SwiftUI
import MapKit
import GoalsDomain

/// View for creating or editing a location definition
public struct LocationEditorView: View {
    @Environment(\.dismiss) private var dismiss

    public enum Mode {
        case create
        case edit(LocationDefinition)
    }

    let mode: Mode
    let onSave: (LocationDefinition) -> Void

    @State private var name: String = ""
    @State private var selectedColor: LocationColor = .blue
    @State private var selectedIcon: String = "mappin.circle.fill"
    @State private var radiusMeters: Double = 100
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var showingMapPicker = false

    private var isValid: Bool {
        !name.isEmpty && coordinate != nil
    }

    private var existingLocation: LocationDefinition? {
        if case .edit(let location) = mode {
            return location
        }
        return nil
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Location name", text: $name)
                }

                Section("Location") {
                    if let coord = coordinate {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Coordinates")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.4f, %.4f", coord.latitude, coord.longitude))
                                    .font(.subheadline.monospacedDigit())
                            }

                            Spacer()

                            Button("Change") {
                                showingMapPicker = true
                            }
                        }
                    } else {
                        Button {
                            showingMapPicker = true
                        } label: {
                            Label("Select on Map", systemImage: "map")
                        }
                    }
                }

                Section("Radius") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Detection radius")
                            Spacer()
                            Text("\(Int(radiusMeters))m")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $radiusMeters, in: 50...500, step: 10)
                    }
                }

                Section("Appearance") {
                    // Color picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color")
                            .font(.subheadline)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(LocationColor.allCases, id: \.self) { color in
                                Button {
                                    selectedColor = color
                                } label: {
                                    Circle()
                                        .fill(color.swiftUIColor)
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                                                .padding(2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // Icon picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Icon")
                            .font(.subheadline)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                            ForEach(Self.availableIcons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.title3)
                                        .foregroundStyle(selectedIcon == icon ? selectedColor.swiftUIColor : .secondary)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedIcon == icon ? selectedColor.swiftUIColor.opacity(0.2) : Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(existingLocation != nil ? "Edit Location" : "New Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveLocation()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingMapPicker) {
                LocationMapPickerView(
                    initialCoordinate: coordinate,
                    radius: radiusMeters
                ) { selectedCoord in
                    coordinate = selectedCoord
                }
            }
            .onAppear {
                if let location = existingLocation {
                    name = location.name
                    selectedColor = location.color
                    selectedIcon = location.icon
                    radiusMeters = location.radiusMeters
                    coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                }
            }
        }
    }

    private func saveLocation() {
        guard let coord = coordinate else { return }

        let location = LocationDefinition(
            id: existingLocation?.id ?? UUID(),
            name: name,
            latitude: coord.latitude,
            longitude: coord.longitude,
            radiusMeters: radiusMeters,
            color: selectedColor,
            icon: selectedIcon,
            isArchived: false,
            createdAt: existingLocation?.createdAt ?? Date(),
            updatedAt: Date(),
            sortOrder: existingLocation?.sortOrder ?? 0
        )

        onSave(location)
        dismiss()
    }

    // Available icons for location types
    private static let availableIcons = [
        "mappin.circle.fill",
        "house.fill",
        "building.2.fill",
        "figure.run",
        "dumbbell.fill",
        "book.fill",
        "cart.fill",
        "cup.and.saucer.fill",
        "fork.knife",
        "bed.double.fill"
    ]

    public init(mode: Mode, onSave: @escaping (LocationDefinition) -> Void) {
        self.mode = mode
        self.onSave = onSave
    }
}

#Preview("Create") {
    LocationEditorView(mode: .create) { _ in }
}

#Preview("Edit") {
    LocationEditorView(
        mode: .edit(LocationDefinition(
            name: "Home",
            latitude: 35.6762,
            longitude: 139.6503,
            color: .blue,
            icon: "house.fill"
        ))
    ) { _ in }
}
