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
    let selectedActivity: PlaceCheckInActivity?
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
    @State private var newPlaceDraft: PlaceCheckInNewPlaceDraft?

    init(
        selectedActivity: PlaceCheckInActivity?,
        showsNavigationChrome: Bool = true,
        showsInlineHeader: Bool = true,
        layout: PlaceCheckInMapSheetLayout = .stack,
        onClose: (() -> Void)? = nil,
        selectedPlaceID: Binding<UUID?>? = nil,
        selectedHistoryMarkerID: Binding<PlaceCheckInHistoryMapMarker.ID?>? = nil
    ) {
        self.selectedActivity = selectedActivity
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
        sessions.first { $0.endedAt == nil }
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
            syncMapPosition()
        }
        .onChange(of: historyMapMarkers.map(\.id)) { _, markerIDs in
            if let selectedHistoryMarkerID, !markerIDs.contains(selectedHistoryMarkerID) {
                self.selectedHistoryMarkerID = nil
            }
            syncMapPosition()
        }
        .onChange(of: selectedPlaceID) { _, _ in
            syncMapPosition()
        }
        .onChange(of: selectedHistoryMarkerID) { _, _ in
            syncMapPosition()
        }
        .sheet(item: $editingSessionDraft) { draft in
            PlaceCheckInSessionEditor(draft: draft) { updatedDraft in
                try saveEditedSession(updatedDraft)
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
                currentLocationPanel

                Divider()

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
            Text(mapTitle)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .routinaGlassPill()
                .padding(10)
        }
        .overlay(alignment: .trailing) {
            mapControls
        }
        .overlay(alignment: .bottom) {
            newPlaceDraftPanel
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
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Label("New Place", systemImage: "mappin.and.ellipse")
                        .font(.headline.weight(.semibold))

                    Spacer(minLength: 8)

                    Button {
                        cancelNewPlaceDraft()
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel new place")
                }

                TextField("Place name", text: newPlaceNameBinding)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Radius")
                        Spacer()
                        Text("\(Int(draft.radiusMeters)) m")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption.weight(.semibold))

                    Slider(value: newPlaceRadiusBinding, in: 25...2_000, step: 25)
                }

                if !draft.statusMessage.isEmpty {
                    Text(draft.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Text(draft.coordinate.formattedForPlaceSelection)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Button("Cancel") {
                        cancelNewPlaceDraft()
                    }

                    Button("Save") {
                        saveNewPlaceDraft()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSaveNewPlaceDraft)
                }
            }
            .padding(12)
            .frame(maxWidth: 360)
            .routinaGlassPanel(cornerRadius: 12, tint: .accentColor, tintOpacity: 0.08, interactive: true)
            .padding(12)
        }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    checkInAtCurrentLocation()
                } label: {
                    Label(currentLocationButtonTitle, systemImage: "location.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(currentLocation == nil || isLoadingLocation)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(locationStatusText)
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
            }
        }
    }

    private var placesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if orderedPlaces.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No saved places yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Current-location check-ins still work, and named places can be added in Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .routinaGlassCard(cornerRadius: 8, tint: .secondary, tintOpacity: 0.08)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(orderedPlaces) { place in
                            placeRow(place)
                        }
                    }
                }
            }
        }
    }

    private var dayTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            if daySections.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No check-ins")
                        .font(.subheadline.weight(.semibold))
                    Text("Your place sessions will appear here grouped by date.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .routinaGlassCard(cornerRadius: 8, tint: .secondary, tintOpacity: 0.08)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(daySections) { section in
                            dayTimelineSection(section)
                        }
                    }
                }
            }
        }
    }

    private func dayTimelineSection(_ section: PlaceCheckInDaySection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(TimelineLogic.daySectionTitle(for: section.date, calendar: calendar))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)

            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(section.sessions) { session in
                    dayTimelineRow(session)
                }
            }
        }
    }

    private func placeRow(_ place: RoutinePlace) -> some View {
        HStack(spacing: 10) {
            Button {
                selectPlace(place)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: activeSession?.placeID == place.id ? "location.fill" : "mappin")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected(place) ? Color.accentColor : Color.secondary)
                        .frame(width: 28, height: 28)
                        .routinaGlassPill(
                            tint: isSelected(place) ? .accentColor : .secondary,
                            tintOpacity: isSelected(place) ? 0.16 : 0.10
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(placeSubtitle(place))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .buttonStyle(.plain)
            .accessibilityLabel("Show \(place.displayName) on map")

            Button {
                checkIn(at: place)
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Check in at \(place.displayName)")
            .help("Check in at \(place.displayName)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassCard(
            cornerRadius: 8,
            tint: isSelected(place) ? .accentColor : .secondary,
            tintOpacity: isSelected(place) ? 0.12 : 0.07,
            interactive: true
        )
    }

    private func dayTimelineRow(_ session: PlaceCheckInSession) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                focusOnSession(session)
            } label: {
                let canFocus = canFocusOnSession(session)

                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(session.isActive ? Color.teal : Color.accentColor)
                            .frame(width: 10, height: 10)
                        Rectangle()
                            .fill(Color.secondary.opacity(0.22))
                            .frame(width: 2, height: 34)
                    }
                    .frame(width: 18)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(session.displayPlaceName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            if session.isActive {
                                Text("Now")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.teal)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .routinaGlassPill(tint: .teal, tintOpacity: 0.12)
                            }

                            if session.isAutomatic {
                                let autoTint = session.requiresConfirmation ? Color.orange : Color.secondary
                                Text("Auto")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(autoTint)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .routinaGlassPill(
                                        tint: autoTint,
                                        tintOpacity: session.requiresConfirmation ? 0.14 : 0.10
                                    )
                            }
                        }

                        Text(sessionTimelineSubtitle(session))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if let activity = session.activity {
                            Label(activity.title, systemImage: activity.systemImage)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    Image(systemName: canFocus ? "scope" : "mappin.slash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .buttonStyle(.plain)
            .disabled(!canFocusOnSession(session))

            sessionActionsMenu(session)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassCard(cornerRadius: 8, tint: .secondary, tintOpacity: 0.07, interactive: true)
        .contextMenu {
            if session.requiresConfirmation {
                Button {
                    confirmAutomaticSession(session)
                } label: {
                    Label("Confirm Auto Check-In", systemImage: "checkmark.circle")
                }

                Divider()
            }

            Button {
                beginEditing(session)
            } label: {
                Label("Edit Check-In", systemImage: "pencil")
            }

            Button(role: .destructive) {
                confirmDelete(session)
            } label: {
                Label("Delete Check-In", systemImage: "trash")
            }
        }
        .modifier(
            PlaceCheckInConfirmSwipeModifier(
                showsConfirm: session.requiresConfirmation,
                action: { confirmAutomaticSession(session) }
            )
        )
        .accessibilityLabel("Show \(session.displayPlaceName) on map")
    }

    private func sessionActionsMenu(_ session: PlaceCheckInSession) -> some View {
        Menu {
            if session.requiresConfirmation {
                Button {
                    confirmAutomaticSession(session)
                } label: {
                    Label("Confirm Auto Check-In", systemImage: "checkmark.circle")
                }

                Divider()
            }

            Button {
                beginEditing(session)
            } label: {
                Label("Edit Check-In", systemImage: "pencil")
            }

            Button(role: .destructive) {
                confirmDelete(session)
            } label: {
                Label("Delete Check-In", systemImage: "trash")
            }
        } label: {
            Label("Check-in actions", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Check-in actions")
        .help("More actions")
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

    private func placeSubtitle(_ place: RoutinePlace) -> String {
        let radius = "\(Int(place.radiusMeters.rounded())) m radius"
        guard let currentLocation else { return radius }

        if place.contains(currentLocation) {
            return "Here · \(radius)"
        }

        let distance = place.distance(to: currentLocation)
        let distanceText: String
        if distance < 1_000 {
            distanceText = "\(Int(distance.rounded())) m away"
        } else {
            distanceText = String(format: "%.1f km away", distance / 1_000)
        }
        return "\(distanceText) · \(radius)"
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

    private func sessionTimelineSubtitle(_ session: PlaceCheckInSession) -> String {
        guard let start = session.startedAt ?? session.createdAt else {
            return "Time unavailable"
        }

        let referenceDate = Date()
        let rawFinish = session.endedAt ?? referenceDate
        let normalizedFinish = rawFinish > start ? rawFinish : start
        let startText = start.formatted(.dateTime.hour().minute())
        let finishText: String
        if session.endedAt == nil {
            finishText = "Now"
        } else {
            finishText = normalizedFinish.formatted(.dateTime.hour().minute())
        }

        let range = "\(startText)-\(finishText)"
        let duration = PlaceCheckInFormatting.durationText(
            seconds: session.durationSeconds(referenceDate: referenceDate)
        )
        return "\(range) · \(duration)"
    }

    @MainActor
    private func refreshLocation(requestAuthorizationIfNeeded: Bool) async {
        isLoadingLocation = true
        defer { isLoadingLocation = false }

        let snapshot = await locationClient.snapshot(requestAuthorizationIfNeeded)
        locationSnapshot = snapshot
        if selectedPlaceID == nil,
           selectedHistoryMarkerID == nil,
           let coordinate = snapshot.coordinate,
           let nearbyPlace = PlaceCheckInSupport.nearestContainingPlace(to: coordinate, places: places) {
            selectedPlaceID = nearbyPlace.id
        }
        reconcileAutomaticCheckIn(for: snapshot)
        syncMapPosition()
    }

    @MainActor
    private func reconcileAutomaticCheckIn(for snapshot: LocationSnapshot) {
        guard snapshot.canDeterminePresence, let coordinate = snapshot.coordinate else {
            return
        }

        do {
            _ = try PlaceCheckInSupport.reconcileAutomaticCheckIn(
                coordinate: coordinate,
                horizontalAccuracyMeters: snapshot.horizontalAccuracy,
                activity: selectedActivity,
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

    private func cancelNewPlaceDraft() {
        newPlaceDraft = nil
    }

    private func isMapTapOnExistingMapFeature(at coordinate: LocationCoordinate) -> Bool {
        if places.contains(where: { $0.distance(to: coordinate) <= 75 }) {
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

    private func confirmDelete(_ session: PlaceCheckInSession) {
        deletionCandidate = PlaceCheckInSessionDeletionCandidate(
            id: session.id,
            title: session.displayPlaceName
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
            startedAt: draft.startedAt,
            endedAt: draft.hasEndTime ? draft.endedAt : nil,
            in: modelContext
        )
        editingSessionDraft = nil
        errorText = nil
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
    private func checkInAtCurrentLocation() {
        guard let currentLocation else {
            errorText = "Current location is unavailable."
            return
        }

        do {
            _ = try PlaceCheckInSupport.checkInAtCurrentLocation(
                coordinate: currentLocation,
                horizontalAccuracyMeters: locationSnapshot.horizontalAccuracy,
                activity: selectedActivity,
                in: modelContext
            )
            errorText = nil
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
                activity: selectedActivity,
                in: modelContext
            )
            errorText = nil
            finishSuccessfulCheckIn()
        } catch {
            errorText = "Could not check in at \(place.displayName)."
            NSLog("Failed to check in at place from map: \(error.localizedDescription)")
        }
    }

    private func syncMapPosition() {
        let region: MKCoordinateRegion
        if let selectedHistoryMarker {
            region = PlaceCheckInMapCamera.region(focusingOn: selectedHistoryMarker.coordinate)
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

private struct PlaceCheckInConfirmSwipeModifier: ViewModifier {
    let showsConfirm: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if showsConfirm {
                    Button {
                        action()
                    } label: {
                        Label("Confirm", systemImage: "checkmark.circle")
                    }
                    .tint(.green)
                }
            }
        #else
        content
        #endif
    }
}

private enum PlaceCheckInMapSheetMode: String, CaseIterable, Identifiable {
    case checkIns
    case places

    var id: Self { self }

    var title: String {
        switch self {
        case .checkIns:
            return "Check-ins"
        case .places:
            return "Places"
        }
    }

    var systemImage: String {
        switch self {
        case .checkIns:
            return "checklist"
        case .places:
            return "mappin"
        }
    }
}

private struct PlaceCheckInSessionEditDraft: Identifiable {
    let id: UUID
    let canRemainActive: Bool
    var placeName: String
    var startedAt: Date
    var endedAt: Date
    var hasEndTime: Bool
    var activity: PlaceCheckInActivity?
    var note: String

    init(session: PlaceCheckInSession) {
        let start = session.startedAt ?? session.createdAt ?? Date()
        self.id = session.id
        self.canRemainActive = session.endedAt == nil
        self.placeName = session.displayPlaceName
        self.startedAt = start
        self.endedAt = session.endedAt ?? Date()
        self.hasEndTime = session.endedAt != nil
        self.activity = session.activity
        self.note = session.note ?? ""
    }
}

private struct PlaceCheckInSessionDeletionCandidate: Identifiable {
    let id: UUID
    let title: String
}

private struct PlaceCheckInNewPlaceDraft: Identifiable, Equatable {
    static let defaultRadiusMeters = 150.0

    let id = UUID()
    var coordinate: LocationCoordinate
    var name = ""
    var radiusMeters = defaultRadiusMeters
    var statusMessage = ""
}

private struct PlaceCheckInSessionEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: PlaceCheckInSessionEditDraft
    @State private var errorText: String?

    let onSave: (PlaceCheckInSessionEditDraft) throws -> Void

    init(
        draft: PlaceCheckInSessionEditDraft,
        onSave: @escaping (PlaceCheckInSessionEditDraft) throws -> Void
    ) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Check-In") {
                    TextField("Place name", text: $draft.placeName)

                    Picker("Activity", selection: $draft.activity) {
                        Label("No Activity", systemImage: "tag.slash")
                            .tag(nil as PlaceCheckInActivity?)

                        ForEach(PlaceCheckInActivity.allCases) { activity in
                            Label(activity.title, systemImage: activity.systemImage)
                                .tag(Optional(activity))
                        }
                    }

                    TextField("Note", text: $draft.note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("Time") {
                    DatePicker(
                        "Start",
                        selection: $draft.startedAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    if draft.canRemainActive {
                        Toggle("End active check-in", isOn: $draft.hasEndTime)
                    }

                    if draft.hasEndTime {
                        DatePicker(
                            "End",
                            selection: $draft.endedAt,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Edit Check-In")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(validationMessage != nil)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 360)
        #endif
    }

    private var validationMessage: String? {
        if draft.placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return PlaceCheckInSessionEditError.invalidPlaceName.localizedDescription
        }
        if draft.hasEndTime, draft.endedAt < draft.startedAt {
            return PlaceCheckInSessionEditError.invalidDateRange.localizedDescription
        }
        return nil
    }

    private func save() {
        guard validationMessage == nil else { return }

        do {
            try onSave(draft)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

private enum PlaceCheckInMapCamera {
    static func position(region: MKCoordinateRegion) -> MapCameraPosition {
        .region(region)
    }

    static func region(focusingOn coordinate: LocationCoordinate) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate.mapCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    }

    static func region(
        places: [RoutinePlace],
        currentLocation: LocationCoordinate?,
        selectedPlaceID: UUID?,
        historyCoordinates: [LocationCoordinate]
    ) -> MKCoordinateRegion {
        if let selectedPlaceID,
           let selectedPlace = places.first(where: { $0.id == selectedPlaceID }) {
            return region(focusingOn: selectedPlace)
        }

        if !places.isEmpty || !historyCoordinates.isEmpty {
            return regionIncluding(
                places: places,
                currentLocation: currentLocation,
                historyCoordinates: historyCoordinates
            )
        }

        if let currentLocation {
            return MKCoordinateRegion(
                center: currentLocation.mapCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    }

    private static func region(focusingOn place: RoutinePlace) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: place.mapCoordinate,
            span: MKCoordinateSpan(
                latitudeDelta: max(latitudeDelta(forMeters: place.radiusMeters * 4), 0.01),
                longitudeDelta: max(longitudeDelta(forMeters: place.radiusMeters * 4, latitude: place.latitude), 0.01)
            )
        )
    }

    private static func regionIncluding(
        places: [RoutinePlace],
        currentLocation: LocationCoordinate?,
        historyCoordinates: [LocationCoordinate]
    ) -> MKCoordinateRegion {
        var minLatitude = Double.greatestFiniteMagnitude
        var maxLatitude = -Double.greatestFiniteMagnitude
        var minLongitude = Double.greatestFiniteMagnitude
        var maxLongitude = -Double.greatestFiniteMagnitude

        for place in places {
            let latitudeInset = latitudeDelta(forMeters: place.radiusMeters * 1.8)
            let longitudeInset = longitudeDelta(forMeters: place.radiusMeters * 1.8, latitude: place.latitude)
            minLatitude = min(minLatitude, place.latitude - latitudeInset)
            maxLatitude = max(maxLatitude, place.latitude + latitudeInset)
            minLongitude = min(minLongitude, place.longitude - longitudeInset)
            maxLongitude = max(maxLongitude, place.longitude + longitudeInset)
        }

        for coordinate in historyCoordinates {
            minLatitude = min(minLatitude, coordinate.latitude)
            maxLatitude = max(maxLatitude, coordinate.latitude)
            minLongitude = min(minLongitude, coordinate.longitude)
            maxLongitude = max(maxLongitude, coordinate.longitude)
        }

        if let currentLocation {
            minLatitude = min(minLatitude, currentLocation.latitude)
            maxLatitude = max(maxLatitude, currentLocation.latitude)
            minLongitude = min(minLongitude, currentLocation.longitude)
            maxLongitude = max(maxLongitude, currentLocation.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLatitude - minLatitude) * 1.35, 0.02),
                longitudeDelta: max((maxLongitude - minLongitude) * 1.35, 0.02)
            )
        )
    }

    private static func latitudeDelta(forMeters meters: Double) -> Double {
        meters / 111_000
    }

    private static func longitudeDelta(forMeters meters: Double, latitude: Double) -> Double {
        let cosine = max(abs(cos(latitude * .pi / 180)), 0.2)
        return meters / (111_000 * cosine)
    }
}

private extension RoutinePlace {
    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension LocationCoordinate {
    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
