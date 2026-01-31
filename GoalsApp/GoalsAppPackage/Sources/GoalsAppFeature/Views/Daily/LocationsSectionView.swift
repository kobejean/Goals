import SwiftUI
import CoreLocation
import MapKit
import GoalsDomain

/// Section view for location tracking within the Daily tab
public struct LocationsSectionView: View {
    @Environment(AppContainer.self) private var container
    @State private var showingSettings = false

    private var viewModel: LocationsViewModel {
        container.locationsViewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Permission prompt if needed
                if viewModel.authorizationStatus == .notDetermined {
                    LocationPermissionPromptView {
                        viewModel.requestLocationPermission()
                    }
                } else if viewModel.authorizationStatus == .denied || viewModel.authorizationStatus == .restricted {
                    LocationPermissionDeniedView()
                } else if viewModel.locations.isEmpty {
                    // Empty state
                    EmptyLocationsView {
                        showingSettings = true
                    }
                } else {
                    // Map showing all locations and user position
                    LocationsMapView(
                        locations: viewModel.locations,
                        activeLocationId: viewModel.activeSession?.locationId
                    )

                    // Location toggle panel
                    LocationTogglePanel(
                        locations: viewModel.locations,
                        activeLocationId: viewModel.activeSession?.locationId,
                        todayDurationForLocation: { locationId in
                            viewModel.todayDuration(for: locationId)
                        },
                        timerTick: viewModel.timerTick,
                        onToggle: { location in
                            Task {
                                await viewModel.toggleLocation(location)
                            }
                        }
                    )

                    // Today's summary
                    TodayLocationSummarySection(
                        locations: viewModel.locations,
                        todayDurationForLocation: { locationId in
                            viewModel.todayDuration(for: locationId)
                        }
                    )
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            LocationSettingsView(
                locations: viewModel.locations,
                isPathTrackingEnabled: viewModel.isPathTrackingEnabled,
                onCreateLocation: { location in
                    Task {
                        await viewModel.createLocation(location)
                    }
                },
                onUpdateLocation: { location in
                    Task {
                        await viewModel.updateLocation(location)
                    }
                },
                onDeleteLocation: { location in
                    Task {
                        await viewModel.deleteLocation(location)
                    }
                },
                onSetPathTracking: { enabled in
                    Task {
                        await viewModel.setPathTrackingEnabled(enabled)
                    }
                }
            )
        }
        .task {
            await viewModel.loadData()
            await viewModel.startTracking()
        }
    }

    public init() {}
}

// MARK: - Permission Views

/// Prompt to request location permission
private struct LocationPermissionPromptView: View {
    let onRequestPermission: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Location Access Required")
                .font(.headline)

            Text("Goals needs location access to automatically track time spent at your configured locations.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                onRequestPermission()
            } label: {
                Label("Enable Location", systemImage: "location.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 40)
    }
}

/// View shown when location permission is denied
private struct LocationPermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Location Access Denied")
                .font(.headline)

            Text("Please enable location access in Settings to use automatic location tracking.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open Settings", systemImage: "gear")
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 40)
    }
}

/// Empty state view when no locations exist
private struct EmptyLocationsView: View {
    let onAddLocation: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Locations Yet")
                .font(.headline)

            Text("Add locations to automatically track time spent at home, office, gym, and more.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                onAddLocation()
            } label: {
                Label("Add Location", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Location Toggle Panel

/// Grid of toggleable location buttons
private struct LocationTogglePanel: View {
    let locations: [LocationDefinition]
    let activeLocationId: UUID?
    let todayDurationForLocation: (UUID) -> TimeInterval
    let timerTick: Date
    let onToggle: (LocationDefinition) -> Void

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(locations) { location in
                LocationToggleButton(
                    location: location,
                    isActive: activeLocationId == location.id,
                    todayDuration: todayDurationForLocation(location.id),
                    timerTick: timerTick,
                    onToggle: { onToggle(location) }
                )
            }
        }
    }
}

/// Individual location toggle button
private struct LocationToggleButton: View {
    let location: LocationDefinition
    let isActive: Bool
    let todayDuration: TimeInterval
    let timerTick: Date
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 8) {
                Image(systemName: location.icon)
                    .font(.title2)
                    .foregroundStyle(isActive ? .white : location.color.swiftUIColor)

                Text(location.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isActive ? .white : .primary)
                    .lineLimit(1)

                Text(formatDuration(todayDuration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(isActive ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isActive ? location.color.swiftUIColor : Color.gray.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isActive ? Color.clear : location.color.swiftUIColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "0m"
        }
    }
}

// MARK: - Today's Summary Section

/// Section showing today's summary per location
private struct TodayLocationSummarySection: View {
    let locations: [LocationDefinition]
    let todayDurationForLocation: (UUID) -> TimeInterval

    private var totalDuration: TimeInterval {
        locations.reduce(0) { $0 + todayDurationForLocation($1.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Summary")
                    .font(.headline)

                Spacer()

                Text(formatDuration(totalDuration))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ForEach(locations) { location in
                let duration = todayDurationForLocation(location.id)
                if duration > 0 {
                    HStack {
                        Image(systemName: location.icon)
                            .foregroundStyle(location.color.swiftUIColor)
                            .frame(width: 24)

                        Text(location.name)
                            .font(.subheadline)

                        Spacer()

                        Text(formatDuration(duration))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if totalDuration == 0 {
                Text("No time tracked today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.15))
        )
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "0m"
        }
    }
}

#Preview {
    NavigationStack {
        LocationsSectionView()
    }
    .environment(try! AppContainer.preview())
}
