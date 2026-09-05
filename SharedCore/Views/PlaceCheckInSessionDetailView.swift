import Foundation
import MapKit
import SwiftUI

struct PlaceCheckInSessionDetailView: View {
    let session: PlaceCheckInSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let imageData = session.imageData, !imageData.isEmpty {
                    PlaceCheckInImagePreview(data: imageData, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                        )
                }

                PlaceCheckInDetailCard(title: "Time", systemImage: "clock") {
                    detailRow(title: "Check-in", value: checkInTimeText)
                    if let endedAt = session.endedAt {
                        detailRow(title: "End", value: endedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    if session.isActive {
                        detailRow(title: "Status", value: "Active")
                    }
                }

                if let activity = session.activity {
                    PlaceCheckInDetailCard(title: "Activity", systemImage: activity.systemImage) {
                        Label(activity.title, systemImage: activity.systemImage)
                            .font(.body.weight(.medium))
                    }
                }

                if let note = PlaceCheckInSession.cleanedNote(session.note) {
                    PlaceCheckInDetailCard(title: "Note", systemImage: "text.alignleft") {
                        Text(note)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }

                PlaceCheckInDetailCard(title: "Location", systemImage: "mappin.and.ellipse") {
                    if let coordinate = session.coordinate {
                        PlaceCheckInSessionLocationMap(session: session, coordinate: coordinate)
                        detailRow(title: "Coordinate", value: coordinate.formattedForPlaceSelection)
                    }
                    if let accuracy = session.horizontalAccuracyMeters {
                        detailRow(title: "Accuracy", value: "\(Int(accuracy.rounded())) m")
                    }
                    if let radius = session.placeRadiusMeters {
                        detailRow(title: "Place radius", value: "\(Int(radius.rounded())) m")
                    }
                    if session.coordinate == nil,
                        session.horizontalAccuracyMeters == nil,
                        session.placeRadiusMeters == nil
                    {
                        Text("No saved coordinate for this check-in.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(24)
        }
        .navigationTitle(session.displayPlaceName)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.16))
                Image(systemName: "mappin.and.ellipse")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.teal)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 6) {
                Text(session.displayPlaceName)
                    .font(.largeTitle.weight(.semibold))
                    .lineLimit(3)

                Text(checkInTimeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    if session.isActive {
                        statusPill("Now", tint: .teal)
                    }

                    if session.isAutomatic {
                        statusPill(
                            session.requiresConfirmation ? "Auto pending" : "Auto",
                            tint: session.requiresConfirmation ? .orange : .secondary)
                    }

                    if let activity = session.activity {
                        Label(activity.title, systemImage: activity.systemImage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .routinaGlassPill(tint: .secondary, tintOpacity: 0.10)
                    }
                }
            }
        }
    }

    private func statusPill(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .routinaGlassPill(tint: tint, tintOpacity: 0.12)
    }

    private var checkInTimeText: String {
        guard let startedAt = session.startedAt ?? session.createdAt else {
            return "Time unavailable"
        }

        return startedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            Text(value)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PlaceCheckInSessionLocationMap: View {
    let session: PlaceCheckInSession
    let coordinate: LocationCoordinate
    @State private var mapPosition: MapCameraPosition

    init(session: PlaceCheckInSession, coordinate: LocationCoordinate) {
        self.session = session
        self.coordinate = coordinate
        _mapPosition = State(
            initialValue: PlaceCheckInMapCamera.position(
                region: PlaceCheckInMapCamera.region(focusingOn: coordinate)
            )
        )
    }

    var body: some View {
        Map(position: $mapPosition) {
            if let radius = session.placeRadiusMeters {
                MapCircle(center: coordinate.mapCoordinate, radius: radius)
                    .foregroundStyle(Color.teal.opacity(0.16))
            }

            Annotation(session.displayPlaceName, coordinate: coordinate.mapCoordinate) {
                ZStack {
                    Circle()
                        .fill(Color.teal)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 30, height: 30)
                .shadow(color: Color.black.opacity(0.16), radius: 4, y: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
        .accessibilityLabel("Map showing check-in location")
    }
}
