import Foundation
import MapKit
import SwiftUI
#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

struct PlaceCheckInConfirmSwipeModifier: ViewModifier {
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

enum PlaceCheckInMapSheetMode: String, CaseIterable, Identifiable {
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

struct PlaceCheckInSessionEditDraft: Identifiable {
    let id: UUID
    let canRemainActive: Bool
    var placeName: String
    var startedAt: Date
    var endedAt: Date
    var hasEndTime: Bool
    var activity: PlaceCheckInActivity?
    var note: String
    var imageData: Data?

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
        self.imageData = session.imageData
    }
}

struct PlaceCheckInSessionDeletionCandidate: Identifiable {
    let id: UUID
    let title: String
}

struct PlaceCheckInNewPlaceDraft: Identifiable, Equatable {
    static let defaultRadiusMeters = 150.0

    let id = UUID()
    var coordinate: LocationCoordinate
    var name = ""
    var radiusMeters = defaultRadiusMeters
    var statusMessage = ""
    var sourceSessionID: UUID?
    var isCurrentLocationDraft = false
}

struct PlaceCheckInPlaceEditDraft: Identifiable, Equatable {
    let id: UUID
    var name: String
    var coordinate: LocationCoordinate
    var radiusMeters: Double

    init(place: RoutinePlace) {
        id = place.id
        name = place.displayName
        coordinate = LocationCoordinate(latitude: place.latitude, longitude: place.longitude)
        radiusMeters = place.radiusMeters
    }
}

struct PlaceCheckInPlaceDeletionCandidate: Identifiable {
    let id: UUID
    let title: String
}

struct PlaceCheckInPlaceEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: PlaceCheckInPlaceEditDraft
    @State private var errorText: String?

    let onSave: (PlaceCheckInPlaceEditDraft) throws -> Void

    init(
        draft: PlaceCheckInPlaceEditDraft,
        onSave: @escaping (PlaceCheckInPlaceEditDraft) throws -> Void
    ) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Place") {
                    TextField("Name", text: $draft.name)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Radius")
                            Spacer()
                            Text("\(Int(draft.radiusMeters.rounded())) m")
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $draft.radiusMeters, in: 25...2_000, step: 25)
                    }
                }

                Section("Location") {
                    Text(draft.coordinate.formattedForPlaceSelection)
                        .foregroundStyle(.secondary)
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
            .navigationTitle("Edit Place")
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
            .frame(minWidth: 420, minHeight: 300)
        #endif
    }

    private var validationMessage: String? {
        if RoutinePlace.cleanedName(draft.name) == nil {
            return "Enter a place name."
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

struct PlaceCheckInDetailCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassPanel(cornerRadius: 12, tint: .secondary, tintOpacity: 0.06)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }
}

struct PlaceCheckInImagePreview: View {
    let data: Data
    let contentMode: ContentMode

    var body: some View {
        if let image = previewImage {
            image
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            Rectangle()
                .fill(Color.secondary.opacity(0.12))
                .overlay(
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                )
        }
    }

    private var previewImage: Image? {
        #if os(iOS)
            guard let uiImage = UIImage(data: data) else { return nil }
            return Image(uiImage: uiImage)
        #elseif os(macOS)
            guard let nsImage = NSImage(data: data) else { return nil }
            return Image(nsImage: nsImage)
        #else
            return nil
        #endif
    }
}

enum PlaceCheckInMapCamera {
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
            let selectedPlace = places.first(where: { $0.id == selectedPlaceID })
        {
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

extension RoutinePlace {
    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension LocationCoordinate {
    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
