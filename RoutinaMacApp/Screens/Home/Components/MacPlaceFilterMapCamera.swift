import MapKit
import SwiftUI

struct MacPlaceFilterMapCamera {
    static func position(
        options: [MacPlaceFilterOption],
        selectedPlaceID: UUID?,
        currentLocation: LocationCoordinate?
    ) -> MapCameraPosition {
        guard !options.isEmpty else {
            let fallbackRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )
            return .region(fallbackRegion)
        }

        if let selectedPlaceID,
           let selectedOption = options.first(where: { $0.id == selectedPlaceID }) {
            return .region(region(focusingOn: selectedOption.place))
        }

        return .region(regionIncludingAllPlaces(options, currentLocation: currentLocation))
    }

    private static func region(focusingOn place: RoutinePlace) -> MKCoordinateRegion {
        let latitudeDelta = max(latitudeDelta(forMeters: place.radiusMeters * 4), 0.01)
        let longitudeDelta = max(
            longitudeDelta(forMeters: place.radiusMeters * 4, latitude: place.latitude),
            0.01
        )

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

    private static func regionIncludingAllPlaces(
        _ options: [MacPlaceFilterOption],
        currentLocation: LocationCoordinate?
    ) -> MKCoordinateRegion {
        var minLatitude = Double.greatestFiniteMagnitude
        var maxLatitude = -Double.greatestFiniteMagnitude
        var minLongitude = Double.greatestFiniteMagnitude
        var maxLongitude = -Double.greatestFiniteMagnitude

        for option in options {
            let latitudeInset = latitudeDelta(forMeters: option.place.radiusMeters * 1.8)
            let longitudeInset = longitudeDelta(
                forMeters: option.place.radiusMeters * 1.8,
                latitude: option.place.latitude
            )

            minLatitude = min(minLatitude, option.place.latitude - latitudeInset)
            maxLatitude = max(maxLatitude, option.place.latitude + latitudeInset)
            minLongitude = min(minLongitude, option.place.longitude - longitudeInset)
            maxLongitude = max(maxLongitude, option.place.longitude + longitudeInset)
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

        let latitudeDelta = max((maxLatitude - minLatitude) * 1.35, 0.02)
        let longitudeDelta = max((maxLongitude - minLongitude) * 1.35, 0.02)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
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
