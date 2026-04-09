import MapKit
import Testing
@testable @preconcurrency import RoutinaAppSupport

@Suite
struct PlaceLocationPickerCameraConfigurationTests {
    @Test
    func make_withInitialCoordinate_prefersSelectedCamera() throws {
        let coordinate = LocationCoordinate(latitude: 52.52, longitude: 13.405)

        let configuration = PlaceLocationPickerCameraConfiguration.make(
            initialCoordinate: coordinate,
            fallbackCoordinate: LocationCoordinate(latitude: 48.1374, longitude: 11.5755),
            radiusMeters: 180
        )

        #expect(
            configuration.initialFocus
                == .selected(coordinate: coordinate, distance: 1_440)
        )

        let camera = try #require(configuration.initialFocus.mapCameraPosition.camera)
        #expect(camera.centerCoordinate.latitude == coordinate.latitude)
        #expect(camera.centerCoordinate.longitude == coordinate.longitude)
        #expect(camera.distance == 1_440)
    }

    @Test
    func make_withoutInitialCoordinate_usesUserLocationWithFallbackRegion() throws {
        let fallback = LocationCoordinate(latitude: 48.1374, longitude: 11.5755)

        let configuration = PlaceLocationPickerCameraConfiguration.make(
            initialCoordinate: nil,
            fallbackCoordinate: fallback,
            radiusMeters: 150
        )

        #expect(
            configuration.initialFocus
                == .userLocation(
                    fallback: .init(
                        center: fallback,
                        latitudinalMeters: 2_000,
                        longitudinalMeters: 2_000
                    )
                )
        )

        let fallbackPosition = try #require(configuration.initialFocus.mapCameraPosition.fallbackPosition)
        let region = try #require(fallbackPosition.region)
        #expect(region.center.latitude == fallback.latitude)
        #expect(region.center.longitude == fallback.longitude)
        #expect(region.span.latitudeDelta > 0)
        #expect(region.span.longitudeDelta > 0)
    }

    @Test
    func make_withoutAnyKnownLocation_usesWorldFallback() {
        let configuration = PlaceLocationPickerCameraConfiguration.make(
            initialCoordinate: nil,
            fallbackCoordinate: nil,
            radiusMeters: 150
        )

        #expect(
            configuration.initialFocus
                == .userLocation(
                    fallback: .init(
                        center: LocationCoordinate(latitude: 20, longitude: 0),
                        latitudinalMeters: 20_000_000,
                        longitudinalMeters: 20_000_000
                    )
                )
        )
    }

    @Test
    func animationTarget_scalesFromRadius() {
        let coordinate = LocationCoordinate(latitude: 40.7128, longitude: -74.0060)

        let target = PlaceLocationPickerCameraConfiguration.animationTarget(
            for: coordinate,
            radiusMeters: 180
        )

        #expect(
            target
                == .init(coordinate: coordinate, distance: 1_440)
        )
    }

    @Test
    func animationTarget_enforcesMinimumDistance() {
        let target = PlaceLocationPickerCameraConfiguration.animationTarget(
            for: LocationCoordinate(latitude: 1, longitude: 2),
            radiusMeters: 25
        )

        #expect(target.distance == 500)
    }
}
