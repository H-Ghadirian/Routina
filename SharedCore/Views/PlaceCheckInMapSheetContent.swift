import Foundation
import SwiftUI

struct PlaceCheckInCurrentLocationPanel: View {
    let buttonTitle: String
    let statusText: String
    let showsLocationSettingsButton: Bool
    let isCheckInDisabled: Bool
    let onCheckInAtCurrentLocation: () -> Void
    let onOpenLocationSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    onCheckInAtCurrentLocation()
                } label: {
                    Label(buttonTitle, systemImage: "location.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(isCheckInDisabled)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if showsLocationSettingsButton {
                    Button {
                        onOpenLocationSettings()
                    } label: {
                        Label("Open Location Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
}

struct PlaceCheckInPlacesList: View {
    let places: [RoutinePlace]
    let activeSessionPlaceID: UUID?
    let selectedPlaceID: UUID?
    let currentLocation: LocationCoordinate?
    let onSelectPlace: (RoutinePlace) -> Void
    let onCheckInAtPlace: (RoutinePlace) -> Void
    let onEditPlace: (RoutinePlace) -> Void
    let onDeletePlace: (RoutinePlace) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if places.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(places) { place in
                            PlaceCheckInPlaceRow(
                                place: place,
                                isActive: activeSessionPlaceID == place.id,
                                isSelected: selectedPlaceID == place.id,
                                subtitle: placeSubtitle(place),
                                onSelect: { onSelectPlace(place) },
                                onCheckIn: { onCheckInAtPlace(place) },
                                onEdit: { onEditPlace(place) },
                                onDelete: { onDeletePlace(place) }
                            )
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
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
}

private struct PlaceCheckInPlaceRow: View {
    let place: RoutinePlace
    let isActive: Bool
    let isSelected: Bool
    let subtitle: String
    let onSelect: () -> Void
    let onCheckIn: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                onSelect()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isActive ? "location.fill" : "mappin")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .frame(width: 28, height: 28)
                        .routinaGlassPill(
                            tint: isSelected ? .accentColor : .secondary,
                            tintOpacity: isSelected ? 0.16 : 0.10
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(subtitle)
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
                onCheckIn()
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Check in at \(place.displayName)")
            .help("Check in at \(place.displayName)")

            PlaceCheckInPlaceActionsMenu(
                onEdit: onEdit,
                onDelete: onDelete
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassCard(
            cornerRadius: 8,
            tint: isSelected ? .accentColor : .secondary,
            tintOpacity: isSelected ? 0.12 : 0.07,
            interactive: true
        )
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit Place", systemImage: "pencil")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Place", systemImage: "trash")
            }
        }
    }
}

private struct PlaceCheckInPlaceActionsMenu: View {
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Menu {
            Button {
                onEdit()
            } label: {
                Label("Edit Place", systemImage: "pencil")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Place", systemImage: "trash")
            }
        } label: {
            Label("Place actions", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Place actions")
        .help("More actions")
    }
}

struct PlaceCheckInDayTimelineList: View {
    let sections: [PlaceCheckInDaySection]
    let calendar: Calendar
    let canFocusOnSession: (PlaceCheckInSession) -> Bool
    let canSaveSessionAsPlace: (PlaceCheckInSession) -> Bool
    let onFocusSession: (PlaceCheckInSession) -> Void
    let onEditSession: (PlaceCheckInSession) -> Void
    let onDeleteSession: (PlaceCheckInSession) -> Void
    let onSaveSessionAsPlace: (PlaceCheckInSession) -> Void
    let onConfirmAutomaticSession: (PlaceCheckInSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if sections.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(sections) { section in
                            PlaceCheckInDayTimelineSectionView(
                                section: section,
                                calendar: calendar,
                                canFocusOnSession: canFocusOnSession,
                                canSaveSessionAsPlace: canSaveSessionAsPlace,
                                onFocusSession: onFocusSession,
                                onEditSession: onEditSession,
                                onDeleteSession: onDeleteSession,
                                onSaveSessionAsPlace: onSaveSessionAsPlace,
                                onConfirmAutomaticSession: onConfirmAutomaticSession
                            )
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
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
    }
}

private struct PlaceCheckInDayTimelineSectionView: View {
    let section: PlaceCheckInDaySection
    let calendar: Calendar
    let canFocusOnSession: (PlaceCheckInSession) -> Bool
    let canSaveSessionAsPlace: (PlaceCheckInSession) -> Bool
    let onFocusSession: (PlaceCheckInSession) -> Void
    let onEditSession: (PlaceCheckInSession) -> Void
    let onDeleteSession: (PlaceCheckInSession) -> Void
    let onSaveSessionAsPlace: (PlaceCheckInSession) -> Void
    let onConfirmAutomaticSession: (PlaceCheckInSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(TimelineLogic.daySectionTitle(for: section.date, calendar: calendar))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)

            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(section.sessions) { session in
                    PlaceCheckInDayTimelineRow(
                        session: session,
                        canFocus: canFocusOnSession(session),
                        canSaveAsPlace: canSaveSessionAsPlace(session),
                        onFocus: { onFocusSession(session) },
                        onEdit: { onEditSession(session) },
                        onDelete: { onDeleteSession(session) },
                        onSaveAsPlace: { onSaveSessionAsPlace(session) },
                        onConfirm: { onConfirmAutomaticSession(session) }
                    )
                }
            }
        }
    }
}

private struct PlaceCheckInDayTimelineRow: View {
    let session: PlaceCheckInSession
    let canFocus: Bool
    let canSaveAsPlace: Bool
    let onFocus: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSaveAsPlace: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Button {
                    onFocus()
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        timelineMarker
                        content
                        Spacer(minLength: 8)
                        imagePreview

                        Image(systemName: canFocus ? "scope" : "mappin.slash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(.plain)
                .disabled(!canFocus)

                PlaceCheckInSessionActionsMenu(
                    showsConfirm: session.requiresConfirmation,
                    showsSaveAsPlace: canSaveAsPlace,
                    onConfirm: onConfirm,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onSaveAsPlace: onSaveAsPlace
                )
            }

            if canSaveAsPlace {
                saveAsPlaceButton
                    .padding(.leading, 28)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassCard(cornerRadius: 8, tint: .secondary, tintOpacity: 0.07, interactive: true)
        .contextMenu {
            if session.requiresConfirmation {
                Button {
                    onConfirm()
                } label: {
                    Label("Confirm Auto Check-In", systemImage: "checkmark.circle")
                }

                Divider()
            }

            Button {
                onEdit()
            } label: {
                Label("Edit Check-In", systemImage: "pencil")
            }

            if canSaveAsPlace {
                Button {
                    onSaveAsPlace()
                } label: {
                    Label("Save as Place", systemImage: "mappin.and.ellipse")
                }
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Check-In", systemImage: "trash")
            }
        }
        .modifier(
            PlaceCheckInConfirmSwipeModifier(
                showsConfirm: session.requiresConfirmation,
                action: onConfirm
            )
        )
        .accessibilityLabel("Show \(session.displayPlaceName) on map")
    }

    private var timelineMarker: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(session.isActive ? Color.teal : Color.accentColor)
                .frame(width: 10, height: 10)
            Rectangle()
                .fill(Color.secondary.opacity(0.22))
                .frame(width: 2, height: 34)
        }
        .frame(width: 18)
    }

    private var content: some View {
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

            Text(sessionTimelineSubtitle)
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
    }

    private var saveAsPlaceButton: some View {
        Button {
            onSaveAsPlace()
        } label: {
            Label("Save as Place", systemImage: "mappin.and.ellipse")
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let imageData = session.imageData, !imageData.isEmpty {
            PlaceCheckInImagePreview(data: imageData, contentMode: .fill)
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
        }
    }

    private var sessionTimelineSubtitle: String {
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
}

private struct PlaceCheckInSessionActionsMenu: View {
    let showsConfirm: Bool
    let showsSaveAsPlace: Bool
    let onConfirm: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSaveAsPlace: () -> Void

    var body: some View {
        Menu {
            if showsConfirm {
                Button {
                    onConfirm()
                } label: {
                    Label("Confirm Auto Check-In", systemImage: "checkmark.circle")
                }

                Divider()
            }

            Button {
                onEdit()
            } label: {
                Label("Edit Check-In", systemImage: "pencil")
            }

            if showsSaveAsPlace {
                Button {
                    onSaveAsPlace()
                } label: {
                    Label("Save as Place", systemImage: "mappin.and.ellipse")
                }
            }

            Button(role: .destructive) {
                onDelete()
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
}
