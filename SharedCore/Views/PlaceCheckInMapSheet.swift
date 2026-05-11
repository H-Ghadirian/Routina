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

    @Dependency(\.locationClient) private var locationClient
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RoutinePlace.name) private var places: [RoutinePlace]
    @Query(sort: \PlaceCheckInSession.startedAt, order: .reverse) private var sessions: [PlaceCheckInSession]

    @State private var locationSnapshot = LocationSnapshot(authorizationStatus: .notDetermined)
    @State private var isLoadingLocation = false
    @State private var selectedMode = PlaceCheckInMapSheetMode.places
    @State private var selectedDay = Date()
    @State private var selectedPlaceID: UUID?
    @State private var visibleRegion = PlaceCheckInMapCamera.region(
        places: [],
        currentLocation: nil,
        selectedPlaceID: nil
    )
    @State private var mapPosition = PlaceCheckInMapCamera.position(
        region: PlaceCheckInMapCamera.region(
            places: [],
            currentLocation: nil,
            selectedPlaceID: nil
        )
    )
    @State private var errorText: String?

    init(
        selectedActivity: PlaceCheckInActivity?,
        showsNavigationChrome: Bool = true,
        showsInlineHeader: Bool = true,
        layout: PlaceCheckInMapSheetLayout = .stack,
        onClose: (() -> Void)? = nil
    ) {
        self.selectedActivity = selectedActivity
        self.showsNavigationChrome = showsNavigationChrome
        self.showsInlineHeader = showsInlineHeader
        self.layout = layout
        self.onClose = onClose
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

    private var daySessions: [PlaceCheckInSession] {
        PlaceCheckInSupport.sessions(sessions, on: selectedDay, calendar: calendar)
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
        .onChange(of: places.map(\.id)) { _, _ in
            if let selectedPlaceID, !places.contains(where: { $0.id == selectedPlaceID }) {
                self.selectedPlaceID = nil
            }
            syncMapPosition()
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
            .background(.bar)

            Divider()

            mapPreview
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mapDetailPicker: some View {
        Picker("Map detail", selection: $selectedMode) {
            ForEach(PlaceCheckInMapSheetMode.allCases) { mode in
                Label(mode.title, systemImage: mode.systemImage)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var mapDetailContent: some View {
        switch selectedMode {
        case .places:
            placesList
        case .day:
            dayTimeline
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
        Map(position: $mapPosition) {
            UserAnnotation()

            ForEach(places) { place in
                MapCircle(
                    center: place.mapCoordinate,
                    radius: place.radiusMeters
                )
                .foregroundStyle(placeMapTint(for: place).opacity(isSelected(place) ? 0.24 : 0.12))

                Annotation(place.displayName, coordinate: place.mapCoordinate) {
                    Button {
                        selectedPlaceID = place.id
                        syncMapPosition()
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
            }

            if let currentLocation {
                Annotation("Current Location", coordinate: currentLocation.mapCoordinate) {
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
            }

            ForEach(daySessions.filter { $0.placeID == nil && $0.coordinate != nil }) { session in
                if let coordinate = session.coordinate {
                    Annotation(session.displayPlaceName, coordinate: coordinate.mapCoordinate) {
                        Image(systemName: "clock.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Color.teal, in: Circle())
                            .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
                    }
                }
            }
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
                .background(.ultraThinMaterial, in: Capsule())
                .padding(10)
        }
        .overlay(alignment: .trailing) {
            mapControls
        }
        .accessibilityLabel("Place check-in map")
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
                Task {
                    if currentLocation == nil {
                        await refreshLocation(requestAuthorizationIfNeeded: true)
                    }
                    focusOnCurrentLocation()
                }
            }
        }
        .frame(width: 40)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

                Button {
                    Task { await refreshLocation(requestAuthorizationIfNeeded: true) }
                } label: {
                    Image(systemName: isLoadingLocation ? "location.circle" : "location.circle.fill")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(isLoadingLocation)
                .accessibilityLabel("Refresh current location")
            }

            Text(locationStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var placesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Saved Places")
                .font(.subheadline.weight(.semibold))

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
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            HStack(spacing: 8) {
                Button {
                    shiftSelectedDay(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Previous day")

                VStack(alignment: .leading, spacing: 1) {
                    Text(dayTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(daySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Button("Today") {
                    selectedDay = Date()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    shiftSelectedDay(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Next day")
            }

            if daySessions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No check-ins")
                        .font(.subheadline.weight(.semibold))
                    Text("Your place sessions for this day will appear here in time order.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(daySessions) { session in
                            dayTimelineRow(session)
                        }
                    }
                }
            }
        }
    }

    private func placeRow(_ place: RoutinePlace) -> some View {
        Button {
            selectedPlaceID = place.id
            checkIn(at: place)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: activeSession?.placeID == place.id ? "location.fill" : "mappin")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected(place) ? Color.accentColor : Color.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(isSelected(place) ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.10))
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

                Image(systemName: "checkmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected(place) ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.07))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Check in at \(place.displayName)")
    }

    private func dayTimelineRow(_ session: PlaceCheckInSession) -> some View {
        Button {
            if let coordinate = session.coordinate {
                selectedPlaceID = session.placeID
                focus(on: coordinate)
            }
        } label: {
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
                                .background(.teal.opacity(0.12), in: Capsule())
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

                Image(systemName: session.coordinate == nil ? "mappin.slash" : "scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(session.coordinate == nil)
        .accessibilityLabel("Show \(session.displayPlaceName) on map")
    }

    private var mapTitle: String {
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

    private var dayTitle: String {
        if calendar.isDateInToday(selectedDay) {
            return "Today"
        }
        if calendar.isDateInYesterday(selectedDay) {
            return "Yesterday"
        }
        return selectedDay.formatted(.dateTime.month(.abbreviated).day().weekday(.abbreviated))
    }

    private var daySubtitle: String {
        let total = PlaceCheckInSupport.totalDurationSeconds(for: daySessions)
        let duration = PlaceCheckInFormatting.durationText(seconds: total)
        let countText = daySessions.count == 1 ? "1 check-in" : "\(daySessions.count) check-ins"
        return "\(duration) tracked · \(countText)"
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

    private func sessionTimelineSubtitle(_ session: PlaceCheckInSession) -> String {
        let start = session.startedAt ?? session.createdAt
        let range: String
        if let start {
            let startText = start.formatted(.dateTime.hour().minute())
            if let endedAt = session.endedAt {
                range = "\(startText)-\(endedAt.formatted(.dateTime.hour().minute()))"
            } else {
                range = "\(startText)-Now"
            }
        } else {
            range = "Time unavailable"
        }

        let duration = PlaceCheckInFormatting.durationText(seconds: session.durationSeconds())
        return "\(range) · \(duration)"
    }

    private func shiftSelectedDay(by value: Int) {
        selectedDay = calendar.date(byAdding: .day, value: value, to: selectedDay) ?? selectedDay
    }

    @MainActor
    private func refreshLocation(requestAuthorizationIfNeeded: Bool) async {
        isLoadingLocation = true
        defer { isLoadingLocation = false }

        let snapshot = await locationClient.snapshot(requestAuthorizationIfNeeded)
        locationSnapshot = snapshot
        if let coordinate = snapshot.coordinate,
           let nearbyPlace = PlaceCheckInSupport.nearestContainingPlace(to: coordinate, places: places) {
            selectedPlaceID = nearbyPlace.id
        }
        syncMapPosition()
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
        selectedPlaceID = currentMatchedPlace?.id
        focus(on: currentLocation)
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
            signalSuccess()
            close()
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
            signalSuccess()
            close()
        } catch {
            errorText = "Could not check in at \(place.displayName)."
            NSLog("Failed to check in at place from map: \(error.localizedDescription)")
        }
    }

    private func syncMapPosition() {
        let region = PlaceCheckInMapCamera.region(
            places: places,
            currentLocation: currentLocation,
            selectedPlaceID: selectedPlaceID
        )
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

    private func signalSuccess() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

private enum PlaceCheckInMapSheetMode: String, CaseIterable, Identifiable {
    case places
    case day

    var id: Self { self }

    var title: String {
        switch self {
        case .places:
            return "Places"
        case .day:
            return "Day"
        }
    }

    var systemImage: String {
        switch self {
        case .places:
            return "mappin"
        case .day:
            return "calendar"
        }
    }
}

private enum PlaceCheckInMapCamera {
    static func position(region: MKCoordinateRegion) -> MapCameraPosition {
        .region(region)
    }

    static func region(
        places: [RoutinePlace],
        currentLocation: LocationCoordinate?,
        selectedPlaceID: UUID?
    ) -> MKCoordinateRegion {
        if let selectedPlaceID,
           let selectedPlace = places.first(where: { $0.id == selectedPlaceID }) {
            return region(focusingOn: selectedPlace)
        }

        if !places.isEmpty {
            return regionIncluding(places: places, currentLocation: currentLocation)
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
        currentLocation: LocationCoordinate?
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
