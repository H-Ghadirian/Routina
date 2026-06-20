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

    @Test
    func completedChecklistRoutineUsesCompletedLogOverStalePartialProgress() {
        let now = makeDate("2026-06-09T08:00:00Z")
        let firstID = UUID()
        let secondID = UUID()
        let thirdID = UUID()
        let task = RoutineTask(
            name: "Check list",
            checklistItems: [
                RoutineChecklistItem(id: firstID, title: "One", intervalDays: 1, createdAt: now),
                RoutineChecklistItem(id: secondID, title: "Two", intervalDays: 1, createdAt: now),
                RoutineChecklistItem(id: thirdID, title: "Three", intervalDays: 1, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 9, minute: 0)),
            scheduleAnchor: now
        )
        task.completedChecklistItemIDs = [firstID, secondID]
        task.completedChecklistProgressStartedAt = now

        let display = makeDisplay(
            task: task,
            places: [],
            coordinate: LocationCoordinate(latitude: 52.5200, longitude: 13.4050),
            doneStats: HomeDoneStats(
                totalCount: 1,
                countsByTaskID: [task.id: 1],
                completedDatesByTaskID: [task.id: [now]]
            )
        )

        #expect(display.isDoneToday)
        #expect(display.completedChecklistItemCount == 0)
        #expect(display.nextPendingChecklistItemTitle == nil)
    }

    @Test
    func assumedChecklistRoutineHidesPendingChecklistPrompt() {
        let now = makeDate("2026-06-09T08:00:00Z")
        let task = RoutineTask(
            name: "Meals",
            checklistItems: [
                RoutineChecklistItem(title: "Breakfast", intervalDays: 1, createdAt: now),
                RoutineChecklistItem(title: "Lunch", intervalDays: 1, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 7, minute: 0)),
            scheduleAnchor: now,
            createdAt: makeDate("2026-06-08T08:00:00Z"),
            autoAssumeDailyDone: true
        )

        let display = makeDisplay(
            task: task,
            places: [],
            coordinate: LocationCoordinate(latitude: 52.5200, longitude: 13.4050)
        )

        #expect(display.isDoneToday)
        #expect(display.isAssumedDoneToday)
        #expect(display.completedChecklistItemCount == 0)
        #expect(display.nextPendingChecklistItemTitle == nil)
    }

    @Test
    func partialChecklistProgressSuppressesAssumedHomeDisplay() {
        let now = makeDate("2026-06-09T08:00:00Z")
        let firstID = UUID()
        let task = RoutineTask(
            name: "Meals",
            checklistItems: [
                RoutineChecklistItem(id: firstID, title: "Breakfast", intervalDays: 1, createdAt: now),
                RoutineChecklistItem(title: "Lunch", intervalDays: 1, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 7, minute: 0)),
            scheduleAnchor: now,
            createdAt: makeDate("2026-06-08T08:00:00Z"),
            autoAssumeDailyDone: true
        )
        task.completedChecklistItemIDs = [firstID]
        task.completedChecklistProgressStartedAt = now

        let display = makeDisplay(
            task: task,
            places: [],
            coordinate: LocationCoordinate(latitude: 52.5200, longitude: 13.4050)
        )

        #expect(!display.isDoneToday)
        #expect(!display.isAssumedDoneToday)
        #expect(display.completedChecklistItemCount == 1)
        #expect(display.nextPendingChecklistItemTitle == "Lunch")
    }

    private func makeDisplay(
        task: RoutineTask,
        places: [RoutinePlace],
        coordinate: LocationCoordinate,
        doneStats: HomeDoneStats = HomeDoneStats()
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
            doneStats: doneStats
        )
    }
}
