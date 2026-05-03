import MapKit
import SwiftUI

struct MacPlaceFilterDetailView: View {
    let options: [MacPlaceFilterOption]
    @Binding var selectedPlaceID: UUID?
    @Binding var hideUnavailableRoutines: Bool
    let showAvailabilityToggle: Bool
    let currentLocation: LocationCoordinate?
    let taskListMode: HomeFeature.TaskListMode
    let manualPlaceFilterDescription: String
    let locationStatusText: String?
    let onManagePlaces: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Place Filter")
                        .font(.largeTitle.weight(.semibold))

                    Text("Choose a saved place from the list and filter the current sidebar by that location.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                MacPlaceFilterPanel(
                    options: options,
                    selectedPlaceID: $selectedPlaceID,
                    hideUnavailableRoutines: $hideUnavailableRoutines,
                    showAvailabilityToggle: showAvailabilityToggle,
                    currentLocation: currentLocation,
                    taskListMode: taskListMode,
                    manualPlaceFilterDescription: manualPlaceFilterDescription,
                    locationStatusText: locationStatusText,
                    onManagePlaces: onManagePlaces
                )
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct MacPlaceFilterPanel: View {
    let options: [MacPlaceFilterOption]
    @Binding var selectedPlaceID: UUID?
    @Binding var hideUnavailableRoutines: Bool
    let showAvailabilityToggle: Bool
    let currentLocation: LocationCoordinate?
    let taskListMode: HomeFeature.TaskListMode
    let manualPlaceFilterDescription: String
    let locationStatusText: String?
    let onManagePlaces: () -> Void

    @State private var mapPosition: MapCameraPosition

    init(
        options: [MacPlaceFilterOption],
        selectedPlaceID: Binding<UUID?>,
        hideUnavailableRoutines: Binding<Bool>,
        showAvailabilityToggle: Bool,
        currentLocation: LocationCoordinate?,
        taskListMode: HomeFeature.TaskListMode,
        manualPlaceFilterDescription: String,
        locationStatusText: String?,
        onManagePlaces: @escaping () -> Void
    ) {
        self.options = options
        _selectedPlaceID = selectedPlaceID
        _hideUnavailableRoutines = hideUnavailableRoutines
        self.showAvailabilityToggle = showAvailabilityToggle
        self.currentLocation = currentLocation
        self.taskListMode = taskListMode
        self.manualPlaceFilterDescription = manualPlaceFilterDescription
        self.locationStatusText = locationStatusText
        self.onManagePlaces = onManagePlaces
        _mapPosition = State(
            initialValue: MacPlaceFilterMapCamera.position(
                options: options,
                selectedPlaceID: selectedPlaceID.wrappedValue,
                currentLocation: currentLocation
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelHeader
            panelContent
            panelFooter
        }
        .onAppear(perform: updateMapPosition)
        .onChange(of: selectedPlaceID) { _, _ in
            updateMapPosition()
        }
        .onChange(of: options) { _, _ in
            updateMapPosition()
        }
        .onChange(of: currentLocation) { _, _ in
            updateMapPosition()
        }
    }

    private var panelHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Label("Places", systemImage: "location.viewfinder")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if selectedPlaceID != nil {
                Button("Clear") {
                    selectedPlaceID = nil
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            }

            Button("Manage") {
                onManagePlaces()
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.accentColor)
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        if options.isEmpty {
            Text("Save places in Settings to filter routines with a map-based view here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HStack(alignment: .top, spacing: 12) {
                placeListColumn

                Divider()
                    .padding(.vertical, 2)

                mapPreview
            }
            .frame(height: 340)
        }
    }

    @ViewBuilder
    private var panelFooter: some View {
        if showAvailabilityToggle {
            Toggle("Hide unavailable \(allItemsPluralNoun)", isOn: $hideUnavailableRoutines)
                .toggleStyle(.switch)
                .font(.caption)
        }

        Text(manualPlaceFilterDescription)
            .font(.caption)
            .foregroundStyle(.secondary)

        if let locationStatusText {
            Text(locationStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var placeListColumn: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                MacPlaceFilterAllItemsRow(
                    taskListMode: taskListMode,
                    isSelected: selectedPlaceID == nil
                ) {
                    selectedPlaceID = nil
                }

                ForEach(options) { option in
                    MacPlaceFilterRow(
                        option: option,
                        isSelected: selectedPlaceID == option.id
                    ) {
                        selectedPlaceID = option.id
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var allItemsPluralNoun: String {
        switch taskListMode {
        case .all:
            return "tasks"
        case .routines:
            return "routines"
        case .todos:
            return "todos"
        }
    }

    private var mapPreview: some View {
        MacPlaceFilterMapPreview(
            options: options,
            selectedPlaceID: selectedPlaceID,
            currentLocation: currentLocation,
            mapPosition: $mapPosition
        )
    }

    private func updateMapPosition() {
        withAnimation(.snappy(duration: 0.3)) {
            mapPosition = MacPlaceFilterMapCamera.position(
                options: options,
                selectedPlaceID: selectedPlaceID,
                currentLocation: currentLocation
            )
        }
    }
}
