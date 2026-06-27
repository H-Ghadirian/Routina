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
    func toggleChecklistItemCompletion_allowsProgressBeforeScheduledDay() async throws {
        let context = makeInMemoryContext()
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let now = makeDate("2026-06-17T10:00:00Z")
        let sciformaID = UUID()
        let excelID = UUID()
        let task = RoutineTask(
            name: "Working Hours",
            checklistItems: [
                RoutineChecklistItem(id: sciformaID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: excelID, title: "Excel", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            recurrenceRule: .monthly(on: 25),
            scheduleAnchor: now
        )
        context.insert(task)
        try context.save()

        #expect(!RoutineDateMath.canMarkDone(for: task, referenceDate: now, calendar: calendar))

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
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.toggleChecklistItemCompletion(sciformaID)) {
            $0.taskRefreshID = 1
        }
        #expect(store.state.task.isChecklistItemCompleted(sciformaID))
        #expect(!store.state.task.isChecklistItemCompleted(excelID))
        #expect(!store.state.isDoneToday)

        await store.receive(.logsLoaded([]))

        let persistedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(persistedTask.isChecklistItemCompleted(sciformaID))
        #expect(!persistedTask.isChecklistItemCompleted(excelID))

        await store.send(.toggleChecklistItemCompletion(sciformaID)) {
            $0.taskRefreshID = 2
            $0.task.completedChecklistItemIDs = []
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
        }
        #expect(!store.state.task.isChecklistItemCompleted(sciformaID))

        await store.receive(.logsLoaded([]))

        let persistedUncheckedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(!persistedUncheckedTask.isChecklistItemCompleted(sciformaID))
        #expect(!persistedUncheckedTask.isChecklistItemCompleted(excelID))

        _ = await store.withExhaustivity(.off) {
            await store.send(.toggleChecklistItemCompletion(sciformaID)) {
                $0.taskRefreshID = 3
            }
            await store.receive(.logsLoaded([]))

            await store.send(.toggleChecklistItemCompletion(excelID)) {
                $0.taskRefreshID = 4
                $0.isDoneToday = true
                $0.daysSinceLastRoutine = 0
                $0.overdueDays = 0
                #expect($0.logs.count == 1)
            }
            await store.receive {
                guard case let .logsLoaded(logs) = $0 else { return false }
                return logs.count == 1
            } assert: {
                #expect($0.logs.count == 1)
                $0.isDoneToday = true
                $0.daysSinceLastRoutine = 0
                $0.overdueDays = 0
            }
        }

        await store.send(.toggleChecklistItemCompletion(excelID))

        let persistedReopenedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        let persistedLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(store.state.task.lastDone == now)
        #expect(store.state.task.completedChecklistItemCount(referenceDate: now, calendar: calendar) == 0)
        #expect(store.state.isDoneToday)
        #expect(persistedReopenedTask.lastDone == now)
        #expect(persistedReopenedTask.completedChecklistItemCount(referenceDate: now, calendar: calendar) == 0)
        #expect(persistedLogs.count == 1)
    }

    @Test
    func completedDailyChecklistIgnoresStalePartialProgressInPresentation() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-06-19T12:00:00Z")
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

        let state = TaskDetailFeature.State(
            task: task,
            logs: [RoutineLog(timestamp: now, taskID: task.id, kind: .completed)],
            selectedDate: calendar.startOfDay(for: now),
            daysSinceLastRoutine: 0,
            overdueDays: 0,
            isDoneToday: true
        )

        #expect(state.checklistProgressText == "All items completed on selected day")
        #expect(state.summaryStatusTitle == "Done today")
        for item in task.checklistItems {
            #expect(state.isChecklistItemMarkedDone(item))
        }
        #expect(!TaskDetailChecklistPresentation.canToggleItem(
            task.checklistItems[2],
            task: task,
            selectedDate: now,
            isSelectedDateCompleted: true,
            calendar: calendar
        ))
    }

    @Test
    func completedChecklistRowsStayCheckedAfterFinalItemClearsPartialProgress() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-06-19T12:00:00Z")
        let firstID = UUID()
        let secondID = UUID()
        let task = RoutineTask(
            name: "Working Hours",
            checklistItems: [
                RoutineChecklistItem(id: firstID, title: "Sciforma", intervalDays: 1, createdAt: now),
                RoutineChecklistItem(id: secondID, title: "Excel", intervalDays: 1, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 9, minute: 0)),
            lastDone: now,
            scheduleAnchor: now
        )
        task.resetChecklistProgress()

        let state = TaskDetailFeature.State(
            task: task,
            logs: [],
            selectedDate: calendar.startOfDay(for: now),
            daysSinceLastRoutine: 0,
            overdueDays: 0,
            isDoneToday: false
        )

        #expect(state.isSelectedDateDone)
        #expect(state.checklistProgressText == "All items completed on selected day")
        for item in task.checklistItems {
            #expect(state.isChecklistItemMarkedDone(item))
            #expect(!TaskDetailChecklistPresentation.canToggleItem(
                item,
                task: task,
                selectedDate: state.resolvedSelectedDate,
                isSelectedDateCompleted: state.isSelectedDateDone,
                calendar: calendar
            ))
        }
    }

    @Test
    func completedDailyChecklistIgnoresStalePartialToggle() async throws {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-06-19T12:00:00Z")
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

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                logs: [RoutineLog(timestamp: now, taskID: task.id, kind: .completed)],
                selectedDate: calendar.startOfDay(for: now),
                daysSinceLastRoutine: 0,
                overdueDays: 0,
                isDoneToday: true
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            $0.calendar = calendar
            $0.date.now = now
        }

        await store.send(.toggleChecklistItemCompletion(thirdID))
    }

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
    func dueDateMetadataText_hidesTodoAvailabilityWindowWithoutDeadline() {
        let task = RoutineTask(
            name: "Watch WWDC 26 Videos",
            availabilityStartDate: makeDate("2026-06-08T00:00:00Z"),
            availabilityEndDate: makeDate("2027-06-12T00:00:00Z"),
            scheduleMode: .oneOff
        )

        let state = TaskDetailFeature.State(task: task)

        #expect(state.resolvedDueDate == nil)
        #expect(state.dueDateMetadataText == nil)
        #expect(state.daysUntilDueIfActive == Int.max)
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
        let calendar = Calendar.current
        let futureOccurrence = calendar.date(
            byAdding: .day,
            value: 1,
            to: Date()
        ) ?? Date().addingTimeInterval(86_400)
        let occurrenceComponents = calendar.dateComponents(
            [.weekday, .hour, .minute],
            from: futureOccurrence
        )
        let task = RoutineTask(
            name: "Planning",
            scheduleMode: .fixedInterval,
            recurrenceRule: .weekly(
                on: occurrenceComponents.weekday ?? 2,
                at: RoutineTimeOfDay(
                    hour: occurrenceComponents.hour ?? 13,
                    minute: occurrenceComponents.minute ?? 0
                )
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
    func multiDayRoutinePrimaryActionStartsThenFinishes() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-04-25T10:00:00Z")
        let task = RoutineTask(
            name: "Travel",
            routineDurationMode: .multiDay,
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 180),
            scheduleAnchor: makeDate("2026-04-01T10:00:00Z")
        )
        var state = TaskDetailFeature.State(task: task)
        let handler = TaskDetailRoutineLifecycleActionHandler(
            now: { now },
            calendar: calendar,
            refreshTaskView: { $0.taskRefreshID &+= 1 },
            updateDerivedState: { _ in },
            upsertLocalLog: { date, state in
                state.logs.append(RoutineLog(timestamp: date, taskID: state.task.id, kind: .completed))
            },
            persistPause: { _, _ in .none },
            persistNotToday: { _, _ in .none },
            persistResume: { _, _ in .none },
            persistStartOngoing: { _, _ in .none },
            persistFinishOngoing: { _, _ in .none }
        )

        #expect(state.completionButtonTitle == "Start")
        #expect(state.completionButtonAction == .startOngoingTapped)
        #expect(state.completionButtonSystemImage == "play.circle.fill")
        var futureSelectedState = state
        futureSelectedState.selectedDate = calendar.date(byAdding: .day, value: 3, to: now)
        #expect(!futureSelectedState.isCompletionButtonDisabled)

        _ = handler.startOngoingTapped(state: &state)

        #expect(state.task.isOngoing)
        #expect(state.task.ongoingSince == now)
        #expect(state.task.changeLogEntries.contains { $0.kind == .ongoingStarted })
        #expect(state.summaryStatusTitle.hasPrefix("In progress since"))
        #expect(state.completionButtonTitle == "Stop")
        #expect(state.completionButtonAction == .finishOngoingTapped)
        #expect(state.completionButtonSystemImage == "stop.circle.fill")

        _ = handler.finishOngoingTapped(state: &state)

        #expect(!state.task.isOngoing)
        #expect(state.task.ongoingSince == nil)
        #expect(state.task.lastDone == now)
        #expect(state.task.changeLogEntries.contains { $0.kind == .ongoingStopped })
        #expect(state.logs.count == 1)
    }

    @Test
    func multiDayRoutineUsesSelectedCalendarDatesForStartAndStop() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-06-20T10:00:00Z")
        let startDay = makeDate("2026-06-13T12:00:00Z")
        let stopDay = makeDate("2026-06-15T12:00:00Z")
        let task = RoutineTask(
            name: "Travel",
            routineDurationMode: .multiDay,
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 180),
            scheduleAnchor: makeDate("2026-04-01T10:00:00Z")
        )
        var state = TaskDetailFeature.State(
            task: task,
            selectedDate: calendar.startOfDay(for: startDay)
        )
        let handler = TaskDetailRoutineLifecycleActionHandler(
            now: { now },
            calendar: calendar,
            refreshTaskView: { $0.taskRefreshID &+= 1 },
            updateDerivedState: { _ in },
            upsertLocalLog: { date, state in
                state.logs.append(RoutineLog(timestamp: date, taskID: state.task.id, kind: .completed))
            },
            persistPause: { _, _ in .none },
            persistNotToday: { _, _ in .none },
            persistResume: { _, _ in .none },
            persistStartOngoing: { _, _ in .none },
            persistFinishOngoing: { _, _ in .none }
        )

        _ = handler.startOngoingTapped(state: &state)

        #expect(state.task.ongoingSince == calendar.startOfDay(for: startDay))

        state.selectedDate = calendar.date(byAdding: .day, value: -1, to: startDay)
        #expect(state.completionButtonTitle == "Select a stop date after start")
        #expect(state.isCompletionButtonDisabled)

        state.selectedDate = calendar.startOfDay(for: stopDay)
        _ = handler.finishOngoingTapped(state: &state)

        #expect(state.task.lastDone == calendar.startOfDay(for: stopDay))
        #expect(state.logs.first?.timestamp == calendar.startOfDay(for: stopDay))
        let spanDates = TaskDetailCalendarPresentation.completedMultiDaySpanDates(
            from: state.task.changeLogEntries,
            calendar: calendar
        )
        #expect(spanDates.contains(calendar.startOfDay(for: startDay)))
        #expect(spanDates.contains(calendar.startOfDay(for: stopDay)))
    }

    @Test
    func multiDayRoutineCanBackfillOlderSpanAfterNewerSpanWithoutStayingOngoing() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-06-15T10:00:00Z")
        let firstStartDay = makeDate("2026-05-20T12:00:00Z")
        let firstStopDay = makeDate("2026-05-24T12:00:00Z")
        let secondStartDay = makeDate("2026-05-07T12:00:00Z")
        let secondStopDay = makeDate("2026-05-09T12:00:00Z")
        let task = RoutineTask(
            name: "Travel",
            routineDurationMode: .multiDay,
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 180),
            scheduleAnchor: makeDate("2026-04-01T10:00:00Z")
        )
        var state = TaskDetailFeature.State(
            task: task,
            selectedDate: calendar.startOfDay(for: firstStartDay)
        )
        let handler = TaskDetailRoutineLifecycleActionHandler(
            now: { now },
            calendar: calendar,
            refreshTaskView: { $0.taskRefreshID &+= 1 },
            updateDerivedState: { _ in },
            upsertLocalLog: { date, state in
                state.logs.append(RoutineLog(timestamp: date, taskID: state.task.id, kind: .completed))
            },
            persistPause: { _, _ in .none },
            persistNotToday: { _, _ in .none },
            persistResume: { _, _ in .none },
            persistStartOngoing: { _, _ in .none },
            persistFinishOngoing: { _, _ in .none }
        )

        _ = handler.startOngoingTapped(state: &state)
        state.selectedDate = calendar.startOfDay(for: firstStopDay)
        _ = handler.finishOngoingTapped(state: &state)

        #expect(state.task.lastDone == calendar.startOfDay(for: firstStopDay))
        #expect(!state.task.isOngoing)

        state.selectedDate = calendar.startOfDay(for: secondStartDay)
        _ = handler.startOngoingTapped(state: &state)
        state.selectedDate = calendar.startOfDay(for: secondStopDay)
        _ = handler.finishOngoingTapped(state: &state)

        #expect(!state.task.isOngoing)
        #expect(state.task.ongoingSince == nil)
        #expect(state.task.lastDone == calendar.startOfDay(for: firstStopDay))
        #expect(state.logs.map { $0.timestamp }.contains(calendar.startOfDay(for: secondStopDay)))

        let spanDates = TaskDetailCalendarPresentation.completedMultiDaySpanDates(
            from: state.task.changeLogEntries,
            calendar: calendar
        )
        for day in 7...9 {
            let date = makeDate("2026-05-\(String(format: "%02d", day))T12:00:00Z")
            #expect(spanDates.contains(calendar.startOfDay(for: date)))
        }
        for day in 20...24 {
            let date = makeDate("2026-05-\(String(format: "%02d", day))T12:00:00Z")
            #expect(spanDates.contains(calendar.startOfDay(for: date)))
        }
        #expect(!spanDates.contains(calendar.startOfDay(for: makeDate("2026-05-10T12:00:00Z"))))
        #expect(!spanDates.contains(calendar.startOfDay(for: makeDate("2026-05-19T12:00:00Z"))))
        #expect(!spanDates.contains(calendar.startOfDay(for: makeDate("2026-05-25T12:00:00Z"))))
    }

    @Test
    func multiDayRoutineRepairsStoppedSpanThatWasLeftOngoing() {
        let calendar = makeTestCalendar()
        let startDay = calendar.startOfDay(for: makeDate("2026-05-07T12:00:00Z"))
        let stopDay = calendar.startOfDay(for: makeDate("2026-05-09T12:00:00Z"))
        let task = RoutineTask(
            name: "Travel",
            routineDurationMode: .multiDay,
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 180),
            lastDone: calendar.startOfDay(for: makeDate("2026-05-24T12:00:00Z"))
        )
        task.activityState = .ongoing
        task.ongoingSince = startDay
        task.appendChangeLogEntry(
            RoutineTaskChangeLogEntry(
                timestamp: startDay,
                kind: .ongoingStarted,
                newValue: RoutineTaskMultiDaySpanDateStorage.encode(startDay)
            )
        )
        task.appendChangeLogEntry(
            RoutineTaskChangeLogEntry(
                timestamp: stopDay,
                kind: .ongoingStopped,
                previousValue: RoutineTaskMultiDaySpanDateStorage.encode(startDay),
                newValue: RoutineTaskMultiDaySpanDateStorage.encode(stopDay)
            )
        )

        #expect(task.clearStoppedOngoingStateIfNeeded(calendar: calendar))
        #expect(!task.isOngoing)
        #expect(task.ongoingSince == nil)
    }

    @Test
    func undoSelectedDateCompletionRemovesMultiDayCalendarSpan() {
        let calendar = makeTestCalendar()
        let startDay = makeDate("2026-06-13T12:00:00Z")
        let stopDay = makeDate("2026-06-15T12:00:00Z")
        let task = RoutineTask(
            name: "Travel",
            routineDurationMode: .multiDay,
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 180),
            lastDone: calendar.startOfDay(for: stopDay),
            scheduleAnchor: calendar.startOfDay(for: stopDay)
        )
        task.appendChangeLogEntry(
            RoutineTaskChangeLogEntry(
                timestamp: calendar.startOfDay(for: startDay),
                kind: .ongoingStarted,
                newValue: RoutineTaskMultiDaySpanDateStorage.encode(calendar.startOfDay(for: startDay))
            )
        )
        task.appendChangeLogEntry(
            RoutineTaskChangeLogEntry(
                timestamp: calendar.startOfDay(for: stopDay),
                kind: .ongoingStopped,
                previousValue: RoutineTaskMultiDaySpanDateStorage.encode(calendar.startOfDay(for: startDay)),
                newValue: RoutineTaskMultiDaySpanDateStorage.encode(calendar.startOfDay(for: stopDay))
            )
        )
        var state = TaskDetailFeature.State(
            task: task,
            logs: [
                RoutineLog(timestamp: calendar.startOfDay(for: stopDay), taskID: task.id, kind: .completed)
            ],
            selectedDate: calendar.startOfDay(for: stopDay)
        )

        #expect(!TaskDetailCalendarPresentation.completedMultiDaySpanDates(
            from: state.task.changeLogEntries,
            calendar: calendar
        ).isEmpty)

        withDependencies {
            $0.calendar = calendar
        } operation: {
            TaskDetailFeature().removeCompletion(on: calendar.startOfDay(for: stopDay), from: &state)
        }

        #expect(state.task.lastDone == nil)
        #expect(state.logs.isEmpty)
        #expect(TaskDetailCalendarPresentation.completedMultiDaySpanDates(
            from: state.task.changeLogEntries,
            calendar: calendar
        ).isEmpty)
    }

    @Test
    func toggleChecklistItemCompletion_forOptionalChecklistPersistsProgress() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-04-25T10:00:00Z")
        let itemID = UUID()
        let task = RoutineTask(
            name: "Plan workshop",
            checklistItems: [RoutineChecklistItem(id: itemID, title: "Book room", intervalDays: 1)],
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 7),
            scheduleAnchor: now
        )
        context.insert(task)
        try context.save()

        let store = TestStore(
            initialState: TaskDetailFeature.State(task: task)
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
        }
        store.exhaustivity = .off

        await store.send(.toggleChecklistItemCompletion(itemID)) {
            $0.task.completedChecklistItemIDs = [itemID]
        }
        await store.receive(.logsLoaded([]))

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(persistedTask.isChecklistItemCompleted(itemID))
        #expect(persistedTask.lastDone == nil)
    }

    @Test
    func markAsDone_ignoresRoutineExactReminderAndSchedulesCadenceReminder() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-04-25T10:00:00Z")
        let reminderAt = makeDate("2026-04-25T08:00:00Z")
        let calendar = makeTestCalendar()
        let expectedTriggerDate = NotificationPreferences.reminderDate(
            on: makeDate("2026-04-28T10:00:00Z"),
            calendar: calendar
        )
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
                $0.isDoneToday = true
                $0.daysSinceLastRoutine = 0
                $0.overdueDays = 0
                $0.pendingLocalCompletionDates = [now]
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
            $0.pendingLocalCompletionDates = []
            $0.isDoneToday = true
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
        }

        let persistedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(persistedTask.reminderAt == reminderAt)
        #expect(scheduledTriggerDates.value == [expectedTriggerDate])
    }

    @Test
    func markAsDone_forSelectedPastDateOnNeverCompletedIntervalRoutine_persistsLog() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-04-28T10:00:00Z")
        let selectedDate = makeDate("2026-04-21T08:00:00Z")
        let calendar = makeTestCalendar()
        let task = makeTask(
            in: context,
            name: "Exercise",
            interval: 4,
            lastDone: nil,
            emoji: "🏃"
        )
        let scheduledIDs = LockIsolated<[String]>([])
        let selectedDayStart = calendar.startOfDay(for: selectedDate)

        let initialState = TaskDetailFeature.State(
            task: task,
            logs: [],
            selectedDate: selectedDayStart,
            daysSinceLastRoutine: 0,
            overdueDays: 0,
            isDoneToday: false
        )

        let store = TestStore(initialState: initialState) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
        }

        _ = await store.withExhaustivity(.off) {
            await store.send(.markAsDone) {
                $0.taskRefreshID = 1
                $0.daysSinceLastRoutine = 7
                $0.overdueDays = 3
                $0.pendingLocalCompletionDates = [makeDate("2026-04-21T12:00:00Z")]
            }
        }
        #expect(store.state.logs.count == 1)
        #expect(store.state.logs.contains { log in
            guard let timestamp = log.timestamp else { return false }
            return calendar.isDate(timestamp, inSameDayAs: selectedDayStart)
        })

        let taskID = task.id
        await store.receive {
            if case .logsLoaded = $0 { return true }
            return false
        } assert: {
            let logs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
            $0.logs = logs
            $0.pendingLocalCompletionDates = []
            #expect(logs.count == 1)
            #expect(logs.contains { log in
                guard let timestamp = log.timestamp else { return false }
                return calendar.isDate(timestamp, inSameDayAs: selectedDayStart)
            })
            $0.daysSinceLastRoutine = 7
            $0.overdueDays = 3
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
        #expect(persistedTask.lastDone == makeDate("2026-04-21T12:00:00Z"))
        #expect(persistedTask.scheduleAnchor == makeDate("2026-04-21T12:00:00Z"))
        #expect(persistedLogs.count == 1)
        #expect(scheduledIDs.value == [task.id.uuidString])
    }

    @Test
    func undoRequests_presentConfirmationBeforeRemovingLog() async {
        let selectedDate = makeDate("2026-04-21T08:00:00Z")
        let completionDate = makeDate("2026-04-21T12:00:00Z")
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            id: UUID(),
            name: "Exercise",
            emoji: "🏃",
            interval: 4,
            lastDone: completionDate
        )
        let log = RoutineLog(timestamp: completionDate, taskID: task.id, kind: .completed)

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                logs: [log],
                selectedDate: calendar.startOfDay(for: selectedDate)
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            $0.calendar = calendar
        }

        #expect(store.state.completionButtonAction == .requestUndoSelectedDateCompletion)

        await store.send(.requestUndoSelectedDateCompletion) {
            $0.isUndoCompletionConfirmationPresented = true
        }

        await store.send(.setUndoCompletionConfirmation(false)) {
            $0.isUndoCompletionConfirmationPresented = false
        }

        await store.send(.requestRemoveLogEntry(completionDate)) {
            $0.isUndoCompletionConfirmationPresented = true
            $0.pendingLogRemovalTimestamp = completionDate
        }

        await store.send(.setUndoCompletionConfirmation(false)) {
            $0.isUndoCompletionConfirmationPresented = false
            $0.pendingLogRemovalTimestamp = nil
        }
    }

    @Test
    func markAsDone_forPastDateBeforeExpiredSnooze_persistsLog() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-04-28T10:00:00Z")
        let selectedDate = makeDate("2026-04-21T08:00:00Z")
        let calendar = makeTestCalendar()
        let task = makeTask(
            in: context,
            name: "Exercise",
            interval: 4,
            lastDone: nil,
            emoji: "🏃",
            recurrenceRule: .interval(days: 4),
            scheduleAnchor: now
        )
        task.snoozedUntil = makeDate("2026-04-22T00:00:00Z")
        try context.save()

        let selectedDayStart = calendar.startOfDay(for: selectedDate)
        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                logs: [],
                selectedDate: selectedDayStart,
                daysSinceLastRoutine: 0,
                overdueDays: 0,
                isDoneToday: false
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        _ = await store.withExhaustivity(.off) {
            await store.send(.markAsDone) {
                $0.taskRefreshID = 1
                $0.daysSinceLastRoutine = 7
                $0.pendingLocalCompletionDates = [makeDate("2026-04-21T12:00:00Z")]
            }
        }

        let taskID = task.id
        await store.receive {
            if case .logsLoaded = $0 { return true }
            return false
        } assert: {
            let logs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
            $0.logs = logs
            $0.pendingLocalCompletionDates = []
            #expect(logs.count == 1)
            #expect(logs.contains { log in
                guard let timestamp = log.timestamp else { return false }
                return calendar.isDate(timestamp, inSameDayAs: selectedDayStart)
            })
            $0.daysSinceLastRoutine = 7
            $0.overdueDays = 0
            $0.isDoneToday = false
        }

        let persistedLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(persistedLogs.count == 1)
        #expect(task.snoozedUntil == makeDate("2026-04-22T00:00:00Z"))
    }

    @Test
    func markAsDone_afterUndoingPastIntervalLog_restoresPastLog() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-04-28T10:00:00Z")
        let selectedDate = makeDate("2026-04-21T08:00:00Z")
        let calendar = makeTestCalendar()
        let task = makeTask(
            in: context,
            name: "Exercise",
            interval: 4,
            lastDone: now,
            emoji: "🏃"
        )
        let todayLog = makeLog(in: context, task: task, timestamp: now)
        let pastLog = makeLog(
            in: context,
            task: task,
            timestamp: makeDate("2026-04-21T12:00:00Z")
        )
        try context.save()

        let scheduledIDs = LockIsolated<[String]>([])
        let selectedDayStart = calendar.startOfDay(for: selectedDate)
        let initialState = TaskDetailFeature.State(
            task: task,
            logs: [todayLog, pastLog],
            selectedDate: selectedDayStart,
            daysSinceLastRoutine: 0,
            overdueDays: 0,
            isDoneToday: true
        )

        let store = TestStore(initialState: initialState) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
        }

        await store.send(.undoSelectedDateCompletion) {
            $0.taskRefreshID = 1
            $0.logs = [todayLog]
            $0.pendingLocalRemovalDates = [selectedDayStart]
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
            $0.isDoneToday = true
        }

        await store.receive(.logsLoaded([todayLog])) {
            $0.pendingLocalRemovalDates = []
        }

        #expect(!store.state.isCompletionButtonDisabled)
        #expect(store.state.completionButtonTitle.hasPrefix("Done for"))

        _ = await store.withExhaustivity(.off) {
            await store.send(.markAsDone) {
                $0.taskRefreshID = 2
                $0.daysSinceLastRoutine = 0
                $0.pendingLocalCompletionDates = [makeDate("2026-04-21T12:00:00Z")]
            }
        }
        #expect(store.state.logs.count == 2)
        #expect(store.state.logs.contains { log in
            guard let timestamp = log.timestamp else { return false }
            return calendar.isDate(timestamp, inSameDayAs: selectedDayStart)
        })

        let taskID = task.id
        await store.receive {
            if case .logsLoaded = $0 { return true }
            return false
        } assert: {
            let logs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
            $0.logs = logs
            $0.pendingLocalCompletionDates = []
            #expect(logs.count == 2)
            #expect(logs.contains { log in
                guard let timestamp = log.timestamp else { return false }
                return calendar.isDate(timestamp, inSameDayAs: selectedDayStart)
            })
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
            $0.isDoneToday = true
        }

        let persistedLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(persistedLogs.count == 2)
        #expect(scheduledIDs.value == [task.id.uuidString, task.id.uuidString])
    }

    @Test
    func logsLoaded_preservesPendingLocalPastCompletionDuringStaleReload() async {
        let now = makeDate("2026-04-28T10:00:00Z")
        let pastCompletion = makeDate("2026-04-21T12:00:00Z")
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            id: UUID(),
            name: "Exercise",
            emoji: "🏃",
            interval: 4,
            lastDone: now,
            scheduleAnchor: now
        )
        let todayLog = RoutineLog(timestamp: now, taskID: task.id, kind: .completed)
        let optimisticPastLog = RoutineLog(timestamp: pastCompletion, taskID: task.id, kind: .completed)

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                logs: [todayLog, optimisticPastLog],
                pendingLocalCompletionDates: [pastCompletion],
                selectedDate: calendar.startOfDay(for: pastCompletion),
                isDoneToday: true
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
        }

        await store.send(.logsLoaded([todayLog]))

        let persistedPastLog = RoutineLog(timestamp: pastCompletion, taskID: task.id, kind: .completed)
        await store.send(.logsLoaded([todayLog, persistedPastLog])) {
            $0.logs = [todayLog, persistedPastLog]
            $0.pendingLocalCompletionDates = []
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
            $0.isDoneToday = true
        }
    }

    @Test
    func logsLoaded_preservesPendingLocalUndoDuringStaleReload() async {
        let now = makeDate("2026-06-19T12:00:00Z")
        let calendar = makeTestCalendar()
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
            lastDone: now,
            scheduleAnchor: nil
        )
        let completedLog = RoutineLog(timestamp: now, taskID: task.id, kind: .completed)
        let selectedDay = calendar.startOfDay(for: now)

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                logs: [],
                pendingLocalRemovalDates: [selectedDay],
                selectedDate: selectedDay,
                daysSinceLastRoutine: 0,
                overdueDays: 0,
                isDoneToday: false
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
        }

        await store.send(.logsLoaded([completedLog]))
        #expect(store.state.task.lastDone == now)
        #expect(store.state.logs.isEmpty)
        #expect(!store.state.isDoneToday)
        #expect(!store.state.isSelectedDateDone)
        for item in task.checklistItems {
            #expect(!store.state.isChecklistItemMarkedDone(item))
        }

        await store.send(.logsLoaded([])) {
            $0.task.lastDone = nil
            $0.pendingLocalRemovalDates = []
        }
        #expect(!store.state.isDoneToday)
        #expect(!store.state.isSelectedDateDone)
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
    func markAsDone_confirmsAssumedChecklistCompletionRoutine() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-06-20T08:30:00Z")
        let task = RoutineTask(
            name: "Meals",
            checklistItems: [
                RoutineChecklistItem(title: "Breakfast", intervalDays: 1, createdAt: now),
                RoutineChecklistItem(title: "Lunch", intervalDays: 1, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            recurrenceRule: .interval(days: 1),
            scheduleAnchor: makeDate("2026-06-19T08:00:00Z"),
            createdAt: makeDate("2026-06-19T08:00:00Z"),
            autoAssumeDailyDone: true
        )
        context.insert(task)
        try context.save()

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
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        #expect(store.state.isSelectedDateAssumedDone)
        #expect(!store.state.isCompletionButtonDisabled)
        #expect(store.state.completionButtonAction == TaskDetailFeature.Action.markAsDone)
        #expect(store.state.completionButtonTitle.hasPrefix("Confirm"))

        _ = await store.withExhaustivity(.off) {
            await store.send(TaskDetailFeature.Action.markAsDone) {
                $0.task.lastDone = now
                $0.taskRefreshID = 1
                $0.isDoneToday = true
                $0.isAssumedDoneToday = false
                $0.daysSinceLastRoutine = 0
                $0.overdueDays = 0
                $0.pendingLocalCompletionDates = [now]
            }
        }

        await store.receive {
            guard case let .logsLoaded(logs) = $0 else { return false }
            return logs.contains { $0.kind == RoutineLogKind.completed && $0.timestamp == now }
        } assert: {
            $0.logs = RoutineLogHistory.detailLogs(taskID: task.id, context: context)
            $0.pendingLocalCompletionDates = []
            $0.isDoneToday = true
            $0.isAssumedDoneToday = false
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
        }

        let persistedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        let persistedLogs = RoutineLogHistory.detailLogs(taskID: task.id, context: context)
        #expect(persistedTask.lastDone == now)
        #expect(persistedLogs.contains { $0.kind == RoutineLogKind.completed && $0.timestamp == now })
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

        _ = await store.withExhaustivity(.off) {
            await store.send(.markAsDone) {
                $0.task.lastDone = expectedCompletion
                $0.taskRefreshID = 1
                $0.daysSinceLastRoutine = 1
                $0.pendingLocalCompletionDates = [expectedCompletion]
            }
        }
        #expect(store.state.logs.contains { $0.kind == .completed && $0.timestamp == expectedCompletion })

        await store.receive { action in
            guard case let .logsLoaded(logs) = action else { return false }
            return logs.contains { $0.kind == .completed && $0.timestamp == expectedCompletion }
        } assert: {
            $0.logs = RoutineLogHistory.detailLogs(taskID: task.id, context: context)
            $0.pendingLocalCompletionDates = []
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
    func markAsDone_forTodayOnMissedWeeklyExactTimeRoutineDoesNothing() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-04-24T10:00:00Z")

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

        _ = await store.withExhaustivity(.off) {
            await store.send(.markAsDone)
        }
        #expect(store.state.logs.isEmpty)
        #expect(store.state.task.lastDone == nil)
        #expect(store.state.pendingLocalCompletionDates.isEmpty)

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
        #expect(persistedLogs.isEmpty)
        #expect(scheduledIDs.value.isEmpty)
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
            $0.pendingLocalRemovalDates = [invalidFridayCompletion]
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
            $0.isDoneToday = false
        }

        await store.receive(.logsLoaded([])) {
            $0.pendingLocalRemovalDates = []
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

        #expect(persistedTask.lastDone == nil)
        #expect(persistedTask.scheduleAnchor == makeDate("2026-04-19T10:00:00Z"))
        #expect(persistedLogs.isEmpty)
    }
}
