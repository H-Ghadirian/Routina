import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct HomeRoutineDisplayFactoryTests {
    @Test
    func locationAvailabilityUsesAnySelectedPlace() {
        let homeID = UUID()
        let gymID = UUID()
        let home = RoutinePlace(
            id: homeID,
            name: "Home",
            latitude: 52.5200,
            longitude: 13.4050,
            radiusMeters: 100
        )
        let gym = RoutinePlace(
            id: gymID,
            name: "Gym",
            latitude: 48.1374,
            longitude: 11.5755,
            radiusMeters: 100
        )
        let task = RoutineTask(name: "Stretch", placeIDs: [homeID, gymID])

        let display = makeDisplay(
            task: task,
            places: [home, gym],
            coordinate: LocationCoordinate(latitude: 48.1374, longitude: 11.5755)
        )

        #expect(display.placeName == "Home + 1")
        #expect(display.locationAvailability == .available(placeName: "Gym"))
    }

    @Test
    func locationAvailabilityUsesAnySavedPlaceWithSelectedKind() {
        let aldiID = UUID()
        let reweID = UUID()
        let aldi = RoutinePlace(
            id: aldiID,
            name: "Aldi",
            latitude: 52.5200,
            longitude: 13.4050,
            radiusMeters: 100,
            kind: "Supermarket"
        )
        let rewe = RoutinePlace(
            id: reweID,
            name: "Rewe",
            latitude: 48.1374,
            longitude: 11.5755,
            radiusMeters: 100,
            kind: "supermarket"
        )
        let task = RoutineTask(name: "Groceries", placeID: aldiID)

        let display = makeDisplay(
            task: task,
            places: [aldi, rewe],
            coordinate: LocationCoordinate(latitude: 48.1374, longitude: 11.5755)
        )

        #expect(display.placeName == "Aldi")
        #expect(display.locationAvailability == .available(placeName: "Rewe"))
    }

    private func makeDisplay(
        task: RoutineTask,
        places: [RoutinePlace],
        coordinate: LocationCoordinate
    ) -> HomeRoutineDisplayCore {
        HomeRoutineDisplayFactory(
            now: makeDate("2026-06-09T08:00:00Z"),
            calendar: makeTestCalendar()
        )
        .makeCore(
            for: task,
            placesByID: Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) }),
            goalsByID: [:],
            locationSnapshot: LocationSnapshot(
                authorizationStatus: .authorizedWhenInUse,
                coordinate: coordinate,
                horizontalAccuracy: 25,
                timestamp: makeDate("2026-06-09T08:00:00Z")
            ),
            doneStats: HomeDoneStats()
        )
    }
}
