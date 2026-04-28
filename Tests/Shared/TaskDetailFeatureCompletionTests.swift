import ComposableArchitecture
import Foundation
import SwiftData
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@Suite(.serialized)
@MainActor
struct TaskDetailFeatureCompletionTests {
    @Test
    func dueDateMetadataText_includesTimeForTodoDeadline() {
        let deadline = makeDate("2026-04-25T13:00:00Z")
        let task = RoutineTask(
            name: "Submit report",
            deadline: deadline,
            scheduleMode: .oneOff
        )

        let state = TaskDetailFeature.State(task: task)

        #expect(state.dueDateMetadataText != nil)
        #expect(state.dueDateMetadataText != deadline.formatted(date: .abbreviated, time: .omitted))
    }

    @Test
    func dueDateMetadataText_includesTimeForExactWeeklyRoutine() throws {
        let task = RoutineTask(
            name: "Planning",
            scheduleMode: .fixedInterval,
            recurrenceRule: .weekly(
                on: 2,
                at: RoutineTimeOfDay(hour: 13, minute: 0)
            ),
            scheduleAnchor: makeDate("2026-04-25T09:00:00Z")
        )

        let state = TaskDetailFeature.State(task: task)
        let dueDate = try #require(state.resolvedDueDate)

        #expect(state.dueDateMetadataText != nil)
        #expect(state.dueDateMetadataText != dueDate.formatted(date: .abbreviated, time: .omitted))
    }

    @Test
    func notificationDisabledWarningText_showsWhenAppNotificationsAreOffForTodoDeadline() {
        let task = RoutineTask(
            name: "Submit report",
            deadline: Date().addingTimeInterval(3_600),
            scheduleMode: .oneOff
        )
        var state = TaskDetailFeature.State(task: task)
        state.hasLoadedNotificationStatus = true
        state.appNotificationsEnabled = false
        state.systemNotificationsAuthorized = true

        #expect(state.notificationDisabledWarningText?.contains("Notifications are off in Routina") == true)
        #expect(state.notificationDisabledWarningActionTitle == "Turn On Notifications")
    }

    @Test
    func notificationDisabledWarningText_showsWhenSystemNotificationsAreDisabledForExactRoutine() {
        let task = RoutineTask(
            name: "Planning",
            scheduleMode: .fixedInterval,
            recurrenceRule: .weekly(
                on: 2,
                at: RoutineTimeOfDay(hour: 13, minute: 0)
            ),
            scheduleAnchor: Date()
        )
        var state = TaskDetailFeature.State(task: task)
        state.hasLoadedNotificationStatus = true
        state.appNotificationsEnabled = true
        state.systemNotificationsAuthorized = false

        #expect(state.notificationDisabledWarningText?.contains("system settings") == true)
        #expect(state.notificationDisabledWarningActionTitle == "Open System Settings")
    }

    @Test
    func notificationDisabledWarningText_hidesForUntimedRoutine() {
        let task = RoutineTask(
            name: "Water plants",
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 3),
            scheduleAnchor: Date()
        )
        var state = TaskDetailFeature.State(task: task)
        state.hasLoadedNotificationStatus = true
        state.appNotificationsEnabled = false
        state.systemNotificationsAuthorized = false

        #expect(state.notificationDisabledWarningText == nil)
    }

    @Test
    func markAsDone_advancesCustomReminderAndSchedulesUpdatedReminder() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-04-25T10:00:00Z")
        let reminderAt = makeDate("2026-04-25T08:00:00Z")
        let expectedReminderAt = makeDate("2026-04-28T08:00:00Z")
        let calendar = makeTestCalendar()
        let task = makeTask(
            in: context,
            name: "Stretch",
            interval: 3,
            lastDone: nil,
            emoji: "🧘",
            reminderAt: reminderAt,
            recurrenceRule: .interval(days: 3),
            scheduleAnchor: makeDate("2026-04-22T10:00:00Z")
        )
        let scheduledTriggerDates = LockIsolated<[Date?]>([])

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { payload in
                scheduledTriggerDates.withValue { $0.append(payload.triggerDate) }
            }
        }

        _ = await store.withExhaustivity(.off) {
            await store.send(.markAsDone) {
                $0.taskRefreshID = 1
                $0.task.reminderAt = expectedReminderAt
                $0.isDoneToday = true
                $0.daysSinceLastRoutine = 0
                $0.overdueDays = 0
            }
        }

        await store.receive {
            if case .logsLoaded = $0 { return true }
            return false
        } assert: {
            let verificationContext = ModelContext(context.container)
            let descriptor = FetchDescriptor<RoutineLog>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            $0.logs = ((try? verificationContext.fetch(descriptor)) ?? []).filter { $0.taskID == task.id }
            $0.task.reminderAt = expectedReminderAt
            $0.isDoneToday = true
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
        }

        let persistedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(persistedTask.reminderAt == expectedReminderAt)
        #expect(scheduledTriggerDates.value == [expectedReminderAt])
    }

    @Test
    func notificationDisabledWarningTapped_enablesAppNotificationsAndSchedulesTaskWhenAuthorized() async {
        let now = makeDate("2026-04-25T09:00:00Z")
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            name: "Submit report",
            deadline: makeDate("2026-04-25T13:00:00Z"),
            scheduleMode: .oneOff
        )
        let enabledPreference = LockIsolated<Bool?>(nil)
        let scheduledIDs = LockIsolated<[String]>([])
        var initialState = TaskDetailFeature.State(task: task)
        initialState.hasLoadedNotificationStatus = true
        initialState.appNotificationsEnabled = false
        initialState.systemNotificationsAuthorized = true
        let store = TestStore(
            initialState: initialState
        ) {
            TaskDetailFeature()
        } withDependencies: {
            $0.date.now = now
            $0.calendar = calendar
            $0.appSettingsClient.setNotificationsEnabled = { value in
                enabledPreference.setValue(value)
            }
            $0.notificationClient.requestAuthorizationIfNeeded = { true }
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
        }
        store.exhaustivity = .off

        await store.send(.notificationDisabledWarningTapped)
        await store.receive(.notificationStatusLoaded(appEnabled: true, systemAuthorized: true)) {
            $0.hasLoadedNotificationStatus = true
            $0.appNotificationsEnabled = true
            $0.systemNotificationsAuthorized = true
        }

        #expect(enabledPreference.value == true)
        #expect(scheduledIDs.value == [task.id.uuidString])
    }

    @Test
    func notificationDisabledWarningTapped_opensSystemSettingsWhenSystemNotificationsAreDisabled() async {
        let settingsURL = URL(string: "app-settings:notifications")!
        let openedURL = LockIsolated<URL?>(nil)
        let task = RoutineTask(
            name: "Planning",
            scheduleMode: .fixedInterval,
            recurrenceRule: .weekly(
                on: 2,
                at: RoutineTimeOfDay(hour: 13, minute: 0)
            ),
            scheduleAnchor: Date()
        )
        var initialState = TaskDetailFeature.State(task: task)
        initialState.hasLoadedNotificationStatus = true
        initialState.appNotificationsEnabled = true
        initialState.systemNotificationsAuthorized = false
        let store = TestStore(
            initialState: initialState
        ) {
            TaskDetailFeature()
        } withDependencies: {
            $0.urlOpenerClient.notificationSettingsURL = { settingsURL }
            $0.urlOpenerClient.open = { url in
                openedURL.setValue(url)
            }
        }
        store.exhaustivity = .off

        await store.send(.notificationDisabledWarningTapped)

        #expect(openedURL.value == settingsURL)
    }

    @Test
    func confirmAssumedPastDays_includesTodayWhenTodayIsAssumedDone() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-02-25T21:30:00Z")
        let task = RoutineTask(
            name: "Brush teeth",
            emoji: "🪥",
            scheduleMode: .fixedInterval,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 21, minute: 0)),
            createdAt: makeDate("2026-02-24T00:00:00Z"),
            autoAssumeDailyDone: true
        )
        context.insert(task)
        try context.save()

        let calendar = makeTestCalendar()
        let scheduledIDs = LockIsolated<[String]>([])
        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                logs: [],
                selectedDate: calendar.startOfDay(for: now)
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
            $0.notificationClient.cancel = { _ in }
        }

        _ = await store.withExhaustivity(.off) {
            await store.send(.confirmAssumedPastDays) {
                $0.task.lastDone = now
                $0.taskRefreshID = 1
                $0.isDoneToday = true
            }
        }

        await store.receive { action in
            guard case let .logsLoaded(logs) = action else { return false }
            return logs.count == 2
        } assert: {
            let logs = RoutineLogHistory.detailLogs(taskID: task.id, context: context)
            $0.logs = logs
            #expect(logs.compactMap(\.timestamp) == [
                now,
                makeDate("2026-02-24T12:00:00Z"),
            ])
            $0.isDoneToday = true
        }

        let persistedTask = try #require(context.fetch(FetchDescriptor<RoutineTask>()).first)
        let persistedLogs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(persistedTask.lastDone == now)
        #expect(persistedLogs.count == 2)
        #expect(persistedLogs.compactMap(\.timestamp).sorted(by: >) == [
            now,
            makeDate("2026-02-24T12:00:00Z"),
        ])
        #expect(scheduledIDs.value == [task.id.uuidString])
    }

    @Test
    func completionButton_usesBulkConfirmWhenTodayAndPastDaysAreAssumed() {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        let task = RoutineTask(
            name: "Walk",
            emoji: "🚶",
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 1),
            createdAt: yesterday,
            autoAssumeDailyDone: true
        )
        let state = TaskDetailFeature.State(
            task: task,
            logs: [],
            selectedDate: today
        )

        #expect(state.shouldUseBulkConfirmAsPrimaryAction)
        #expect(state.completionButtonAction == .confirmAssumedPastDays)
        #expect(state.completionButtonTitle == "Confirm 2 assumed days")
        #expect(!state.shouldShowBulkConfirmAssumedDays)
    }

    @Test
    func markAsDone_forPastWeeklyExactTimeDate_usesScheduledTimestamp() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-04-21T10:00:00Z")
        let selectedDate = makeDate("2026-04-20T00:00:00Z")
        let expectedCompletion = makeDate("2026-04-20T17:00:00Z")

        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = makeTask(
            in: context,
            name: "Workout",
            interval: 7,
            lastDone: nil,
            emoji: "💪",
            recurrenceRule: .weekly(on: 2, at: RoutineTimeOfDay(hour: 17, minute: 0)),
            scheduleAnchor: makeDate("2026-04-19T10:00:00Z")
        )
        try context.save()

        let scheduledIDs = LockIsolated<[String]>([])
        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                selectedDate: selectedDate
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.markAsDone) {
            $0.task.lastDone = expectedCompletion
            $0.taskRefreshID = 1
            $0.daysSinceLastRoutine = 1
        }

        await store.receive { action in
            guard case let .logsLoaded(logs) = action else { return false }
            return logs.contains { $0.kind == .completed && $0.timestamp == expectedCompletion }
        } assert: {
            $0.logs = RoutineLogHistory.detailLogs(taskID: task.id, context: context)
            $0.daysSinceLastRoutine = 1
        }

        let persistedTaskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { persistedTask in
                        persistedTask.id == persistedTaskID
                    }
                )
            ).first
        )
        let persistedLogs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(persistedTask.lastDone == expectedCompletion)
        #expect(persistedLogs.count == 1)
        #expect(persistedLogs.first?.timestamp == expectedCompletion)
        #expect(scheduledIDs.value == [task.id.uuidString])
    }

    @Test
    func selectedDateDone_forExactTimedWeeklyRoutine_ignoresNonOccurrenceDays() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let thursdayCompletion = makeDate("2026-04-23T18:30:00Z")
        let friday = makeDate("2026-04-24T00:00:00Z")

        let task = RoutineTask(
            name: "Group session",
            scheduleMode: .fixedInterval,
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            lastDone: thursdayCompletion,
            scheduleAnchor: makeDate("2026-04-19T10:00:00Z"),
            createdAt: makeDate("2026-04-19T10:00:00Z")
        )

        let state = TaskDetailFeature.State(
            task: task,
            logs: [RoutineLog(timestamp: thursdayCompletion, taskID: task.id)],
            selectedDate: calendar.startOfDay(for: friday)
        )

        #expect(state.selectedScheduledOccurrenceDate == nil)
        #expect(!state.isSelectedDateDone)
        #expect(!state.isSelectedDateTerminal)
    }

    @Test
    func markAsDone_forTodayOnOverdueWeeklyExactTimeRoutine_usesOutstandingOccurrenceTimestamp() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-04-24T10:00:00Z")
        let expectedCompletion = makeDate("2026-04-23T18:30:00Z")

        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = makeTask(
            in: context,
            name: "Group session",
            interval: 7,
            lastDone: nil,
            emoji: "✨",
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            scheduleAnchor: makeDate("2026-04-19T10:00:00Z")
        )
        try context.save()

        let scheduledIDs = LockIsolated<[String]>([])
        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                selectedDate: calendar.startOfDay(for: now)
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.markAsDone) {
            $0.task.lastDone = expectedCompletion
            $0.taskRefreshID = 1
            $0.daysSinceLastRoutine = 1
            $0.overdueDays = 0
            $0.isDoneToday = false
        }

        await store.receive { action in
            guard case let .logsLoaded(logs) = action else { return false }
            return logs.contains { $0.kind == .completed && $0.timestamp == expectedCompletion }
        } assert: {
            $0.logs = RoutineLogHistory.detailLogs(taskID: task.id, context: context)
            $0.daysSinceLastRoutine = 1
            $0.overdueDays = 0
            $0.isDoneToday = false
        }

        let persistedTaskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { persistedTask in
                        persistedTask.id == persistedTaskID
                    }
                )
            ).first
        )
        let persistedLogs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(persistedTask.lastDone == expectedCompletion)
        #expect(persistedLogs.count == 1)
        #expect(persistedLogs.first?.timestamp == expectedCompletion)
        #expect(scheduledIDs.value == [task.id.uuidString])
    }

    @Test
    func logsLoaded_forInvalidNonOccurrenceTimedLog_doesNotMarkDoneToday() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-04-24T10:36:00Z")
        let invalidFridayCompletion = makeDate("2026-04-24T10:36:00Z")

        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = makeTask(
            in: context,
            name: "Group session",
            interval: 7,
            lastDone: invalidFridayCompletion,
            emoji: "✨",
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            scheduleAnchor: makeDate("2026-04-19T10:00:00Z")
        )
        let fridayLog = makeLog(in: context, task: task, timestamp: invalidFridayCompletion)

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.logsLoaded([fridayLog])) {
            $0.logs = [fridayLog]
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
            $0.isDoneToday = false
        }
    }

    @Test
    func removeLogEntry_removesInvalidTimedCompletion() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-04-24T10:36:00Z")
        let invalidFridayCompletion = makeDate("2026-04-24T10:36:00Z")

        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = makeTask(
            in: context,
            name: "Group session",
            interval: 7,
            lastDone: invalidFridayCompletion,
            emoji: "✨",
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            scheduleAnchor: makeDate("2026-04-19T10:00:00Z")
        )
        let fridayLog = makeLog(in: context, task: task, timestamp: invalidFridayCompletion)
        try context.save()

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                logs: [fridayLog],
                selectedDate: calendar.startOfDay(for: now)
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.removeLogEntry(invalidFridayCompletion)) {
            $0.task.lastDone = nil
            $0.task.scheduleAnchor = makeDate("2026-04-19T10:00:00Z")
            $0.taskRefreshID = 1
            $0.logs = []
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 1
            $0.isDoneToday = false
        }

        await store.receive(.logsLoaded([]))

        let persistedTaskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { persistedTask in
                        persistedTask.id == persistedTaskID
                    }
                )
            ).first
        )
        let persistedLogs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(persistedTask.lastDone == nil)
        #expect(persistedTask.scheduleAnchor == makeDate("2026-04-19T10:00:00Z"))
        #expect(persistedLogs.isEmpty)
    }
}
