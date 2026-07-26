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

struct MacPlaceFilterOptionFactory {
    static func options(
        places: [RoutinePlace],
        displays: [HomeFeature.RoutineDisplay],
        taskListMode: HomeFeature.TaskListMode,
        locationSnapshot: LocationSnapshot
    ) -> [MacPlaceFilterOption] {
        let linkedRoutineCounts = HomeFeature.placeLinkedCounts(
            from: displays,
            taskListMode: taskListMode
        )

        return places.map { place in
            let linkedRoutineCount = linkedRoutineCounts[place.id, default: 0]

            return MacPlaceFilterOption(
                place: place,
                linkedRoutineCount: linkedRoutineCount,
                linkedItemText: countText(linkedRoutineCount, taskListMode: taskListMode),
                status: status(for: place, locationSnapshot: locationSnapshot)
            )
        }
    }

    private static func countText(
        _ count: Int,
        taskListMode: HomeFeature.TaskListMode
    ) -> String {
        switch taskListMode {
        case .all:
            return count == 1 ? "1 task" : "\(count) tasks"
        case .routines:
            return count == 1 ? "1 routine" : "\(count) routines"
        case .todos:
            return count == 1 ? "1 todo" : "\(count) todos"
        }
    }

    private static func status(
        for place: RoutinePlace,
        locationSnapshot: LocationSnapshot
    ) -> MacPlaceFilterOption.Status {
        guard
            let coordinate = locationSnapshot.coordinate,
            locationSnapshot.authorizationStatus.isAuthorized
        else {
            return .unknown
        }

        if place.contains(coordinate) {
            return .here
        }

        return .away(distanceMeters: place.distance(to: coordinate))
    }
}
