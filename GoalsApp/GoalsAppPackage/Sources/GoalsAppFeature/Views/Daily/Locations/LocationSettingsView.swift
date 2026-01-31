import SwiftUI
import GoalsDomain

/// Settings view for managing location definitions
public struct LocationSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let locations: [LocationDefinition]
    let isPathTrackingEnabled: Bool
    let onCreateLocation: (LocationDefinition) -> Void
    let onUpdateLocation: (LocationDefinition) -> Void
    let onDeleteLocation: (LocationDefinition) -> Void
    let onSetPathTracking: (Bool) -> Void

    @State private var showingAddSheet = false
    @State private var locationToEdit: LocationDefinition?

    public var body: some View {
        NavigationStack {
            List {
                // Path tracking toggle
                Section {
                    Toggle(isOn: Binding(
                        get: { isPathTrackingEnabled },
                        set: { onSetPathTracking($0) }
                    )) {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Track Daily Path")
                                Text("Record your movement throughout the day")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                        }
                    }
                } footer: {
                    Text("Path data is stored locally and kept for 7 days. Updates every ~50 meters.")
                }

                if locations.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "location.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)

                            Text("No locations configured")
                                .font(.headline)

                            Text("Add locations to start tracking time automatically.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                } else {
                    Section("Locations") {
                        ForEach(locations) { location in
                            Button {
                                locationToEdit = location
                            } label: {
                                HStack {
                                    Image(systemName: location.icon)
                                        .foregroundStyle(location.color.swiftUIColor)
                                        .frame(width: 32)

                                    VStack(alignment: .leading) {
                                        Text(location.name)
                                            .foregroundStyle(.primary)
                                        Text("\(Int(location.radiusMeters))m radius")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                onDeleteLocation(locations[index])
                            }
                        }
                    }
                }

                Section {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add Location", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Location Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                LocationEditorView(
                    mode: .create,
                    onSave: { location in
                        onCreateLocation(location)
                    }
                )
            }
            .sheet(item: $locationToEdit) { location in
                LocationEditorView(
                    mode: .edit(location),
                    onSave: { updatedLocation in
                        onUpdateLocation(updatedLocation)
                    }
                )
            }
        }
    }

    public init(
        locations: [LocationDefinition],
        isPathTrackingEnabled: Bool,
        onCreateLocation: @escaping (LocationDefinition) -> Void,
        onUpdateLocation: @escaping (LocationDefinition) -> Void,
        onDeleteLocation: @escaping (LocationDefinition) -> Void,
        onSetPathTracking: @escaping (Bool) -> Void
    ) {
        self.locations = locations
        self.isPathTrackingEnabled = isPathTrackingEnabled
        self.onCreateLocation = onCreateLocation
        self.onUpdateLocation = onUpdateLocation
        self.onDeleteLocation = onDeleteLocation
        self.onSetPathTracking = onSetPathTracking
    }
}

#Preview {
    LocationSettingsView(
        locations: [
            LocationDefinition(name: "Home", latitude: 35.6762, longitude: 139.6503, color: .blue, icon: "house.fill"),
            LocationDefinition(name: "Office", latitude: 35.6812, longitude: 139.7671, color: .green, icon: "building.2.fill")
        ],
        isPathTrackingEnabled: false,
        onCreateLocation: { _ in },
        onUpdateLocation: { _ in },
        onDeleteLocation: { _ in },
        onSetPathTracking: { _ in }
    )
}
