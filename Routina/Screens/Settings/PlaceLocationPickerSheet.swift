import MapKit
import SwiftUI

struct PlaceLocationPickerSheet: View {
    let fallbackCoordinate: LocationCoordinate?
    let cameraConfiguration: PlaceLocationPickerCameraConfiguration
    let onUseLocation: (LocationCoordinate, Double) -> Void
    let onCancel: () -> Void

    @State private var selectedCoordinate: LocationCoordinate?
    @State private var draftRadiusMeters: Double
    @State private var cameraAnimationTrigger = 0
    @State private var cameraAnimationTarget: PlaceLocationPickerCameraConfiguration.AnimationTarget?

    init(
        initialCoordinate: LocationCoordinate?,
        initialRadiusMeters: Double,
        fallbackCoordinate: LocationCoordinate?,
        onUseLocation: @escaping (LocationCoordinate, Double) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.fallbackCoordinate = fallbackCoordinate
        self.cameraConfiguration = .make(
            initialCoordinate: initialCoordinate,
            fallbackCoordinate: fallbackCoordinate,
            radiusMeters: initialRadiusMeters
        )
        self.onUseLocation = onUseLocation
        self.onCancel = onCancel
        _selectedCoordinate = State(initialValue: initialCoordinate)
        _draftRadiusMeters = State(initialValue: min(max(initialRadiusMeters, 25), 2_000))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tap the map to place the center point.")
                        .font(.headline)
                    Text("Adjust the radius below. The highlighted circle shows when the place becomes active.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                MapReader { proxy in
                    Map(initialPosition: cameraConfiguration.initialFocus.mapCameraPosition) {
                        UserAnnotation()

                        if let selectedCoordinate {
                            Marker("Selected Place", coordinate: selectedCoordinate.clLocationCoordinate2D)
                            MapCircle(
                                center: selectedCoordinate.clLocationCoordinate2D,
                                radius: draftRadiusMeters
                            )
                            .foregroundStyle(Color.accentColor.opacity(0.18))
                        }
                    }
                    .mapCameraKeyframeAnimator(trigger: cameraAnimationTrigger) { camera in
                        KeyframeTrack(\MapCamera.centerCoordinate) {
                            LinearKeyframe(
                                cameraAnimationTarget?.coordinate.clLocationCoordinate2D ?? camera.centerCoordinate,
                                duration: 0.75,
                                timingCurve: .easeInOut
                            )
                        }
                        KeyframeTrack(\MapCamera.distance) {
                            LinearKeyframe(
                                cameraAnimationTarget?.distance ?? camera.distance,
                                duration: 0.75,
                                timingCurve: .easeInOut
                            )
                        }
                    }
                    .mapStyle(.standard)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        Text(selectedCoordinate == nil ? "Tap to choose a location" : "Tap anywhere to move the center")
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(16)
                    }
                    .simultaneousGesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                guard let coordinate = proxy.convert(value.location, from: .local) else {
                                    return
                                }

                                let location = LocationCoordinate(
                                    latitude: coordinate.latitude,
                                    longitude: coordinate.longitude
                                )
                                selectedCoordinate = location
                                animateCamera(to: location)
                            }
                    )
                }
                .frame(minHeight: 360)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Radius")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(draftRadiusMeters)) m")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $draftRadiusMeters, in: 25...2_000, step: 25)

                    if let selectedCoordinate {
                        Text("Center: \(selectedCoordinate.formattedForPlaceSelection)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if let fallbackCoordinate {
                        Text("Map is centered near \(fallbackCoordinate.formattedForPlaceSelection).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No center selected yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .navigationTitle("Choose Place")
            .routinaPlaceLocationPickerNavigationTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Use This Location") {
                        guard let selectedCoordinate else {
                            return
                        }
                        onUseLocation(selectedCoordinate, draftRadiusMeters)
                    }
                    .disabled(selectedCoordinate == nil)
                }
            }
        }
        .onChange(of: draftRadiusMeters) { _, _ in
            guard let selectedCoordinate else { return }
            animateCamera(to: selectedCoordinate)
        }
        .routinaPlaceLocationPickerFrame()
    }

    private func animateCamera(to coordinate: LocationCoordinate) {
        cameraAnimationTarget = PlaceLocationPickerCameraConfiguration.animationTarget(
            for: coordinate,
            radiusMeters: draftRadiusMeters
        )
        cameraAnimationTrigger += 1
    }
}
