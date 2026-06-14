import ComposableArchitecture
import SwiftData
import SwiftUI

struct RoutinaMacPlaceCheckInToolbarItem: ToolbarContent {
    let locationSnapshot: LocationSnapshot
    let onMapRequested: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            RoutinaMacPlaceCheckInToolbarButton(
                locationSnapshot: locationSnapshot,
                onMapRequested: onMapRequested
            )
        }
    }
}

private struct RoutinaMacPlaceCheckInToolbarButton: View {
    let locationSnapshot: LocationSnapshot
    let onMapRequested: () -> Void

    @Dependency(\.locationClient) private var locationClient
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \RoutinePlace.name) private var places: [RoutinePlace]
    @Query(sort: \PlaceCheckInSession.startedAt, order: .reverse) private var sessions: [PlaceCheckInSession]
    @State private var refreshedLocationSnapshot: LocationSnapshot?

    var body: some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 60)) { timeline in
            Button {
                onMapRequested()
            } label: {
                toolbarLabel
            }
            .buttonStyle(.plain)
            .controlSize(.small)
            .help(helpText(now: timeline.date))
            .accessibilityLabel(accessibilityLabel(now: timeline.date))
            .padding(.leading, 8)
            .padding(.trailing, 8)
        }
        .task {
            await refreshLocationSnapshot()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshLocationSnapshot()
            }
        }
    }

    private var effectiveLocationSnapshot: LocationSnapshot {
        guard let refreshedLocationSnapshot else {
            return locationSnapshot
        }

        return refreshedLocationSnapshot.retainingLastKnownCoordinate(from: locationSnapshot)
    }

    private var currentLocationName: String? {
        guard effectiveLocationSnapshot.canDeterminePresence,
              let coordinate = effectiveLocationSnapshot.coordinate
        else { return nil }

        return PlaceCheckInSupport.currentLocationDisplayName(
            coordinate: coordinate,
            places: places,
            sessions: sessions
        )
    }

    private var activeAutomaticSession: PlaceCheckInSession? {
        sessions.first { session in
            session.endedAt == nil && session.isAutomatic
        }
    }

    private var titleState: TitleState {
        if let currentLocationName {
            return .currentLocation(currentLocationName)
        }
        if let activeAutomaticSession {
            return .currentLocation(activeAutomaticSession.displayPlaceName)
        }
        return .checkIn
    }

    private var labelSystemImage: String {
        switch titleState {
        case .currentLocation:
            return "location.fill"
        case .checkIn:
            return "mappin.and.ellipse"
        }
    }

    private var toolbarLabel: some View {
        HStack(spacing: 7) {
            Image(systemName: labelSystemImage)
                .font(.caption.weight(.semibold))
                .symbolRenderingMode(.hierarchical)

            Text(labelTitle)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: labelMaxWidth, alignment: .leading)
        }
        .foregroundStyle(toolbarForegroundStyle)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .routinaGlassPill(
            tint: .teal,
            tintOpacity: isNamedLocation ? 0.18 : 0.12,
            interactive: true
        )
        .overlay(toolbarBorder)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var toolbarBorder: some View {
        Capsule(style: .continuous)
            .stroke(Color.teal.opacity(isNamedLocation ? 0.38 : 0.24), lineWidth: 1)
    }

    private var toolbarForegroundStyle: Color {
        isNamedLocation ? .teal : .primary
    }

    private var labelMaxWidth: CGFloat? {
        isNamedLocation ? 160 : nil
    }

    private var labelTitle: String {
        switch titleState {
        case let .currentLocation(name):
            return name
        case .checkIn:
            return "Check In"
        }
    }

    private var isNamedLocation: Bool {
        switch titleState {
        case .currentLocation:
            return true
        case .checkIn:
            return false
        }
    }

    private func helpText(now: Date) -> String {
        switch titleState {
        case let .currentLocation(name):
            return "Open Places, current location: \(name)"
        case .checkIn:
            return "Open Places"
        }
    }

    private func accessibilityLabel(now: Date) -> String {
        switch titleState {
        case let .currentLocation(name):
            return "Open Places, current location: \(name)"
        case .checkIn:
            return "Open Places"
        }
    }

    private enum TitleState {
        case checkIn
        case currentLocation(String)
    }

    @MainActor
    private func refreshLocationSnapshot() async {
        refreshedLocationSnapshot = await locationClient.snapshot(false)
    }
}
