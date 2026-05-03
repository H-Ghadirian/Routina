import MapKit
import SwiftUI

struct MacPlaceFilterAllItemsRow: View {
    let taskListMode: HomeFeature.TaskListMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "square.grid.2x2")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.10))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
        }
        .buttonStyle(.plain)
    }

    private var title: String {
        switch taskListMode {
        case .all:
            return "All tasks"
        case .routines:
            return "All routines"
        case .todos:
            return "All todos"
        }
    }

    private var description: String {
        switch taskListMode {
        case .all:
            return "Show every task without filtering by place."
        case .routines:
            return "Show every routine without filtering by place."
        case .todos:
            return "Show every todo without filtering by place."
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.07))
    }
}

struct MacPlaceFilterMapPreview: View {
    let options: [MacPlaceFilterOption]
    let selectedPlaceID: UUID?
    let currentLocation: LocationCoordinate?
    @Binding var mapPosition: MapCameraPosition

    var body: some View {
        Map(position: $mapPosition) {
            ForEach(options) { option in
                MapCircle(
                    center: option.coordinate,
                    radius: option.place.radiusMeters
                )
                .foregroundStyle(circleColor(for: option))

                Annotation(option.place.displayName, coordinate: option.coordinate) {
                    Circle()
                        .fill(selectedPlaceID == option.id ? Color.accentColor : Color.white.opacity(0.92))
                        .overlay(
                            Circle()
                                .stroke(selectedPlaceID == option.id ? Color.white : Color.accentColor, lineWidth: 2)
                        )
                        .frame(width: selectedPlaceID == option.id ? 14 : 10, height: selectedPlaceID == option.id ? 14 : 10)
                        .shadow(color: .black.opacity(0.14), radius: 3, y: 1)
                }
            }

            if let currentLocation {
                Annotation("Current Location", coordinate: currentLocation.clLocationCoordinate2D) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.18))
                            .frame(width: 20, height: 20)

                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .mapStyle(.standard)
        .allowsHitTesting(false)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            Text(selectedPlaceMapTitle)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(10)
        }
        .frame(maxWidth: 280, maxHeight: .infinity)
    }

    private var selectedPlaceMapTitle: String {
        if let selectedPlaceID,
           let option = options.first(where: { $0.id == selectedPlaceID }) {
            return option.place.displayName
        }
        return "All saved places"
    }

    private func circleColor(for option: MacPlaceFilterOption) -> Color {
        selectedPlaceID == option.id ? Color.accentColor.opacity(0.22) : Color.accentColor.opacity(0.10)
    }
}
