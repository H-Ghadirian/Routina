import Foundation
import Testing
import UserNotifications
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@Suite(.serialized)
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
    func notificationPayload_doesNotUseTodoAvailabilityAsDueDate() {
        let reminderAt = makeDate("2026-04-25T14:30:00Z")
        let task = RoutineTask(
            name: "Buy phone",
            availabilityStartDate: makeDate("2026-04-20T00:00:00Z"),
            availabilityEndDate: makeDate("2026-04-30T00:00:00Z"),
            reminderAt: reminderAt,
            scheduleMode: .oneOff
        )

        let payload = NotificationCoordinator.notificationPayload(
            for: task,
            referenceDate: makeDate("2026-04-25T12:00:00Z")
        )

        #expect(payload.triggerDate == reminderAt)
        #expect(payload.dueDate == nil)
        #expect(payload.isCustomReminder)
    }

    @Test
    func notificationPayload_ignoresExactDateReminderForRoutine() {
        let reminderAt = makeDate("2026-04-25T14:30:00Z")
        let task = RoutineTask(
            name: "Stretch",
            reminderAt: reminderAt,
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 3),
            scheduleAnchor: makeDate("2026-04-20T10:00:00Z")
        )

        let payload = NotificationCoordinator.notificationPayload(
            for: task,
            referenceDate: makeDate("2026-04-25T12:00:00Z")
        )

        #expect(payload.triggerDate != reminderAt)
        #expect(!payload.isCustomReminder)
        #expect(!payload.usesExactTime)
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
    func notificationPayload_keepsRollingAdvancedHourlyOccurrences() {
        let calendar = makeTestCalendar()
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .hourly,
            interval: 6,
            startDate: makeDate("2026-07-21T07:00:00Z"),
            hourlyMode: .dailyWindow,
            dailyWindowStart: RoutineTimeOfDay(hour: 7, minute: 0),
            dailyWindowEnd: RoutineTimeOfDay(hour: 22, minute: 0),
            timeZoneIdentifier: calendar.timeZone.identifier,
            calendar: calendar
        )
        let task = RoutineTask(
            name: "Medicine",
            scheduleMode: .fixedInterval,
            recurrenceRule: .advanced(advanced),
            scheduleAnchor: advanced.startDate
        )

        let payload = NotificationCoordinator.notificationPayload(
            for: task,
            referenceDate: makeDate("2026-07-21T08:00:00Z"),
            calendar: calendar
        )

        #expect(payload.recurrenceOccurrenceDates.prefix(4) == [
            makeDate("2026-07-21T07:00:00Z"),
            makeDate("2026-07-21T13:00:00Z"),
            makeDate("2026-07-21T19:00:00Z"),
            makeDate("2026-07-22T07:00:00Z")
        ])
    }

    @Test
    func notificationPayload_forMissedExactTimeRoutineUsesNextOccurrence() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let referenceDate = makeDate("2026-04-24T10:00:00Z")
        let nextThursday = makeDate("2026-04-30T18:30:00Z")
        let task = RoutineTask(
            name: "Group session",
            scheduleMode: .fixedInterval,
            recurrenceRule: .weekly(
                on: 5,
                at: RoutineTimeOfDay(hour: 18, minute: 30)
            ),
            scheduleAnchor: makeDate("2026-04-19T10:00:00Z")
        )

        #expect(
            NotificationCoordinator.shouldScheduleNotification(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            )
        )

        let payload = NotificationCoordinator.notificationPayload(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let trigger = NotificationCoordinator.createNotificationTrigger(for: payload, now: referenceDate)
        let expectedComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextThursday)

        #expect(payload.triggerDate == nextThursday)
        #expect(payload.dueDate == nextThursday)
        #expect(trigger.dateComponents.year == expectedComponents.year)
        #expect(trigger.dateComponents.month == expectedComponents.month)
        #expect(trigger.dateComponents.day == expectedComponents.day)
        #expect(trigger.dateComponents.hour == expectedComponents.hour)
        #expect(trigger.dateComponents.minute == expectedComponents.minute)
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

    @Test
    func shouldScheduleNotification_returnsTrueForFutureEventReminder() {
        let reminderAt = makeDate("2026-04-25T12:30:00Z")
        let event = RoutineEvent(
            title: "Conference",
            isAllDay: false,
            startedAt: makeDate("2026-04-25T13:00:00Z"),
            endedAt: makeDate("2026-04-25T14:00:00Z"),
            reminderAt: reminderAt
        )

        #expect(
            NotificationCoordinator.shouldScheduleNotification(
                for: event,
                referenceDate: makeDate("2026-04-25T12:00:00Z")
            )
        )
    }

    @Test
    func shouldScheduleNotification_returnsFalseForPastEventReminder() {
        let event = RoutineEvent(
            title: "Conference",
            isAllDay: false,
            startedAt: makeDate("2026-04-25T13:00:00Z"),
            endedAt: makeDate("2026-04-25T14:00:00Z"),
            reminderAt: makeDate("2026-04-25T11:30:00Z")
        )

        #expect(
            !NotificationCoordinator.shouldScheduleNotification(
                for: event,
                referenceDate: makeDate("2026-04-25T12:00:00Z")
            )
        )
    }

    @Test
    func notificationPayload_forEventUsesReminderAndDeepLink() {
        let eventID = UUID()
        let reminderAt = makeDate("2026-04-25T12:30:00Z")
        let event = RoutineEvent(
            id: eventID,
            title: "Conference",
            emoji: "🎤",
            isAllDay: false,
            startedAt: makeDate("2026-04-25T13:00:00Z"),
            endedAt: makeDate("2026-04-25T14:00:00Z"),
            reminderAt: reminderAt
        )

        let payload = NotificationCoordinator.notificationPayload(
            for: event,
            referenceDate: makeDate("2026-04-25T12:00:00Z")
        )
        let content = NotificationCoordinator.createNotificationContent(for: payload)

        #expect(payload.identifier == NotificationCoordinator.eventNotificationIdentifier(for: eventID))
        #expect(payload.kind == .event)
        #expect(payload.triggerDate == reminderAt)
        #expect(payload.dueDate == event.startedAt)
        #expect(payload.deepLink == .event(eventID))
        #expect(content.categoryIdentifier.isEmpty)
        #expect(RoutinaDeepLink(notificationUserInfo: content.userInfo) == .event(eventID))
        if #available(iOS 15.0, macOS 12.0, *) {
            #expect(content.interruptionLevel == .timeSensitive)
            #expect(content.relevanceScore == 1.0)
        }
    }

    @Test
    func notificationTrigger_movesPastNonExactTriggerToNextReminderTime() {
        let now = makeDate("2026-04-25T12:00:00Z")
        let payload = NotificationPayload(
            identifier: UUID().uuidString,
            name: "Exercise",
            emoji: nil,
            interval: 1,
            lastDone: nil,
            dueDate: makeDate("2026-04-24T12:00:00Z"),
            triggerDate: makeDate("2026-04-24T20:00:00Z"),
            isOneOffTask: false,
            isCustomReminder: false,
            isArchived: false,
            usesExactTime: false,
            isChecklistDriven: false,
            isChecklistCompletionRoutine: false,
            nextDueChecklistItemTitle: nil
        )

        let trigger = NotificationCoordinator.createNotificationTrigger(for: payload, now: now)
        let expectedDate = NotificationPreferences.nextReminderDate(after: now)
        let expectedComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: expectedDate)

        #expect(trigger.dateComponents.year == expectedComponents.year)
        #expect(trigger.dateComponents.month == expectedComponents.month)
        #expect(trigger.dateComponents.day == expectedComponents.day)
        #expect(trigger.dateComponents.hour == expectedComponents.hour)
        #expect(trigger.dateComponents.minute == expectedComponents.minute)
    }

    @Test
    @MainActor
    func handleResponse_defaultNotificationTapQueuesTaskDeepLink() async {
        let taskID = UUID()
        _ = RoutinaDeepLinkDispatcher.consumePendingDeepLink()

        await NotificationCoordinator.handleResponse(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            requestIdentifier: taskID.uuidString
        )

        #expect(RoutinaDeepLinkDispatcher.consumePendingDeepLink() == .task(taskID))
    }
}
