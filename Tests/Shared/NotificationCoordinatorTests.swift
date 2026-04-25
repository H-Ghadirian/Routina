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

    @Test
    func shouldScheduleNotification_returnsTrueForFutureOneOffDeadline() {
        let deadline = makeDate("2026-04-25T14:30:00Z")
        let task = RoutineTask(
            name: "Send invoice",
            deadline: deadline,
            scheduleMode: .oneOff
        )

        #expect(
            NotificationCoordinator.shouldScheduleNotification(
                for: task,
                referenceDate: makeDate("2026-04-25T12:00:00Z")
            )
        )
    }

    @Test
    func shouldScheduleNotification_returnsFalseForPastOneOffDeadline() {
        let deadline = makeDate("2026-04-25T10:30:00Z")
        let task = RoutineTask(
            name: "Send invoice",
            deadline: deadline,
            scheduleMode: .oneOff
        )

        #expect(
            !NotificationCoordinator.shouldScheduleNotification(
                for: task,
                referenceDate: makeDate("2026-04-25T12:00:00Z")
            )
        )
    }

    @Test
    func notificationPayload_usesOneOffDeadlineAsExactTrigger() {
        let deadline = makeDate("2026-04-25T14:30:00Z")
        let task = RoutineTask(
            name: "Send invoice",
            deadline: deadline,
            scheduleMode: .oneOff
        )

        let payload = NotificationCoordinator.notificationPayload(
            for: task,
            referenceDate: makeDate("2026-04-25T12:00:00Z")
        )

        #expect(payload.triggerDate == deadline)
        #expect(payload.dueDate == deadline)
        #expect(payload.isOneOffTask)
        #expect(payload.usesExactTime)
    }

    @Test
    func notificationPayload_usesWeeklyExactTimeAsTrigger() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let mondayAtOne = makeDate("2026-04-27T13:00:00Z")
        let task = RoutineTask(
            name: "Planning",
            scheduleMode: .fixedInterval,
            recurrenceRule: .weekly(
                on: 2,
                at: RoutineTimeOfDay(hour: 13, minute: 0)
            ),
            scheduleAnchor: makeDate("2026-04-25T09:00:00Z")
        )

        let payload = NotificationCoordinator.notificationPayload(
            for: task,
            referenceDate: makeDate("2026-04-25T12:00:00Z"),
            calendar: calendar
        )

        #expect(payload.triggerDate == mondayAtOne)
        #expect(payload.dueDate == mondayAtOne)
        #expect(!payload.isOneOffTask)
        #expect(payload.usesExactTime)
    }

    @Test
    func notificationContent_marksWeeklyExactTimeRoutineTimeSensitive() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let task = RoutineTask(
            name: "Planning",
            scheduleMode: .fixedInterval,
            recurrenceRule: .weekly(
                on: 2,
                at: RoutineTimeOfDay(hour: 13, minute: 0)
            ),
            scheduleAnchor: makeDate("2026-04-25T09:00:00Z")
        )

        let payload = NotificationCoordinator.notificationPayload(
            for: task,
            referenceDate: makeDate("2026-04-25T12:00:00Z"),
            calendar: calendar
        )
        let content = NotificationCoordinator.createNotificationContent(for: payload)

        #expect(content.sound != nil)
        #expect(content.subtitle.isEmpty == false)
        if #available(iOS 15.0, macOS 12.0, *) {
            #expect(content.interruptionLevel == .timeSensitive)
            #expect(content.relevanceScore == 1.0)
        }
    }
}
