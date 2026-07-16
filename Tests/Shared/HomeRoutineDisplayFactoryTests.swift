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
    func canceledCalendarRoutineOccurrenceMarksDisplayCanceledToday() {
        let now = makeDate("2026-06-22T10:00:00Z")
        let task = RoutineTask(
            name: "Class",
            recurrenceRule: .weekly(on: 2, at: RoutineTimeOfDay(hour: 9, minute: 0))
        )
        let canceledAt = makeDate("2026-06-22T09:00:00Z")

        let display = makeDisplay(
            task: task,
            now: now,
            places: [],
            coordinate: LocationCoordinate(latitude: 52.5200, longitude: 13.4050),
            doneStats: HomeDoneStats(
                canceledTotalCount: 1,
                canceledCountsByTaskID: [task.id: 1],
                canceledDatesByTaskID: [task.id: [canceledAt]]
            )
        )

        #expect(display.isCanceledToday)
    }

    @Test
    func missedExactTimedDisplaySkipsAcknowledgedEarlierMissedOccurrence() {
        let firstMissed = makeDate("2026-05-07T18:30:00Z")
        let task = RoutineTask(
            name: "Class",
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            scheduleAnchor: makeDate("2026-05-01T10:00:00Z")
        )

        let display = makeDisplay(
            task: task,
            now: makeDate("2026-05-15T10:00:00Z"),
            places: [],
            coordinate: LocationCoordinate(latitude: 52.5200, longitude: 13.4050),
            doneStats: HomeDoneStats(missedDatesByTaskID: [task.id: [firstMissed]])
        )

        #expect(display.hasMissedExactTimedOccurrence)
        #expect(display.dueDate == makeDate("2026-05-21T18:30:00Z"))
    }

    @Test
    func oneOffAvailabilityWindowWithoutDeadlineHasNoHomeDueDate() {
        let task = RoutineTask(
            name: "Watch WWDC 26 Videos",
            availabilityStartDate: makeDate("2026-06-08T00:00:00Z"),
            availabilityEndDate: makeDate("2027-06-12T00:00:00Z"),
            scheduleMode: .oneOff
        )

        let display = makeDisplay(
            task: task,
            now: makeDate("2026-06-27T10:00:00Z"),
            places: [],
            coordinate: LocationCoordinate(latitude: 52.5200, longitude: 13.4050)
        )

        #expect(display.dueDate == nil)
        #expect(display.daysUntilDue == Int.max)
    }

    @Test
    func canceledWeeklyTimeWindowOccurrenceMarksDisplayCanceledToday() {
        let now = makeDate("2026-06-22T10:00:00Z")
        let window = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 17, minute: 0),
            end: RoutineTimeOfDay(hour: 18, minute: 0)
        )
        let task = RoutineTask(
            name: "Therapy",
            recurrenceRule: .weekly(on: 2, timeRange: window)
        )
        let canceledAt = makeDate("2026-06-22T17:30:00Z")

        let display = makeDisplay(
            task: task,
            now: now,
            places: [],
            coordinate: LocationCoordinate(latitude: 52.5200, longitude: 13.4050),
            doneStats: HomeDoneStats(
                canceledTotalCount: 1,
                canceledCountsByTaskID: [task.id: 1],
                canceledDatesByTaskID: [task.id: [canceledAt]]
            )
        )

        #expect(display.isCanceledToday)
    }

    @Test
    func overnightWindowProbableTimeCompletionMarksCurrentOccurrenceDoneBeforeNextStart() {
        let now = makeDate("2026-07-12T12:00:00Z")
        let window = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 21, minute: 0),
            end: RoutineTimeOfDay(hour: 3, minute: 0)
        )
        let task = RoutineTask(
            name: "Brush teeth",
            scheduleMode: .record,
            recurrenceRule: .daily(in: window),
            createdAt: makeDate("2026-07-01T00:00:00Z"),
            autoAssumeDailyDone: true,
            autoAssumeDoneTimeOfDay: RoutineTimeOfDay(hour: 12, minute: 0)
        )
        let probableCompletion = makeDate("2026-07-11T12:00:00Z")

        let display = makeDisplay(
            task: task,
            now: now,
            places: [],
            coordinate: LocationCoordinate(latitude: 52.5200, longitude: 13.4050),
            doneStats: HomeDoneStats(
                totalCount: 1,
                countsByTaskID: [task.id: 1],
                completedDatesByTaskID: [task.id: [probableCompletion]]
            )
        )

        #expect(display.isDoneToday)
        #expect(!display.isAssumedDoneToday)
    }

    @Test
    func assumedChecklistTrackingHidesPendingChecklistPrompt() {
        let now = makeDate("2026-06-09T08:00:00Z")
        let task = RoutineTask(
            name: "Meals",
            checklistItems: [
                RoutineChecklistItem(title: "Breakfast", intervalDays: 1, createdAt: now),
                RoutineChecklistItem(title: "Lunch", intervalDays: 1, createdAt: now)
            ],
            scheduleMode: .recordChecklist,
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
    func overnightAutoAssumedTrackingUsesCurrentOccurrenceDayInHomeDisplay() {
        let now = makeDate("2026-06-10T01:00:00Z")
        let task = RoutineTask(
            name: "Brush teeth",
            scheduleMode: .record,
            recurrenceRule: .daily(in: RoutineTimeRange(
                start: RoutineTimeOfDay(hour: 21, minute: 0),
                end: RoutineTimeOfDay(hour: 3, minute: 0)
            )),
            scheduleAnchor: makeDate("2026-06-09T00:00:00Z"),
            createdAt: makeDate("2026-06-09T00:00:00Z"),
            autoAssumeDailyDone: true
        )

        let display = makeDisplay(
            task: task,
            now: now,
            places: [],
            coordinate: LocationCoordinate(latitude: 52.5200, longitude: 13.4050)
        )

        #expect(display.isDoneToday)
        #expect(display.isAssumedDoneToday)
    }

    @Test
    func overnightAutoAssumedTrackingStaysAssumedAfterWindowBeforeNextStart() {
        let now = makeDate("2026-06-10T12:00:00Z")
        let task = RoutineTask(
            name: "Brush teeth",
            scheduleMode: .record,
            recurrenceRule: .daily(in: RoutineTimeRange(
                start: RoutineTimeOfDay(hour: 21, minute: 0),
                end: RoutineTimeOfDay(hour: 3, minute: 0)
            )),
            scheduleAnchor: makeDate("2026-06-09T00:00:00Z"),
            createdAt: makeDate("2026-06-09T00:00:00Z"),
            autoAssumeDailyDone: true
        )

        let display = makeDisplay(
            task: task,
            now: now,
            places: [],
            coordinate: LocationCoordinate(latitude: 52.5200, longitude: 13.4050)
        )

        #expect(display.isDoneToday)
        #expect(display.isAssumedDoneToday)
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
            scheduleMode: .recordChecklist,
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

    @Test
    func optionalChecklistBlockerCarriesToHomeDisplay() {
        let task = RoutineTask(
            name: "Pack bag",
            checklistItems: [
                RoutineChecklistItem(title: "Laptop", intervalDays: 1),
                RoutineChecklistItem(title: "Charger", intervalDays: 1)
            ],
            scheduleMode: .fixedInterval
        )

        let display = makeDisplay(
            task: task,
            places: [],
            coordinate: LocationCoordinate(latitude: 52.5200, longitude: 13.4050)
        )

        #expect(display.blocksManualCompletionForIncompleteChecklist)
    }

    @Test
    func creationDayAllDayAutoAssumedTrackingPresentsAsAssumedInHome() {
        let now = makeDate("2026-06-09T08:00:00Z")
        let task = RoutineTask(
            name: "Hydrate",
            scheduleMode: .record,
            recurrenceRule: .interval(days: 1),
            scheduleAnchor: makeDate("2026-06-09T00:00:00Z"),
            createdAt: makeDate("2026-06-09T07:30:00Z"),
            autoAssumeDailyDone: true
        )

        let display = makeDisplay(
            task: task,
            now: now,
            places: [],
            coordinate: LocationCoordinate(latitude: 52.5200, longitude: 13.4050)
        )

        #expect(display.isDoneToday)
        #expect(display.isAssumedDoneToday)
    }

    private func makeDisplay(
        task: RoutineTask,
        now: Date = makeDate("2026-06-09T08:00:00Z"),
        places: [RoutinePlace],
        coordinate: LocationCoordinate,
        doneStats: HomeDoneStats = HomeDoneStats()
    ) -> HomeRoutineDisplayCore {
        HomeRoutineDisplayFactory(
            now: now,
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
