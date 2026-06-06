import Foundation
import MapKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
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

struct PlaceCheckInSessionEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: PlaceCheckInSessionEditDraft
    @State private var errorText: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isImageImporterPresented = false

    let onSave: (PlaceCheckInSessionEditDraft) throws -> Void

    init(
        draft: PlaceCheckInSessionEditDraft,
        onSave: @escaping (PlaceCheckInSessionEditDraft) throws -> Void
    ) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        let hasImage = draft.imageData?.isEmpty == false
        let imagePickerLabel = hasImage ? "Replace Image" : "Choose Image"
        let imageImportLabel = hasImage ? "Browse Another File" : "Browse"

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

                Section("Image") {
                    if let imageData = draft.imageData, !imageData.isEmpty {
                        PlaceCheckInImagePreview(data: imageData, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                            )
                    } else {
                        Label("No image selected", systemImage: "photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label(imagePickerLabel, systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(.bordered)

                        Button(imageImportLabel) {
                            isImageImporterPresented = true
                        }
                        .buttonStyle(.bordered)

                        if hasImage {
                            Button("Remove") {
                                selectedPhotoItem = nil
                                draft.imageData = nil
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Text("Images are resized and compressed before saving to reduce storage use.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            loadPickedImage(from: newItem)
        }
        .fileImporter(
            isPresented: $isImageImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleImageImport(result)
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 520)
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

    private func loadPickedImage(from item: PhotosPickerItem) {
        _ = Task {
            let data = try? await item.loadTransferable(type: Data.self)
            let compressedData = data.flatMap(TaskImageProcessor.compressedImageData(from:))
            await MainActor.run {
                draft.imageData = compressedData
                selectedPhotoItem = nil
            }
        }
    }

    private func handleImageImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        draft.imageData = TaskImageProcessor.compressedImageData(fromFileAt: url)
    }
}

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
                    detailRow(title: "Range", value: timeRangeText)
                    detailRow(title: "Duration", value: durationText)
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
                       session.placeRadiusMeters == nil {
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

                Text(timeRangeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    if session.isActive {
                        statusPill("Now", tint: .teal)
                    }

                    if session.isAutomatic {
                        statusPill(session.requiresConfirmation ? "Auto pending" : "Auto", tint: session.requiresConfirmation ? .orange : .secondary)
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

    private var timeRangeText: String {
        guard let startedAt = session.startedAt ?? session.createdAt else {
            return "Time unavailable"
        }

        if let endedAt = session.endedAt {
            return "\(startedAt.formatted(date: .abbreviated, time: .shortened)) - \(endedAt.formatted(date: .abbreviated, time: .shortened))"
        }

        return "Since \(startedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private var durationText: String {
        PlaceCheckInFormatting.durationText(seconds: session.durationSeconds(referenceDate: Date()))
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

private struct PlaceCheckInDetailCard<Content: View>: View {
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
