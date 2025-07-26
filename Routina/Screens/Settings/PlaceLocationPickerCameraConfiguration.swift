import Foundation
import MapKit
import SwiftUI

struct PlaceLocationPickerCameraConfiguration: Equatable, Sendable {
    struct AnimationTarget: Equatable, Sendable {
        let coordinate: LocationCoordinate
        let distance: Double
    }

    struct FallbackRegion: Equatable, Sendable {
        let center: LocationCoordinate
        let latitudinalMeters: Double
        let longitudinalMeters: Double
    }

    enum InitialFocus: Equatable, Sendable {
        case selected(coordinate: LocationCoordinate, distance: Double)
        case userLocation(fallback: FallbackRegion)
    }

    let initialFocus: InitialFocus

    static func make(
        initialCoordinate: LocationCoordinate?,
        fallbackCoordinate: LocationCoordinate?,
        radiusMeters: Double
    ) -> Self {
        if let initialCoordinate {
            return Self(
                initialFocus: .selected(
                    coordinate: initialCoordinate,
                    distance: distance(for: radiusMeters)
                )
            )
        }

        return Self(
            initialFocus: .userLocation(
                fallback: fallbackRegion(for: fallbackCoordinate)
            )
        )
    }

    static func animationTarget(
        for coordinate: LocationCoordinate,
        radiusMeters: Double
    ) -> AnimationTarget {
        AnimationTarget(
            coordinate: coordinate,
            distance: distance(for: radiusMeters)
        )
    }

    static func distance(for radiusMeters: Double) -> Double {
        max(radiusMeters * 8, 500)
    }

    static func fallbackRegion(for fallbackCoordinate: LocationCoordinate?) -> FallbackRegion {
        if let fallbackCoordinate {
            return FallbackRegion(
                center: fallbackCoordinate,
                latitudinalMeters: 2_000,
                longitudinalMeters: 2_000
            )
        }

        return FallbackRegion(
            center: LocationCoordinate(latitude: 20, longitude: 0),
            latitudinalMeters: 20_000_000,
            longitudinalMeters: 20_000_000
        )
    }
}

extension PlaceLocationPickerCameraConfiguration.InitialFocus {
    var mapCameraPosition: MapCameraPosition {
        switch self {
        case let .selected(coordinate, distance):
            return .camera(
                MapCamera(
                    centerCoordinate: coordinate.clLocationCoordinate2D,
                    distance: distance
                )
            )

        case let .userLocation(fallback):
            return .userLocation(
                fallback: .region(
                    MKCoordinateRegion(
                        center: fallback.center.clLocationCoordinate2D,
                        latitudinalMeters: fallback.latitudinalMeters,
                        longitudinalMeters: fallback.longitudinalMeters
                    )
                )
            )
        }
    }
}

extension LocationCoordinate {
    var clLocationCoordinate2D: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
