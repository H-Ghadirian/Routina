import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct NotificationCoordinatorTests {
    @Test
    func shouldScheduleNotification_returnsFalseForSoftRoutine() {
        let task = RoutineTask(
            name: "Travel",
            scheduleMode: .softInterval,
            recurrenceRule: .interval(days: 180),
            scheduleAnchor: makeDate("2026-01-01T10:00:00Z")
        )

        #expect(
            !NotificationCoordinator.shouldScheduleNotification(
                for: task,
                referenceDate: makeDate("2026-04-23T10:00:00Z")
            )
        )
    }

    @Test
    func shouldScheduleNotification_returnsFalseForOngoingRoutine() {
        let task = RoutineTask(
            name: "Travel",
            scheduleMode: .softInterval,
            recurrenceRule: .interval(days: 180),
            scheduleAnchor: makeDate("2026-01-01T10:00:00Z")
        )

        task.startOngoing(at: makeDate("2026-04-10T08:00:00Z"))

        #expect(
            !NotificationCoordinator.shouldScheduleNotification(
                for: task,
                referenceDate: makeDate("2026-04-23T10:00:00Z")
            )
        )
    }

    @Test
    func shouldScheduleNotification_returnsTrueForActiveRecurringRoutine() {
        let task = RoutineTask(
            name: "Stretch",
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 3),
            scheduleAnchor: makeDate("2026-04-20T10:00:00Z")
        )

        #expect(
            NotificationCoordinator.shouldScheduleNotification(
                for: task,
                referenceDate: makeDate("2026-04-23T10:00:00Z")
            )
        )
    }
}
