import ComposableArchitecture
import Foundation
import MapKit
import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

enum PlaceCheckInMapSheetLayout {
    case stack
    case workspace
    case controlsOnly
    case mapOnly
}

struct PlaceCheckInMapSheet: View {
    private let showsNavigationChrome: Bool
    private let showsInlineHeader: Bool
    private let layout: PlaceCheckInMapSheetLayout
    private let onClose: (() -> Void)?
    private let externalSelectedPlaceID: Binding<UUID?>?
    private let externalSelectedHistoryMarkerID: Binding<PlaceCheckInHistoryMapMarker.ID?>?

    @Dependency(\.locationClient) private var locationClient
    @Dependency(\.urlOpenerClient) private var urlOpenerClient
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \RoutinePlace.name) private var places: [RoutinePlace]
    @Query(sort: \PlaceCheckInSession.startedAt, order: .reverse) private var sessions: [PlaceCheckInSession]
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAutomaticPlaceCheckInEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAutomaticPlaceCheckInEnabled = true

    @State private var locationSnapshot = LocationSnapshot(authorizationStatus: .notDetermined)
    @State private var isLoadingLocation = false
    @State private var selectedMode = PlaceCheckInMapSheetMode.checkIns
    @State private var localSelectedPlaceID: UUID?
    @State private var localSelectedHistoryMarkerID: PlaceCheckInHistoryMapMarker.ID?
    @State private var visibleRegion = PlaceCheckInMapCamera.region(
        places: [],
        currentLocation: nil,
        selectedPlaceID: nil,
        historyCoordinates: []
    )
    @State private var mapPosition = PlaceCheckInMapCamera.position(
        region: PlaceCheckInMapCamera.region(
            places: [],
            currentLocation: nil,
            selectedPlaceID: nil,
            historyCoordinates: []
        )
    )
    @State private var errorText: String?
    @State private var editingSessionDraft: PlaceCheckInSessionEditDraft?
    @State private var deletionCandidate: PlaceCheckInSessionDeletionCandidate?
    @State private var editingPlaceDraft: PlaceCheckInPlaceEditDraft?
    @State private var placeDeletionCandidate: PlaceCheckInPlaceDeletionCandidate?
    @State private var newPlaceDraft: PlaceCheckInNewPlaceDraft?

    init(
        showsNavigationChrome: Bool = true,
        showsInlineHeader: Bool = true,
        layout: PlaceCheckInMapSheetLayout = .stack,
        onClose: (() -> Void)? = nil,
        selectedPlaceID: Binding<UUID?>? = nil,
        selectedHistoryMarkerID: Binding<PlaceCheckInHistoryMapMarker.ID?>? = nil
    ) {
        self.showsNavigationChrome = showsNavigationChrome
        self.showsInlineHeader = showsInlineHeader
        self.layout = layout
        self.onClose = onClose
        self.externalSelectedPlaceID = selectedPlaceID
        self.externalSelectedHistoryMarkerID = selectedHistoryMarkerID
        _localSelectedPlaceID = State(initialValue: selectedPlaceID?.wrappedValue)
        _localSelectedHistoryMarkerID = State(initialValue: selectedHistoryMarkerID?.wrappedValue)
    }

    private var selectedPlaceID: UUID? {
        get {
            externalSelectedPlaceID?.wrappedValue ?? localSelectedPlaceID
        }
        nonmutating set {
            if let externalSelectedPlaceID {
                externalSelectedPlaceID.wrappedValue = newValue
            } else {
                localSelectedPlaceID = newValue
            }
        }
    }

    private var selectedHistoryMarkerID: PlaceCheckInHistoryMapMarker.ID? {
        get {
            externalSelectedHistoryMarkerID?.wrappedValue ?? localSelectedHistoryMarkerID
        }
        nonmutating set {
            if let externalSelectedHistoryMarkerID {
                externalSelectedHistoryMarkerID.wrappedValue = newValue
            } else {
                localSelectedHistoryMarkerID = newValue
            }
        }
    }

    private var currentLocation: LocationCoordinate? {
        locationSnapshot.coordinate
    }

    private var activeSession: PlaceCheckInSession? {
        guard let activeSessionID = PlaceCheckInSupport.currentActiveSessionID(in: sessions) else {
            return nil
        }
        return sessions.first { $0.id == activeSessionID }
    }

    private var orderedPlaces: [RoutinePlace] {
        PlaceCheckInSupport.locationOrderedPlaces(
            places: places,
            coordinate: currentLocation,
            sessions: sessions
        )
    }

    private var selectedPlace: RoutinePlace? {
        guard let selectedPlaceID else { return nil }
        return places.first { $0.id == selectedPlaceID }
    }

    private var currentMatchedPlace: RoutinePlace? {
        guard let currentLocation else { return nil }
        return PlaceCheckInSupport.nearestContainingPlace(to: currentLocation, places: places)
    }

    private var historyMapMarkers: [PlaceCheckInHistoryMapMarker] {
        PlaceCheckInSupport.historyMapMarkers(from: sessions)
    }

    private var selectedHistoryMarker: PlaceCheckInHistoryMapMarker? {
        guard let selectedHistoryMarkerID else { return nil }
        return historyMapMarkers.first { $0.id == selectedHistoryMarkerID }
    }

    private var newPlaceNameBinding: Binding<String> {
        Binding(
            get: { newPlaceDraft?.name ?? "" },
            set: { name in
                newPlaceDraft?.name = name
                newPlaceDraft?.statusMessage = ""
            }
        )
    }

    private var newPlaceRadiusBinding: Binding<Double> {
        Binding(
            get: { newPlaceDraft?.radiusMeters ?? PlaceCheckInNewPlaceDraft.defaultRadiusMeters },
            set: { radiusMeters in
                newPlaceDraft?.radiusMeters = min(max(radiusMeters, 25), 2_000)
                newPlaceDraft?.statusMessage = ""
            }
        )
    }

    private var canSaveNewPlaceDraft: Bool {
        RoutinePlace.cleanedName(newPlaceDraft?.name) != nil
    }

    private var daySections: [PlaceCheckInDaySection] {
        PlaceCheckInSupport.groupedSessionsByDay(sessions, calendar: calendar)
    }

    var body: some View {
        Group {
            if showsNavigationChrome {
                NavigationStack {
                    mapContent
                        .navigationTitle("Check In")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    close()
                                }
                            }
                        }
                }
            } else {
                switch layout {
                case .workspace:
                    macWorkspaceContent
                case .controlsOnly:
                    macControlsContent
                case .mapOnly:
                    mapPreview
                        .padding(16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .stack:
                    VStack(spacing: 0) {
                        if showsInlineHeader {
                            inlineHeader
                            Divider()
                        }
                        mapContent
                    }
                }
            }
        }
        .task {
            syncMapPosition()
            await refreshLocation(requestAuthorizationIfNeeded: true)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshLocation(requestAuthorizationIfNeeded: true)
            }
        }
        .onChange(of: places.map(\.id)) { _, _ in
            if let selectedPlaceID, !places.contains(where: { $0.id == selectedPlaceID }) {
                self.selectedPlaceID = nil
            }
            syncMapPositionIfAllowed()
        }
        .onChange(of: historyMapMarkers.map(\.id)) { _, markerIDs in
            if let selectedHistoryMarkerID, !markerIDs.contains(selectedHistoryMarkerID) {
                self.selectedHistoryMarkerID = nil
            }
            syncMapPositionIfAllowed()
        }
        .onChange(of: selectedPlaceID) { _, _ in
            clearCurrentLocationDraftForExplicitSelection()
            syncMapPositionIfAllowed()
        }
        .onChange(of: selectedHistoryMarkerID) { _, _ in
            clearCurrentLocationDraftForExplicitSelection()
            syncMapPositionIfAllowed()
        }
        .sheet(item: $editingSessionDraft) { draft in
            PlaceCheckInSessionEditor(draft: draft) { updatedDraft in
                try saveEditedSession(updatedDraft)
            }
        }
        .sheet(item: $editingPlaceDraft) { draft in
            PlaceCheckInPlaceEditor(draft: draft) { updatedDraft in
                try saveEditedPlace(updatedDraft)
            }
        }
        .confirmationDialog(
            item: $deletionCandidate,
            titleVisibility: .visible
        ) { _ in
            Text("Delete Check-In?")
        } actions: { candidate in
            Button("Delete Check-In", role: .destructive) {
                deleteSession(id: candidate.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { candidate in
            Text("This removes the check-in at \(candidate.title) from your place timeline.")
        }
        .confirmationDialog(
            item: $placeDeletionCandidate,
            titleVisibility: .visible
        ) { _ in
            Text("Delete Place?")
        } actions: { candidate in
            Button("Delete Place", role: .destructive) {
                deletePlace(id: candidate.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { candidate in
            Text("This removes \(candidate.title) from saved places. Linked tasks will keep working, but they will no longer be tied to this place.")
        }
    }

    private var inlineHeader: some View {
        HStack(spacing: 10) {
            Label("Map Check-In", systemImage: "map")
                .font(.headline.weight(.semibold))

            Spacer(minLength: 8)

            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Close map check-in")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var mapContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            mapPreview

            currentLocationPanel

            Divider()

            mapDetailPicker
            mapDetailContent
            errorMessageView
        }
        .padding(16)
    }

    private var macControlsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                mapDetailPicker
                mapDetailContent
                errorMessageView
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var macWorkspaceContent: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                currentLocationPanel

                Divider()

                mapDetailPicker
                mapDetailContent
                    .frame(maxHeight: .infinity, alignment: .top)

                errorMessageView
            }
            .padding(18)
            .frame(width: 380)
            .frame(maxHeight: .infinity, alignment: .top)
            .routinaGlassPanel(cornerRadius: 0, tint: .teal, tintOpacity: 0.04)

            Divider()

            mapPreview
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mapDetailPicker: some View {
        Picker("Places view", selection: $selectedMode) {
            ForEach(PlaceCheckInMapSheetMode.allCases) { mode in
                Label(mode.title, systemImage: mode.systemImage)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var mapDetailContent: some View {
        switch selectedMode {
        case .checkIns:
            dayTimeline
        case .places:
            placesList
        }
    }

    @ViewBuilder
    private var errorMessageView: some View {
        if let errorText {
            Text(errorText)
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var mapPreview: some View {
        if layout == .workspace || layout == .mapOnly {
            mapSurface
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            mapSurface
                .frame(height: showsNavigationChrome ? 260 : 360)
        }
    }

    private var mapSurface: some View {
        MapReader { proxy in
            Map(position: $mapPosition) {
                UserAnnotation()

                ForEach(places) { place in
                    MapCircle(
                        center: place.mapCoordinate,
                        radius: place.radiusMeters
                    )
                    .foregroundStyle(placeMapTint(for: place).opacity(isSelected(place) ? 0.24 : 0.12))

                    Annotation(place.displayName, coordinate: place.mapCoordinate) {
                        placeAnnotationButton(place)
                    }
                }

                if let currentLocation {
                    Annotation("Current Location", coordinate: currentLocation.mapCoordinate) {
                        currentLocationAnnotation
                    }
                }

                ForEach(historyMapMarkers) { marker in
                    Annotation(marker.title, coordinate: marker.coordinate.mapCoordinate) {
                        historyMarkerButton(marker)
                    }
                }

                if let newPlaceDraft {
                    MapCircle(
                        center: newPlaceDraft.coordinate.mapCoordinate,
                        radius: newPlaceDraft.radiusMeters
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.18))

                    Marker("New Place", coordinate: newPlaceDraft.coordinate.mapCoordinate)
                        .tint(Color.accentColor)
                }
            }
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        guard let coordinate = proxy.convert(value.location, from: .local) else {
                            return
                        }

                        beginNewPlaceDraft(
                            at: LocationCoordinate(
                                latitude: coordinate.latitude,
                                longitude: coordinate.longitude
                            )
                        )
                    }
            )
        }
        .mapStyle(.standard)
        .onMapCameraChange { context in
            visibleRegion = context.region
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            if layout == .mapOnly {
                mapLocationActionPanel
                    .padding(10)
            } else {
                Text(mapTitle)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .routinaGlassPill()
                    .padding(10)
            }
        }
        .overlay(alignment: .trailing) {
            mapControls
        }
        .overlay(alignment: .bottom) {
            if layout != .mapOnly {
                newPlaceDraftPanel
            }
        }
        .accessibilityLabel("Place check-in map")
    }

    private func placeAnnotationButton(_ place: RoutinePlace) -> some View {
        Button {
            selectPlace(place)
        } label: {
            ZStack {
                Circle()
                    .fill(isSelected(place) ? Color.accentColor : Color.white.opacity(0.94))
                    .frame(width: isSelected(place) ? 18 : 14, height: isSelected(place) ? 18 : 14)
                Circle()
                    .stroke(isSelected(place) ? Color.white : Color.accentColor, lineWidth: 2)
                    .frame(width: isSelected(place) ? 18 : 14, height: isSelected(place) ? 18 : 14)
            }
            .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select \(place.displayName)")
    }

    private var currentLocationAnnotation: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.18))
                .frame(width: 26, height: 26)
            Circle()
                .fill(Color.blue)
                .frame(width: 10, height: 10)
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 10, height: 10)
        }
        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }

    private func historyMarkerButton(_ marker: PlaceCheckInHistoryMapMarker) -> some View {
        Button {
            newPlaceDraft = nil
            selectedHistoryMarkerID = marker.id
            selectedPlaceID = marker.placeID
            focus(on: marker.coordinate)
        } label: {
            historyMarkerView(marker)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(marker.accessibilityLabel)
    }

    @ViewBuilder
    private var newPlaceDraftPanel: some View {
        if let draft = newPlaceDraft {
            mapLocationActionPanel(
                title: mapLocationPanelTitle(for: draft),
                coordinateText: draft.coordinate.formattedForPlaceSelection,
                draft: draft,
                selectedPlace: nil,
                showsLocationSettingsButton: false
            )
            .padding(12)
        }
    }

    @ViewBuilder
    private var mapLocationActionPanel: some View {
        if let draft = newPlaceDraft {
            mapLocationActionPanel(
                title: mapLocationPanelTitle(for: draft),
                coordinateText: draft.coordinate.formattedForPlaceSelection,
                draft: draft,
                selectedPlace: nil,
                showsLocationSettingsButton: false
            )
        } else {
            mapLocationActionPanel(
                title: mapTitle,
                coordinateText: selectedPlaceCoordinateText ?? locationStatusText,
                draft: nil,
                selectedPlace: selectedPlace,
                showsLocationSettingsButton: selectedPlace == nil && showsLocationSettingsButton
            )
        }
    }

    private func mapLocationPanelTitle(for draft: PlaceCheckInNewPlaceDraft) -> String {
        draft.isCurrentLocationDraft ? "Current location" : "Pinned Location"
    }

    private func mapLocationActionPanel(
        title: String,
        coordinateText: String,
        draft: PlaceCheckInNewPlaceDraft?,
        selectedPlace: RoutinePlace?,
        showsLocationSettingsButton: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: draft == nil ? "location" : "mappin.and.ellipse")
                .font(.headline.weight(.semibold))

            if draft != nil {
                TextField("Place name", text: newPlaceNameBinding)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Radius")
                        Spacer()
                        Text("\(Int(draft?.radiusMeters ?? PlaceCheckInNewPlaceDraft.defaultRadiusMeters)) m")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption.weight(.semibold))

                    Slider(value: newPlaceRadiusBinding, in: 25...2_000, step: 25)
                }
            }

            Text(coordinateText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if showsLocationSettingsButton {
                Button {
                    openLocationSettings()
                } label: {
                    Label("Open Location Settings", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if let locationActionErrorText {
                Text(locationActionErrorText)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsAddPlaceButton(for: draft, selectedPlace: selectedPlace)
                || showsCheckInButton(for: draft, selectedPlace: selectedPlace) {
                HStack(spacing: 10) {
                    if showsAddPlaceButton(for: draft, selectedPlace: selectedPlace) {
                        Button {
                            if draft != nil {
                                saveNewPlaceDraft()
                            } else {
                                beginNewPlaceDraftFromCurrentLocation()
                            }
                        } label: {
                            Label("Add Place", systemImage: "mappin.and.ellipse")
                                .lineLimit(1)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isAddPlaceButtonDisabled(for: draft))
                    }

                    if showsCheckInButton(for: draft, selectedPlace: selectedPlace) {
                        Button {
                            if let draft {
                                checkInAtPinnedLocation(draft)
                            } else if let selectedPlace {
                                checkIn(at: selectedPlace)
                            } else {
                                checkInAtCurrentLocation()
                            }
                        } label: {
                            Label(checkInButtonTitle(for: draft, selectedPlace: selectedPlace), systemImage: "location.fill")
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(draft == nil && (currentLocation == nil || isLoadingLocation))
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: 360, alignment: .leading)
        .routinaGlassPanel(cornerRadius: 12, tint: .teal, tintOpacity: 0.08, interactive: true)
    }

    private var locationActionErrorText: String? {
        if let draftMessage = newPlaceDraft?.statusMessage, !draftMessage.isEmpty {
            return draftMessage
        }
        return errorText
    }

    private func isAddPlaceButtonDisabled(for draft: PlaceCheckInNewPlaceDraft?) -> Bool {
        if draft != nil {
            return !canSaveNewPlaceDraft
        }
        return currentLocation == nil || isLoadingLocation
    }

    private func showsAddPlaceButton(
        for draft: PlaceCheckInNewPlaceDraft?,
        selectedPlace: RoutinePlace?
    ) -> Bool {
        if selectedPlace != nil {
            return false
        }
        return !isKnownPlaceLocation(for: draft)
    }

    private func showsCheckInButton(
        for draft: PlaceCheckInNewPlaceDraft?,
        selectedPlace: RoutinePlace?
    ) -> Bool {
        if let selectedPlace {
            return !isCurrentMatchedPlace(selectedPlace)
        }
        if let draft {
            guard let containingPlace = PlaceCheckInSupport.nearestContainingPlace(to: draft.coordinate, places: places) else {
                return true
            }
            return !isCurrentMatchedPlace(containingPlace)
        }
        return !isKnownPlaceLocation(for: draft)
    }

    private func checkInButtonTitle(
        for draft: PlaceCheckInNewPlaceDraft?,
        selectedPlace: RoutinePlace?
    ) -> String {
        if let selectedPlace {
            return "Check In at \(selectedPlace.displayName)"
        }
        if let draft,
           let place = PlaceCheckInSupport.nearestContainingPlace(to: draft.coordinate, places: places) {
            return "Check In at \(place.displayName)"
        }
        return "Check In Here"
    }

    private func isCurrentMatchedPlace(_ place: RoutinePlace) -> Bool {
        currentMatchedPlace?.id == place.id
    }

    private var selectedPlaceCoordinateText: String? {
        guard let selectedPlace else { return nil }
        let coordinate = LocationCoordinate(
            latitude: selectedPlace.latitude,
            longitude: selectedPlace.longitude
        )
        return "\(coordinate.formattedForPlaceSelection) · \(Int(selectedPlace.radiusMeters.rounded())) m radius"
    }

    private func isKnownPlaceLocation(for draft: PlaceCheckInNewPlaceDraft?) -> Bool {
        if let draft {
            return PlaceCheckInSupport.nearestContainingPlace(to: draft.coordinate, places: places) != nil
        }
        return currentMatchedPlace != nil
    }

    private var mapControls: some View {
        VStack(spacing: 4) {
            mapControlButton(systemImage: "plus", accessibilityLabel: "Zoom in") {
                zoomMap(by: 0.5)
            }

            mapControlSeparator

            mapControlButton(systemImage: "minus", accessibilityLabel: "Zoom out") {
                zoomMap(by: 2)
            }

            mapControlSeparator

            mapControlButton(systemImage: "location", accessibilityLabel: "Show current location") {
                showCurrentLocation(refreshFirst: false)
            }
        }
        .frame(width: 40)
        .padding(.vertical, 6)
        .routinaGlassCard(cornerRadius: 8, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
        .fixedSize()
        .padding(10)
    }

    private func mapControlButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: 32, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func historyMarkerView(_ marker: PlaceCheckInHistoryMapMarker) -> some View {
        let isSelected = selectedHistoryMarkerID == marker.id
        let markerColor = marker.containsActiveSession ? Color.teal : Color.orange

        return ZStack(alignment: .topTrailing) {
            Image(systemName: marker.containsActiveSession ? "location.fill" : "clock.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: isSelected ? 28 : 24, height: isSelected ? 28 : 24)
                .background(markerColor, in: Circle())
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: isSelected ? 3 : 2)
                )
                .shadow(color: .black.opacity(0.18), radius: 5, y: 2)

            if marker.count > 1 {
                Text(historyMarkerCountText(marker.count))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 4)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(Color.red, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.white, lineWidth: 1)
                    )
                    .offset(x: 8, y: -8)
            }
        }
    }

    private func historyMarkerCountText(_ count: Int) -> String {
        count > 99 ? "99+" : "\(count)"
    }

    private var mapControlSeparator: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.18))
            .frame(width: 24, height: 1)
    }

    private var currentLocationPanel: some View {
        PlaceCheckInCurrentLocationPanel(
            buttonTitle: currentLocationButtonTitle,
            statusText: locationStatusText,
            showsLocationSettingsButton: showsLocationSettingsButton,
            isCheckInDisabled: currentLocation == nil || isLoadingLocation,
            onCheckInAtCurrentLocation: { checkInAtCurrentLocation() },
            onOpenLocationSettings: { openLocationSettings() }
        )
    }

    private var placesList: some View {
        PlaceCheckInPlacesList(
            places: orderedPlaces,
            activeSessionPlaceID: activeSession?.placeID,
            selectedPlaceID: selectedPlaceID,
            currentLocation: currentLocation,
            onSelectPlace: { selectPlace($0) },
            onCheckInAtPlace: { checkIn(at: $0) },
            onEditPlace: { beginEditing($0) },
            onDeletePlace: { confirmDelete($0) }
        )
    }

    private var dayTimeline: some View {
        PlaceCheckInDayTimelineList(
            sections: daySections,
            calendar: calendar,
            canFocusOnSession: { canFocusOnSession($0) },
            canSaveSessionAsPlace: { canSaveSessionAsPlace($0) },
            onFocusSession: { focusOnSession($0) },
            onEditSession: { beginEditing($0) },
            onDeleteSession: { confirmDelete($0) },
            onSaveSessionAsPlace: { beginNewPlaceDraft(from: $0) },
            onConfirmAutomaticSession: { confirmAutomaticSession($0) }
        )
    }

    private var mapTitle: String {
        if newPlaceDraft != nil {
            return "New place"
        }
        if let selectedHistoryMarker {
            return selectedHistoryMarker.title
        }
        if let selectedPlace {
            return selectedPlace.displayName
        }
        if currentLocation != nil {
            return "Current location"
        }
        return "Saved places"
    }

    private var currentLocationButtonTitle: String {
        if let currentMatchedPlace {
            return "Check In at \(currentMatchedPlace.displayName)"
        }
        return "Check In Here"
    }

    private var locationStatusText: String {
        if isLoadingLocation {
            return "Finding current location..."
        }

        switch locationSnapshot.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if let currentLocation {
                let accuracyText = locationSnapshot.horizontalAccuracy.map { "accuracy \(Int($0.rounded())) m" }
                return [currentLocation.formattedForPlaceSelection, accuracyText].compactMap(\.self).joined(separator: " · ")
            }
            return "Location access is on, but the current position is not available yet."
        case .notDetermined:
            return "Location permission has not been decided yet."
        case .disabled:
            return "Location services are disabled on this device."
        case .restricted, .denied:
            return "Location access is off. Saved places can still be checked in manually."
        }
    }

    private var showsLocationSettingsButton: Bool {
        guard urlOpenerClient.locationSettingsURL() != nil else {
            return false
        }

        switch locationSnapshot.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return false
        case .disabled, .notDetermined, .restricted, .denied:
            return true
        }
    }

    private func placeMapTint(for place: RoutinePlace) -> Color {
        if currentMatchedPlace?.id == place.id {
            return .blue
        }
        return .accentColor
    }

    private func isSelected(_ place: RoutinePlace) -> Bool {
        selectedPlaceID == place.id
    }

    private func selectPlace(_ place: RoutinePlace) {
        newPlaceDraft = nil
        selectedHistoryMarkerID = nil
        selectedPlaceID = place.id
        syncMapPosition()
    }

    @MainActor
    private func refreshLocation(requestAuthorizationIfNeeded: Bool) async {
        isLoadingLocation = true
        defer { isLoadingLocation = false }

        let snapshot = await locationClient.snapshot(requestAuthorizationIfNeeded)
        locationSnapshot = snapshot
        prepareCurrentLocationDraftIfNeeded(for: snapshot)
        if newPlaceDraft == nil,
           selectedPlaceID == nil,
           selectedHistoryMarkerID == nil,
           let coordinate = snapshot.coordinate,
           let nearbyPlace = PlaceCheckInSupport.nearestContainingPlace(to: coordinate, places: places) {
            selectedPlaceID = nearbyPlace.id
        }
        reconcileAutomaticCheckIn(for: snapshot)
        syncMapPositionIfAllowed()
    }

    private func prepareCurrentLocationDraftIfNeeded(for snapshot: LocationSnapshot) {
        guard layout == .mapOnly,
              newPlaceDraft == nil,
              selectedPlaceID == nil,
              selectedHistoryMarkerID == nil,
              let coordinate = snapshot.coordinate,
              PlaceCheckInSupport.nearestContainingPlace(to: coordinate, places: places) == nil
        else {
            return
        }

        var draft = PlaceCheckInNewPlaceDraft(coordinate: coordinate)
        draft.isCurrentLocationDraft = true
        newPlaceDraft = draft
    }

    @MainActor
    private func reconcileAutomaticCheckIn(for snapshot: LocationSnapshot) {
        guard isAutomaticPlaceCheckInEnabled else {
            do {
                _ = try PlaceCheckInSupport.endActiveAutomaticSession(in: modelContext)
            } catch {
                errorText = "Could not end automatic check-in."
                NSLog("Failed to end automatic place check-in: \(error.localizedDescription)")
            }
            return
        }

        guard snapshot.canDeterminePresence, let coordinate = snapshot.coordinate else {
            return
        }

        do {
            _ = try PlaceCheckInSupport.reconcileAutomaticCheckIn(
                coordinate: coordinate,
                horizontalAccuracyMeters: snapshot.horizontalAccuracy,
                activity: nil,
                in: modelContext
            )
        } catch {
            errorText = "Could not update automatic check-in."
            NSLog("Failed to reconcile automatic place check-in: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func openLocationSettings() {
        guard let url = urlOpenerClient.locationSettingsURL() else {
            return
        }

        urlOpenerClient.open(url)
    }

    private func zoomMap(by scale: Double) {
        let region = MKCoordinateRegion(
            center: visibleRegion.center,
            span: MKCoordinateSpan(
                latitudeDelta: min(max(visibleRegion.span.latitudeDelta * scale, 0.001), 160),
                longitudeDelta: min(max(visibleRegion.span.longitudeDelta * scale, 0.001), 160)
            )
        )
        visibleRegion = region
        withAnimation(.easeInOut(duration: 0.2)) {
            mapPosition = PlaceCheckInMapCamera.position(region: region)
        }
    }

    private func focusOnCurrentLocation() {
        guard let currentLocation else { return }
        if layout == .mapOnly, currentMatchedPlace == nil {
            beginNewPlaceDraftFromCurrentLocation()
            return
        }

        newPlaceDraft = nil
        selectedHistoryMarkerID = nil
        selectedPlaceID = currentMatchedPlace?.id
        focus(on: currentLocation)
    }

    private func showCurrentLocation(refreshFirst: Bool) {
        Task { @MainActor in
            if refreshFirst || currentLocation == nil {
                await refreshLocation(requestAuthorizationIfNeeded: true)
            }

            guard currentLocation != nil else {
                errorText = "Current location is unavailable."
                return
            }

            errorText = nil
            focusOnCurrentLocation()
        }
    }

    private func focusOnSession(_ session: PlaceCheckInSession) {
        newPlaceDraft = nil
        if let coordinate = session.coordinate {
            selectedHistoryMarkerID = PlaceCheckInSupport.historyMapMarkerID(for: coordinate)
            selectedPlaceID = session.placeID
            focus(on: coordinate)
            return
        }

        if let place = place(for: session) {
            selectPlace(place)
        }
    }

    private func canFocusOnSession(_ session: PlaceCheckInSession) -> Bool {
        session.coordinate != nil || place(for: session) != nil
    }

    private func canSaveSessionAsPlace(_ session: PlaceCheckInSession) -> Bool {
        session.placeID == nil && session.coordinate != nil
    }

    private func place(for session: PlaceCheckInSession) -> RoutinePlace? {
        guard let placeID = session.placeID else { return nil }
        return places.first { $0.id == placeID }
    }

    private func focus(on coordinate: LocationCoordinate) {
        let region = MKCoordinateRegion(
            center: coordinate.mapCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        visibleRegion = region
        withAnimation(.easeInOut(duration: 0.25)) {
            mapPosition = PlaceCheckInMapCamera.position(region: region)
        }
    }

    private func beginNewPlaceDraft(at coordinate: LocationCoordinate) {
        guard !isMapTapOnExistingMapFeature(at: coordinate) else {
            return
        }

        if var draft = newPlaceDraft {
            draft.coordinate = coordinate
            draft.statusMessage = ""
            newPlaceDraft = draft
        } else {
            newPlaceDraft = PlaceCheckInNewPlaceDraft(coordinate: coordinate)
        }
        selectedHistoryMarkerID = nil
        selectedPlaceID = nil
        errorText = nil
    }

    private func beginNewPlaceDraft(from session: PlaceCheckInSession) {
        guard let coordinate = session.coordinate else {
            errorText = "This check-in does not have a saved location."
            return
        }

        var draft = PlaceCheckInNewPlaceDraft(coordinate: coordinate)
        draft.name = suggestedNewPlaceName(for: session)
        draft.sourceSessionID = session.id
        newPlaceDraft = draft
        selectedHistoryMarkerID = PlaceCheckInSupport.historyMapMarkerID(for: coordinate)
        selectedPlaceID = nil
        selectedMode = .checkIns
        errorText = nil
        focus(on: coordinate)
    }

    private func suggestedNewPlaceName(for session: PlaceCheckInSession) -> String {
        if PlaceCheckInSupport.isGeneratedRawCurrentLocationName(session.placeName) {
            return ""
        }
        return session.displayPlaceName
    }

    private func cancelNewPlaceDraft() {
        newPlaceDraft = nil
        errorText = nil
    }

    private func beginNewPlaceDraftFromCurrentLocation() {
        guard let currentLocation else {
            errorText = "Current location is unavailable."
            return
        }

        var draft = PlaceCheckInNewPlaceDraft(coordinate: currentLocation)
        draft.isCurrentLocationDraft = true
        newPlaceDraft = draft
        selectedHistoryMarkerID = nil
        selectedPlaceID = nil
        errorText = nil
        focus(on: currentLocation)
    }

    private func isMapTapOnExistingMapFeature(at coordinate: LocationCoordinate) -> Bool {
        if places.contains(where: { $0.distance(to: coordinate) <= 18 }) {
            return true
        }
        if historyMapMarkers.contains(where: { $0.coordinate.distance(to: coordinate) <= 75 }) {
            return true
        }
        if let currentLocation, currentLocation.distance(to: coordinate) <= 75 {
            return true
        }
        return false
    }

    @MainActor
    private func saveNewPlaceDraft() {
        guard var draft = newPlaceDraft else {
            return
        }
        guard let cleanedName = RoutinePlace.cleanedName(draft.name) else {
            draft.statusMessage = "Enter a place name."
            newPlaceDraft = draft
            return
        }

        do {
            if try SettingsDataQueries.hasDuplicatePlaceName(cleanedName, in: modelContext) {
                draft.statusMessage = SettingsPlacePersistenceError.duplicateName.localizedDescription
                newPlaceDraft = draft
                return
            }

            let placeID = UUID()
            let place = RoutinePlace(
                id: placeID,
                name: cleanedName,
                latitude: draft.coordinate.latitude,
                longitude: draft.coordinate.longitude,
                radiusMeters: draft.radiusMeters
            )
            modelContext.insert(place)
            DeviceActivityRecorder.recordAction(
                .created,
                entity: .place,
                entityID: place.id,
                entityTitle: place.displayName,
                in: modelContext
            )
            try modelContext.save()

            if let sourceSessionID = draft.sourceSessionID {
                _ = try PlaceCheckInSupport.linkSessionToPlace(
                    sessionID: sourceSessionID,
                    place: place,
                    in: modelContext
                )
            }

            newPlaceDraft = nil
            selectedHistoryMarkerID = nil
            selectedPlaceID = placeID
            selectedMode = .places
            errorText = nil
            focus(on: draft.coordinate)
        } catch {
            draft.statusMessage = "Could not save place."
            newPlaceDraft = draft
            NSLog("Failed to save place from map: \(error.localizedDescription)")
        }
    }

    private func beginEditing(_ session: PlaceCheckInSession) {
        editingSessionDraft = PlaceCheckInSessionEditDraft(session: session)
    }

    private func beginEditing(_ place: RoutinePlace) {
        editingPlaceDraft = PlaceCheckInPlaceEditDraft(place: place)
    }

    private func confirmDelete(_ session: PlaceCheckInSession) {
        deletionCandidate = PlaceCheckInSessionDeletionCandidate(
            id: session.id,
            title: session.displayPlaceName
        )
    }

    private func confirmDelete(_ place: RoutinePlace) {
        placeDeletionCandidate = PlaceCheckInPlaceDeletionCandidate(
            id: place.id,
            title: place.displayName
        )
    }

    @MainActor
    private func confirmAutomaticSession(_ session: PlaceCheckInSession) {
        do {
            _ = try PlaceCheckInSupport.confirmAutomaticSession(id: session.id, in: modelContext)
            errorText = nil
            signalSuccess()
        } catch {
            errorText = "Could not confirm check-in."
            NSLog("Failed to confirm automatic place check-in: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func saveEditedSession(_ draft: PlaceCheckInSessionEditDraft) throws {
        _ = try PlaceCheckInSupport.updateSession(
            id: draft.id,
            placeName: draft.placeName,
            activity: draft.activity,
            note: draft.note,
            imageData: draft.imageData,
            startedAt: draft.startedAt,
            endedAt: draft.hasEndTime ? draft.endedAt : nil,
            in: modelContext
        )
        editingSessionDraft = nil
        errorText = nil
    }

    @MainActor
    private func saveEditedPlace(_ draft: PlaceCheckInPlaceEditDraft) throws {
        guard let cleanedName = RoutinePlace.cleanedName(draft.name) else {
            throw SettingsPlacePersistenceError.invalidName
        }

        _ = try SettingsPlacePersistence.update(
            SettingsPlaceUpdateRequest(
                placeID: draft.id,
                cleanedName: cleanedName,
                coordinate: draft.coordinate,
                radiusMeters: draft.radiusMeters
            ),
            in: modelContext
        )
        NotificationCenter.default.postRoutineDidUpdate()
        editingPlaceDraft = nil
        selectedHistoryMarkerID = nil
        selectedPlaceID = draft.id
        errorText = nil
        focus(on: draft.coordinate)
    }

    @MainActor
    private func deleteSession(id: UUID) {
        do {
            let deleted = try PlaceCheckInSupport.deleteSession(id: id, in: modelContext)
            if deleted {
                errorText = nil
            } else {
                errorText = PlaceCheckInSessionEditError.missingSession.localizedDescription
            }
        } catch {
            errorText = "Could not delete check-in."
            NSLog("Failed to delete place check-in: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func deletePlace(id: UUID) {
        do {
            _ = try SettingsPlacePersistence.delete(
                SettingsPlaceDeletionRequest(placeID: id),
                in: modelContext
            )
            NotificationCenter.default.postRoutineDidUpdate()
            if selectedPlaceID == id {
                selectedPlaceID = nil
            }
            if editingPlaceDraft?.id == id {
                editingPlaceDraft = nil
            }
            placeDeletionCandidate = nil
            errorText = nil
            syncMapPositionIfAllowed()
            signalSuccess()
        } catch {
            errorText = "Could not delete place."
            NSLog("Failed to delete place from map: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func checkInAtCurrentLocation() {
        guard let currentLocation else {
            errorText = "Current location is unavailable."
            return
        }

        do {
            let session = try PlaceCheckInSupport.checkInAtCurrentLocation(
                coordinate: currentLocation,
                horizontalAccuracyMeters: locationSnapshot.horizontalAccuracy,
                activity: nil,
                in: modelContext
            )
            errorText = nil
            if canSaveSessionAsPlace(session) {
                signalSuccess()
                beginNewPlaceDraft(from: session)
                return
            }
            finishSuccessfulCheckIn()
        } catch {
            errorText = "Could not check in at current location."
            NSLog("Failed to check in at current location: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func checkIn(at place: RoutinePlace) {
        do {
            _ = try PlaceCheckInSupport.checkIn(
                at: place,
                activity: nil,
                in: modelContext
            )
            errorText = nil
            finishSuccessfulCheckIn()
        } catch {
            errorText = "Could not check in at \(place.displayName)."
            NSLog("Failed to check in at place from map: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func checkInAtPinnedLocation(_ draft: PlaceCheckInNewPlaceDraft) {
        do {
            let session = try PlaceCheckInSupport.checkInAtCurrentLocation(
                coordinate: draft.coordinate,
                horizontalAccuracyMeters: nil,
                rawPlaceName: draft.name,
                activity: nil,
                in: modelContext
            )
            newPlaceDraft = nil
            selectedPlaceID = session.placeID
            if let coordinate = session.coordinate {
                selectedHistoryMarkerID = PlaceCheckInSupport.historyMapMarkerID(for: coordinate)
                focus(on: coordinate)
            } else {
                selectedHistoryMarkerID = nil
            }
            selectedMode = .checkIns
            errorText = nil
            finishSuccessfulCheckIn()
        } catch {
            var updatedDraft = draft
            updatedDraft.statusMessage = "Could not check in here."
            newPlaceDraft = updatedDraft
            NSLog("Failed to check in at pinned map location: \(error.localizedDescription)")
        }
    }

    private func syncMapPosition() {
        let region: MKCoordinateRegion
        if let selectedHistoryMarker {
            region = PlaceCheckInMapCamera.region(focusingOn: selectedHistoryMarker.coordinate)
        } else if let newPlaceDraft, shouldFocusNewPlaceDraft(newPlaceDraft) {
            region = PlaceCheckInMapCamera.region(focusingOn: newPlaceDraft.coordinate)
        } else {
            region = PlaceCheckInMapCamera.region(
                places: places,
                currentLocation: currentLocation,
                selectedPlaceID: selectedPlaceID,
                historyCoordinates: historyMapMarkers.map(\.coordinate)
            )
        }
        visibleRegion = region
        mapPosition = PlaceCheckInMapCamera.position(region: region)
    }

    private func syncMapPositionIfAllowed() {
        guard newPlaceDraft == nil || newPlaceDraft?.isCurrentLocationDraft == true else {
            return
        }

        syncMapPosition()
    }

    private func clearCurrentLocationDraftForExplicitSelection() {
        guard selectedPlaceID != nil || selectedHistoryMarkerID != nil else {
            return
        }

        if newPlaceDraft?.isCurrentLocationDraft == true {
            newPlaceDraft = nil
        }
    }

    private func shouldFocusNewPlaceDraft(_ draft: PlaceCheckInNewPlaceDraft) -> Bool {
        !draft.isCurrentLocationDraft || (selectedPlaceID == nil && selectedHistoryMarkerID == nil)
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func finishSuccessfulCheckIn() {
        signalSuccess()

        guard shouldDismissAfterCheckIn else {
            return
        }

        close()
    }

    private var shouldDismissAfterCheckIn: Bool {
        showsNavigationChrome || onClose != nil
    }

    private func signalSuccess() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
