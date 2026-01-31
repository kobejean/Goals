import SwiftUI
import GoalsDomain

/// Settings view for managing location definitions
public struct LocationSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let locations: [LocationDefinition]
    let onCreateLocation: (LocationDefinition) -> Void
    let onUpdateLocation: (LocationDefinition) -> Void
    let onDeleteLocation: (LocationDefinition) -> Void

    @State private var showingAddSheet = false
    @State private var locationToEdit: LocationDefinition?

    public var body: some View {
        NavigationStack {
            List {
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
        onCreateLocation: @escaping (LocationDefinition) -> Void,
        onUpdateLocation: @escaping (LocationDefinition) -> Void,
        onDeleteLocation: @escaping (LocationDefinition) -> Void
    ) {
        self.locations = locations
        self.onCreateLocation = onCreateLocation
        self.onUpdateLocation = onUpdateLocation
        self.onDeleteLocation = onDeleteLocation
    }
}

#Preview {
    LocationSettingsView(
        locations: [
            LocationDefinition(name: "Home", latitude: 35.6762, longitude: 139.6503, color: .blue, icon: "house.fill"),
            LocationDefinition(name: "Office", latitude: 35.6812, longitude: 139.7671, color: .green, icon: "building.2.fill")
        ],
        onCreateLocation: { _ in },
        onUpdateLocation: { _ in },
        onDeleteLocation: { _ in }
    )
}
