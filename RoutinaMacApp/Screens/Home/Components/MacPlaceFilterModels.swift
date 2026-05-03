import MapKit

struct MacPlaceFilterOption: Equatable, Identifiable {
    enum Status: Equatable {
        case here
        case away(distanceMeters: Double)
        case unknown
    }

    let place: RoutinePlace
    let linkedRoutineCount: Int
    let linkedItemText: String
    let status: Status

    var id: UUID { place.id }
    var coordinate: CLLocationCoordinate2D { placeCoordinate.clLocationCoordinate2D }

    var placeCoordinate: LocationCoordinate {
        LocationCoordinate(latitude: place.latitude, longitude: place.longitude)
    }

    var subtitle: String {
        "\(linkedItemText) • \(Int(place.radiusMeters)) m radius"
    }
}
