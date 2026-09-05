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
