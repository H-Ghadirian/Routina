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
    func scheduledNotificationSummaries_useSystemTriggerDatesAndSortChronologically() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let earlierDate = makeDate("2099-01-02T08:30:00Z")
        let laterDate = makeDate("2099-02-03T09:45:00Z")

        let earlierContent = UNMutableNotificationContent()
        earlierContent.title = " Earlier reminder "
        earlierContent.subtitle = "Due today"
        var earlierComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: earlierDate
        )
        earlierComponents.calendar = calendar
        earlierComponents.timeZone = calendar.timeZone
        let earlierRequest = UNNotificationRequest(
            identifier: "earlier",
            content: earlierContent,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: earlierComponents,
                repeats: false
            )
        )

        let laterContent = UNMutableNotificationContent()
        laterContent.title = "Later reminder"
        laterContent.body = "Open Routina to review it."
        var laterComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: laterDate
        )
        laterComponents.calendar = calendar
        laterComponents.timeZone = calendar.timeZone
        let laterRequest = UNNotificationRequest(
            identifier: "later",
            content: laterContent,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: laterComponents,
                repeats: false
            )
        )

        let undatedContent = UNMutableNotificationContent()
        undatedContent.title = "Undated reminder"
        let undatedRequest = UNNotificationRequest(
            identifier: "undated",
            content: undatedContent,
            trigger: nil
        )

        let summaries = NotificationClient.scheduledNotificationSummaries(
            from: [undatedRequest, laterRequest, earlierRequest]
        )

        #expect(summaries.map(\.identifier) == ["earlier", "later", "undated"])
        #expect(summaries[0].title == "Earlier reminder")
        #expect(summaries[0].scheduledAt == earlierDate)
        #expect(summaries[0].detailText == "Due today")
        #expect(summaries[1].scheduledAt == laterDate)
        #expect(summaries[1].detailText == "Open Routina to review it.")
        #expect(summaries[2].scheduledAt == nil)
    }

    @Test
    func scheduledNotificationSummaries_groupOccurrencesUsingStableRequestMetadata() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let taskID = UUID()
        let firstOriginalDate = makeDate("2099-03-04T08:00:00Z")
        let secondOriginalDate = makeDate("2099-03-05T08:00:00Z")
        let pausedDate = makeDate("2099-03-04T09:00:00Z")
        let payload = NotificationPayload(
            identifier: taskID.uuidString,
            name: "Water plants",
            emoji: "🪴",
            interval: 1,
            lastDone: nil,
            dueDate: firstOriginalDate,
            triggerDate: firstOriginalDate,
            isOneOffTask: false,
            isCustomReminder: false,
            isArchived: false,
            usesExactTime: true,
            isChecklistDriven: false,
            isChecklistCompletionRoutine: false,
            nextDueChecklistItemTitle: nil
        )

        func request(identifier: String, originalDate: Date, scheduledDate: Date) -> UNNotificationRequest {
            var components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: scheduledDate
            )
            components.calendar = calendar
            components.timeZone = calendar.timeZone
            return UNNotificationRequest(
                identifier: identifier,
                content: NotificationCoordinator.createNotificationContent(
                    for: payload,
                    originalScheduledAt: originalDate
                ),
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
        }

        let summaries = NotificationClient.scheduledNotificationSummaries(
            from: [
                request(
                    identifier: "\(taskID.uuidString).occurrence.1",
                    originalDate: secondOriginalDate,
                    scheduledDate: secondOriginalDate
                ),
                request(
                    identifier: "\(taskID.uuidString).occurrence.0",
                    originalDate: firstOriginalDate,
                    scheduledDate: pausedDate
                )
            ]
        )
        let groups = ScheduledNotificationGroup.groups(from: summaries)

        #expect(summaries.map(\.sourceIdentifier) == [taskID.uuidString, taskID.uuidString])
        #expect(summaries.first?.sourceKind == .task)
        #expect(summaries.first?.sourceTitle == "🪴 Water plants")
        #expect(summaries.first?.originalScheduledAt == firstOriginalDate)
        #expect(summaries.first?.scheduledAt == pausedDate)
        #expect(summaries.first?.isPaused == true)
        #expect(groups.count == 1)
        #expect(groups.first?.title == "🪴 Water plants")
        #expect(groups.first?.notifications.count == 2)
    }

    @Test
    func occurrenceOverrideStore_keepsSkipAndPauseAcrossSchedulerRebuilds() async {
        let suiteName = "NotificationSchedulingOverrideStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let overrideStore = NotificationSchedulingOverrideStore(
            defaults: defaults,
            storageKey: "test-overrides"
        )
        let sourceIdentifier = UUID().uuidString
        let now = makeDate("2099-04-01T07:00:00Z")
        let originalDate = makeDate("2099-04-01T08:00:45Z")
        let normalizedOriginalDate = makeDate("2099-04-01T08:00:00Z")

        await overrideStore.skip(
            sourceIdentifier: sourceIdentifier,
            originalScheduledAt: originalDate,
            now: now
        )

        let skippedDate = await NotificationCoordinator.effectiveScheduledDate(
            sourceIdentifier: sourceIdentifier,
            originalScheduledAt: normalizedOriginalDate,
            now: now,
            overrideStore: overrideStore
        )
        #expect(skippedDate == nil)

        let requestedPauseDate = makeDate("2099-04-01T09:30:45Z")
        let normalizedPauseDate = makeDate("2099-04-01T09:30:00Z")
        await overrideStore.pause(
            sourceIdentifier: sourceIdentifier,
            originalScheduledAt: originalDate,
            until: requestedPauseDate,
            now: now
        )

        let pausedDate = await NotificationCoordinator.effectiveScheduledDate(
            sourceIdentifier: sourceIdentifier,
            originalScheduledAt: normalizedOriginalDate,
            now: now,
            overrideStore: overrideStore
        )
        #expect(pausedDate == normalizedPauseDate)

        let unrelatedDate = await NotificationCoordinator.effectiveScheduledDate(
            sourceIdentifier: sourceIdentifier,
            originalScheduledAt: makeDate("2099-04-02T08:00:00Z"),
            now: now,
            overrideStore: overrideStore
        )
        #expect(unrelatedDate == makeDate("2099-04-02T08:00:00Z"))
    }

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
    func shouldScheduleNotification_returnsFalseForAutoAssumedRoutine() {
        let timeRange = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 21, minute: 0),
            end: RoutineTimeOfDay(hour: 3, minute: 0)
        )
        let task = RoutineTask(
            name: "Brush teeth",
            scheduleMode: .softInterval,
            recurrenceRule: .daily(in: timeRange),
            createdAt: makeDate("2026-08-01T00:00:00Z"),
            autoAssumeDailyDone: true
        )

        #expect(RoutineAssumedCompletion.isEligible(task))
        #expect(
            !NotificationCoordinator.shouldScheduleNotification(
                for: task,
                referenceDate: makeDate("2026-08-09T13:14:00Z"),
                calendar: makeTestCalendar()
            )
        )
    }

    @Test
    func shouldScheduleNotification_returnsFalseForAutoAssumedTaskWithDirectReminder() {
        let timeRange = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 12, minute: 0),
            end: RoutineTimeOfDay(hour: 15, minute: 0)
        )
        let task = RoutineTask(
            name: "Visit museum",
            availabilityStartDate: makeDate("2026-08-10T00:00:00Z"),
            reminderAt: makeDate("2026-08-10T11:30:00Z"),
            scheduleMode: .oneOff,
            recurrenceRule: .interval(days: 1, timeRange: timeRange),
            recurrenceTimeRangeRole: .scheduledBlock,
            autoAssumeDailyDone: true
        )

        #expect(RoutineAssumedCompletion.isEligible(task))
        #expect(
            !NotificationCoordinator.shouldScheduleNotification(
                for: task,
                referenceDate: makeDate("2026-08-10T09:00:00Z"),
                calendar: makeTestCalendar()
            )
        )
    }

    @Test
    func shouldScheduleNotification_returnsFalseForCadenceFreeRoutine() {
        let task = RoutineTask(
            name: "Go to library",
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 1),
            cadenceEnabled: false
        )

        #expect(
            !NotificationCoordinator.shouldScheduleNotification(
                for: task,
                referenceDate: makeDate("2026-07-24T10:00:00Z")
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
    func notificationPayload_usesAvailabilityStartForStructuredOccurrences() {
        var calendar = makeTestCalendar()
        calendar.firstWeekday = 2
        let window = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 18, minute: 0),
            end: RoutineTimeOfDay(hour: 21, minute: 0)
        )
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .weekly,
            interval: 2,
            startDate: makeDate("2026-07-20T09:00:00Z"),
            weekdays: [2, 4],
            timesOfDay: [RoutineTimeOfDay(hour: 9, minute: 0)],
            timeZoneIdentifier: calendar.timeZone.identifier,
            calendar: calendar
        )
        let task = RoutineTask(
            name: "Training",
            scheduleMode: .fixedInterval,
            recurrenceRule: .advanced(advanced, timeRange: window),
            scheduleAnchor: advanced.startDate,
            createdAt: advanced.startDate
        )

        let payload = NotificationCoordinator.notificationPayload(
            for: task,
            referenceDate: makeDate("2026-07-20T08:00:00Z"),
            calendar: calendar
        )

        #expect(payload.triggerDate == makeDate("2026-07-20T18:00:00Z"))
        #expect(payload.dueDate == makeDate("2026-07-20T18:00:00Z"))
        #expect(payload.recurrenceOccurrenceDates.prefix(4) == [
            makeDate("2026-07-20T18:00:00Z"),
            makeDate("2026-07-22T18:00:00Z"),
            makeDate("2026-08-03T18:00:00Z"),
            makeDate("2026-08-05T18:00:00Z")
        ])
    }

    @Test
    func notificationPayload_keepsMultipleDailyOccurrenceTimesInsideSharedWindow() {
        let calendar = makeTestCalendar()
        let window = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 22, minute: 0)
        )
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .daily,
            interval: 1,
            startDate: makeDate("2026-07-21T08:00:00Z"),
            timesOfDay: [
                RoutineTimeOfDay(hour: 8, minute: 0),
                RoutineTimeOfDay(hour: 20, minute: 0)
            ],
            timeZoneIdentifier: calendar.timeZone.identifier,
            calendar: calendar
        )
        let task = RoutineTask(
            name: "Medicine",
            scheduleMode: .fixedInterval,
            recurrenceRule: .advanced(advanced, timeRange: window),
            scheduleAnchor: advanced.startDate,
            createdAt: advanced.startDate
        )

        let payload = NotificationCoordinator.notificationPayload(
            for: task,
            referenceDate: makeDate("2026-07-21T07:30:00Z"),
            calendar: calendar
        )

        #expect(payload.triggerDate == makeDate("2026-07-21T08:00:00Z"))
        #expect(payload.recurrenceOccurrenceDates.prefix(4) == [
            makeDate("2026-07-21T08:00:00Z"),
            makeDate("2026-07-21T20:00:00Z"),
            makeDate("2026-07-22T08:00:00Z"),
            makeDate("2026-07-22T20:00:00Z")
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
