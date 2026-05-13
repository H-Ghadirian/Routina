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

@MainActor
struct DayPlanPlannerStateTests {
    @Test
    func editVisibleFutureBlockKeepsVisibleWeekAnchored() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let selectedDate = try #require(date("2026-05-03T12:00:00Z"))
        let blockDate = try #require(date("2026-05-07T12:00:00Z"))
        let block = dayPlanBlock(on: blockDate, calendar: calendar)
        let planner = DayPlanPlannerState(selectedDate: selectedDate)
        planner.weekBlocksByDayKey = [
            block.dayKey: [block],
        ]

        let visibleDatesBefore = planner.weekDates(calendar: calendar)

        planner.edit(block, on: blockDate, calendar: calendar, context: context)

        #expect(planner.selectedDate == blockDate)
        #expect(planner.weekDates(calendar: calendar) == visibleDatesBefore)
        #expect(planner.selectedBlockID == block.id)
    }

    @Test
    func resizeVisibleFutureBlockKeepsVisibleWeekAnchored() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let selectedDate = try #require(date("2026-05-03T12:00:00Z"))
        let blockDate = try #require(date("2026-05-07T12:00:00Z"))
        let block = dayPlanBlock(on: blockDate, calendar: calendar)
        let planner = DayPlanPlannerState(selectedDate: selectedDate)
        planner.weekBlocksByDayKey = [
            block.dayKey: [block],
        ]

        let visibleDatesBefore = planner.weekDates(calendar: calendar)
        let didResize = planner.resizeBlock(
            block.id,
            on: blockDate,
            startMinute: block.startMinute,
            durationMinutes: block.durationMinutes + 30,
            calendar: calendar,
            context: context
        )

        #expect(didResize)
        #expect(planner.selectedDate == blockDate)
        #expect(planner.weekDates(calendar: calendar) == visibleDatesBefore)
        #expect(planner.selectedBlock?.durationMinutes == block.durationMinutes + 30)
    }

    @Test
    func persistsBlocksInSwiftData() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let blockDate = try #require(date("2026-05-07T12:00:00Z"))
        let block = dayPlanBlock(on: blockDate, calendar: calendar)

        DayPlanStorage.saveBlocks([block], forDayKey: block.dayKey, context: context)

        let loaded = DayPlanStorage.loadBlocks(forDayKey: block.dayKey, context: context)
        #expect(loaded == [block])

        var descriptor = FetchDescriptor<DayPlanBlockRecord>()
        descriptor.predicate = #Predicate<DayPlanBlockRecord> { record in
            record.id == block.id
        }
        let records = try context.fetch(descriptor)
        #expect(records.count == 1)
    }

    @Test
    func timelineTasksIncludeMissedAndCanceledActivityNotAlreadyPlanned() throws {
        let calendar = gregorianCalendar
        let activityDate = try #require(date("2026-05-07T12:00:00Z"))
        let completedAt = try #require(date("2026-05-07T08:00:00Z"))
        let missedAt = try #require(date("2026-05-07T09:00:00Z"))
        let canceledAt = try #require(date("2026-05-07T10:00:00Z"))
        let completedTaskID = UUID()
        let missedTaskID = UUID()
        let canceledTaskID = UUID()
        let completedTask = RoutineTask(
            id: completedTaskID,
            name: "Already planned",
            scheduleMode: .fixedInterval
        )
        let missedTask = RoutineTask(
            id: missedTaskID,
            name: "Missed call",
            scheduleMode: .fixedInterval
        )
        let canceledTask = RoutineTask(
            id: canceledTaskID,
            name: "Canceled errand",
            scheduleMode: .oneOff,
            canceledAt: canceledAt
        )
        let logs = [
            RoutineLog(
                timestamp: completedAt,
                taskID: completedTaskID,
                kind: .completed
            ),
            RoutineLog(
                timestamp: missedAt,
                taskID: missedTaskID,
                kind: .missed
            ),
            RoutineLog(
                timestamp: canceledAt,
                taskID: canceledTaskID,
                kind: .canceled
            ),
        ]
        let plannedBlock = DayPlanBlock(
            taskID: completedTaskID,
            dayKey: DayPlanStorage.dayKey(for: activityDate, calendar: calendar),
            startMinute: 8 * 60,
            durationMinutes: 60,
            titleSnapshot: "Already planned"
        )

        let tasks = DayPlanTimelineTasks.tasks(
            on: activityDate,
            from: [completedTask, missedTask, canceledTask],
            logs: logs,
            plannedBlocks: [plannedBlock],
            calendar: calendar
        )

        #expect(tasks.map(\.id) == [canceledTaskID, missedTaskID])
    }

    @Test
    func timelineActivityBlocksUseLatestActivityAndExcludePlannedTasks() throws {
        let calendar = gregorianCalendar
        let activityDate = try #require(date("2026-05-07T12:00:00Z"))
        let plannedAt = try #require(date("2026-05-07T08:00:00Z"))
        let olderActivityAt = try #require(date("2026-05-07T09:00:00Z"))
        let latestActivityAt = try #require(date("2026-05-07T09:45:00Z"))
        let canceledAt = try #require(date("2026-05-07T10:15:00Z"))
        let plannedTaskID = UUID()
        let activeTaskID = UUID()
        let canceledTaskID = UUID()
        let plannedTask = RoutineTask(
            id: plannedTaskID,
            name: "Already planned",
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 60
        )
        let activeTask = RoutineTask(
            id: activeTaskID,
            name: "Review inbox",
            emoji: "📬",
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 45
        )
        let canceledTask = RoutineTask(
            id: canceledTaskID,
            name: "Canceled errand",
            scheduleMode: .oneOff,
            canceledAt: canceledAt,
            estimatedDurationMinutes: 35
        )
        let logs = [
            RoutineLog(
                timestamp: plannedAt,
                taskID: plannedTaskID,
                kind: .completed,
                actualDurationMinutes: 20
            ),
            RoutineLog(
                timestamp: olderActivityAt,
                taskID: activeTaskID,
                kind: .missed,
                actualDurationMinutes: 25
            ),
            RoutineLog(
                timestamp: latestActivityAt,
                taskID: activeTaskID,
                kind: .completed,
                actualDurationMinutes: 40
            ),
        ]
        let plannedBlock = DayPlanBlock(
            taskID: plannedTaskID,
            dayKey: DayPlanStorage.dayKey(for: activityDate, calendar: calendar),
            startMinute: 8 * 60,
            durationMinutes: 60,
            titleSnapshot: "Already planned"
        )

        let activityBlocks = DayPlanTimelineTasks.activityBlocks(
            on: activityDate,
            from: [plannedTask, activeTask, canceledTask],
            logs: logs,
            plannedBlocks: [plannedBlock],
            calendar: calendar
        )

        #expect(activityBlocks.map(\.block.taskID) == [activeTaskID, canceledTaskID])
        #expect(activityBlocks.map(\.kind) == [.completed, .canceled])
        #expect(activityBlocks.first?.block.startMinute == 9 * 60 + 5)
        #expect(activityBlocks.first?.block.durationMinutes == 40)
        #expect(activityBlocks.last?.block.durationMinutes == 35)
    }

    @Test
    func completedTimelineActivityBlocksEndAtCompletionAndAvoidRapidCompletionOverlap() throws {
        let calendar = gregorianCalendar
        let activityDate = try #require(date("2026-05-07T12:00:00Z"))
        let firstCompletedAt = try #require(date("2026-05-07T22:10:05Z"))
        let secondCompletedAt = try #require(date("2026-05-07T22:10:40Z"))
        let firstTaskID = UUID()
        let secondTaskID = UUID()
        let firstTask = RoutineTask(
            id: firstTaskID,
            name: "First rapid task",
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 30
        )
        let secondTask = RoutineTask(
            id: secondTaskID,
            name: "Second rapid task",
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 30
        )
        let logs = [
            RoutineLog(
                timestamp: firstCompletedAt,
                taskID: firstTaskID,
                kind: .completed,
                actualDurationMinutes: 30
            ),
            RoutineLog(
                timestamp: secondCompletedAt,
                taskID: secondTaskID,
                kind: .completed,
                actualDurationMinutes: 30
            ),
        ]

        let activityBlocks = DayPlanTimelineTasks.activityBlocks(
            on: activityDate,
            from: [firstTask, secondTask],
            logs: logs,
            plannedBlocks: [],
            calendar: calendar
        )

        #expect(activityBlocks.map(\.block.taskID) == [firstTaskID, secondTaskID])
        #expect(activityBlocks.map(\.block.startMinute) == [21 * 60 + 10, 21 * 60 + 40])
        #expect(activityBlocks.map(\.block.endMinute) == [21 * 60 + 40, 22 * 60 + 10])
    }

    @Test
    func completedTimelineActivityBlocksAvoidExistingPlannerBlocks() throws {
        let calendar = gregorianCalendar
        let activityDate = try #require(date("2026-05-07T12:00:00Z"))
        let completedAt = try #require(date("2026-05-07T22:10:05Z"))
        let taskID = UUID()
        let placedTaskID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Rapid task",
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 30
        )
        let log = RoutineLog(
            timestamp: completedAt,
            taskID: taskID,
            kind: .completed,
            actualDurationMinutes: 30
        )
        let placedBlock = DayPlanBlock(
            taskID: placedTaskID,
            dayKey: DayPlanStorage.dayKey(for: activityDate, calendar: calendar),
            startMinute: 21 * 60 + 40,
            durationMinutes: 30,
            titleSnapshot: "Already placed"
        )

        let activityBlocks = DayPlanTimelineTasks.activityBlocks(
            on: activityDate,
            from: [task],
            logs: [log],
            plannedBlocks: [placedBlock],
            calendar: calendar
        )

        let activityBlock = try #require(activityBlocks.first)
        #expect(activityBlocks.count == 1)
        #expect(activityBlock.block.taskID == taskID)
        #expect(activityBlock.block.startMinute == 21 * 60 + 10)
        #expect(activityBlock.block.endMinute == 21 * 60 + 40)
    }

    @Test
    func confirmedLatestTimelineActivityKeepsEarlierSuggestionBeforeConfirmedBlock() throws {
        let calendar = gregorianCalendar
        let activityDate = try #require(date("2026-05-07T12:00:00Z"))
        let earlierCompletedAt = try #require(date("2026-05-07T22:10:05Z"))
        let latestCompletedAt = try #require(date("2026-05-07T22:10:40Z"))
        let earlierTaskID = UUID()
        let latestTaskID = UUID()
        let earlierTask = RoutineTask(
            id: earlierTaskID,
            name: "Earlier rapid task",
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 30
        )
        let latestTask = RoutineTask(
            id: latestTaskID,
            name: "Latest rapid task",
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 30
        )
        let logs = [
            RoutineLog(
                timestamp: earlierCompletedAt,
                taskID: earlierTaskID,
                kind: .completed,
                actualDurationMinutes: 30
            ),
            RoutineLog(
                timestamp: latestCompletedAt,
                taskID: latestTaskID,
                kind: .completed,
                actualDurationMinutes: 30
            ),
        ]
        let confirmedLatestBlock = DayPlanBlock(
            taskID: latestTaskID,
            dayKey: DayPlanStorage.dayKey(for: activityDate, calendar: calendar),
            startMinute: 21 * 60 + 40,
            durationMinutes: 30,
            titleSnapshot: "Latest rapid task"
        )

        let remainingActivityBlocks = DayPlanTimelineTasks.activityBlocks(
            on: activityDate,
            from: [earlierTask, latestTask],
            logs: logs,
            plannedBlocks: [confirmedLatestBlock],
            calendar: calendar
        )

        let remainingActivityBlock = try #require(remainingActivityBlocks.first)
        #expect(remainingActivityBlocks.map(\.block.taskID) == [earlierTaskID])
        #expect(remainingActivityBlock.block.startMinute == 21 * 60 + 10)
        #expect(remainingActivityBlock.block.endMinute == 21 * 60 + 40)
    }

    @Test
    func confirmingTimelineActivityPersistsPlannerBlockAndHidesAutomaticBlock() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let selectedDate = try #require(date("2026-05-06T12:00:00Z"))
        let activityDate = try #require(date("2026-05-07T12:00:00Z"))
        let completedAt = try #require(date("2026-05-07T12:15:00Z"))
        let task = RoutineTask(
            name: "Review inbox",
            emoji: "📬",
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 45
        )
        let log = RoutineLog(
            timestamp: completedAt,
            taskID: task.id,
            kind: .completed,
            actualDurationMinutes: 40
        )
        let planner = DayPlanPlannerState(selectedDate: selectedDate)
        planner.loadBlocks(calendar: calendar, context: context)
        let activity = try #require(
            DayPlanTimelineTasks.activityBlocks(
                on: activityDate,
                from: [task],
                logs: [log],
                plannedBlocks: [],
                calendar: calendar
            )
            .first
        )

        let didConfirm = planner.confirmTimelineActivity(activity, on: activityDate, calendar: calendar, context: context)
        let didConfirmAgain = planner.confirmTimelineActivity(activity, on: activityDate, calendar: calendar, context: context)

        let dayKey = DayPlanStorage.dayKey(for: activityDate, calendar: calendar)
        let confirmedBlocks = DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context)
        let remainingAutomaticBlocks = DayPlanTimelineTasks.activityBlocks(
            on: activityDate,
            from: [task],
            logs: [log],
            plannedBlocks: confirmedBlocks,
            calendar: calendar
        )

        #expect(didConfirm)
        #expect(didConfirmAgain)
        #expect(confirmedBlocks.count == 1)
        let confirmedBlock = try #require(confirmedBlocks.first)
        #expect(confirmedBlock.id != activity.block.id)
        #expect(confirmedBlock.taskID == task.id)
        #expect(confirmedBlock.dayKey == dayKey)
        #expect(confirmedBlock.startMinute == 11 * 60 + 35)
        #expect(confirmedBlock.durationMinutes == 40)
        #expect(confirmedBlock.titleSnapshot == "Review inbox")
        #expect(confirmedBlock.emojiSnapshot == "📬")
        #expect(planner.selectedDate == activityDate)
        #expect(planner.selectedBlockID == confirmedBlock.id)
        #expect(planner.selectedTaskID == task.id)
        #expect(remainingAutomaticBlocks.isEmpty)
    }

    @Test
    func activeFocusSessionBlocksUseTimerStartAndElapsedDuration() throws {
        let calendar = gregorianCalendar
        let visibleDate = try #require(date("2026-05-07T12:00:00Z"))
        let startedAt = try #require(date("2026-05-07T09:30:00Z"))
        let now = try #require(date("2026-05-07T10:05:00Z"))
        let taskID = UUID()
        let sessionID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Write notes",
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 45
        )
        let session = FocusSession(
            id: sessionID,
            taskID: taskID,
            startedAt: startedAt,
            plannedDurationSeconds: 0
        )

        let focusBlocksByDayKey = DayPlanFocusSessionBlocks.activeBlocksByDayKey(
            on: [visibleDate],
            from: [task],
            sessions: [session],
            now: now,
            calendar: calendar
        )

        let dayKey = DayPlanStorage.dayKey(for: visibleDate, calendar: calendar)
        let focusBlock = try #require(focusBlocksByDayKey[dayKey]?.first)
        #expect(focusBlock.sessionID == sessionID)
        #expect(focusBlock.block.id == sessionID)
        #expect(focusBlock.block.taskID == taskID)
        #expect(focusBlock.block.startMinute == 9 * 60 + 30)
        #expect(focusBlock.durationMinutes == 35)
        #expect(focusBlock.block.durationMinutes == 35)
    }

    @Test
    func activeFocusSessionBlocksClampFutureStartsToCurrentDay() throws {
        let calendar = gregorianCalendar
        let currentDate = try #require(date("2026-05-07T12:00:00Z"))
        let now = try #require(date("2026-05-07T12:36:00Z"))
        let futureStartedAt = try #require(date("2026-05-10T12:36:00Z"))
        let futureDate = try #require(date("2026-05-10T12:00:00Z"))
        let taskID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Write notes",
            scheduleMode: .fixedInterval
        )
        let session = FocusSession(
            taskID: taskID,
            startedAt: futureStartedAt,
            plannedDurationSeconds: 0
        )

        let focusBlocksByDayKey = DayPlanFocusSessionBlocks.activeBlocksByDayKey(
            on: [currentDate, futureDate],
            from: [task],
            sessions: [session],
            now: now,
            calendar: calendar
        )

        let currentDayKey = DayPlanStorage.dayKey(for: currentDate, calendar: calendar)
        let futureDayKey = DayPlanStorage.dayKey(for: futureDate, calendar: calendar)
        let focusBlock = try #require(focusBlocksByDayKey[currentDayKey]?.first)
        #expect(focusBlocksByDayKey[futureDayKey] == nil)
        #expect(focusBlock.block.startMinute == 12 * 60 + 36)
        #expect(focusBlock.durationMinutes == 1)
    }

    @Test
    func activeFocusSessionBlocksClampPreviousDayStartsToCurrentDay() throws {
        let calendar = gregorianCalendar
        let previousDate = try #require(date("2026-05-06T12:00:00Z"))
        let currentDate = try #require(date("2026-05-07T12:00:00Z"))
        let startedAt = try #require(date("2026-05-06T22:30:00Z"))
        let now = try #require(date("2026-05-07T01:15:00Z"))
        let taskID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Write notes",
            scheduleMode: .fixedInterval
        )
        let session = FocusSession(
            taskID: taskID,
            startedAt: startedAt,
            plannedDurationSeconds: 0
        )

        let focusBlocksByDayKey = DayPlanFocusSessionBlocks.activeBlocksByDayKey(
            on: [previousDate, currentDate],
            from: [task],
            sessions: [session],
            now: now,
            calendar: calendar
        )

        let previousDayKey = DayPlanStorage.dayKey(for: previousDate, calendar: calendar)
        let currentDayKey = DayPlanStorage.dayKey(for: currentDate, calendar: calendar)
        let focusBlock = try #require(focusBlocksByDayKey[currentDayKey]?.first)
        #expect(focusBlocksByDayKey[previousDayKey] == nil)
        #expect(focusBlock.block.startMinute == 0)
        #expect(focusBlock.durationMinutes == 75)
    }

    @Test
    func activeFocusSessionBlocksExcludeFinishedAndUnknownTaskSessions() throws {
        let calendar = gregorianCalendar
        let visibleDate = try #require(date("2026-05-07T12:00:00Z"))
        let startedAt = try #require(date("2026-05-07T09:30:00Z"))
        let finishedAt = try #require(date("2026-05-07T10:05:00Z"))
        let taskID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Write notes",
            scheduleMode: .fixedInterval
        )
        let sessions = [
            FocusSession(
                taskID: taskID,
                startedAt: startedAt,
                completedAt: finishedAt
            ),
            FocusSession(
                taskID: taskID,
                startedAt: startedAt,
                abandonedAt: finishedAt
            ),
            FocusSession(
                taskID: UUID(),
                startedAt: startedAt
            ),
        ]

        let focusBlocksByDayKey = DayPlanFocusSessionBlocks.activeBlocksByDayKey(
            on: [visibleDate],
            from: [task],
            sessions: sessions,
            now: finishedAt,
            calendar: calendar
        )

        #expect(focusBlocksByDayKey.isEmpty)
    }

    @Test
    func sleepBlocksSplitOvernightSessionsByVisibleDay() throws {
        let calendar = gregorianCalendar
        let previousDate = try #require(date("2026-05-09T12:00:00Z"))
        let nextDate = try #require(date("2026-05-10T12:00:00Z"))
        let startedAt = try #require(date("2026-05-09T22:30:00Z"))
        let endedAt = try #require(date("2026-05-10T06:45:00Z"))
        let session = SleepSession(startedAt: startedAt, endedAt: endedAt)

        let sleepBlocksByDayKey = DayPlanSleepBlocks.blocksByDayKey(
            on: [previousDate, nextDate],
            from: [session],
            referenceDate: endedAt,
            calendar: calendar
        )

        let previousDayKey = DayPlanStorage.dayKey(for: previousDate, calendar: calendar)
        let nextDayKey = DayPlanStorage.dayKey(for: nextDate, calendar: calendar)
        let previousBlock = try #require(sleepBlocksByDayKey[previousDayKey]?.first)
        let nextBlock = try #require(sleepBlocksByDayKey[nextDayKey]?.first)
        #expect(previousBlock.sessionID == session.id)
        #expect(previousBlock.block.startMinute == 22 * 60 + 30)
        #expect(previousBlock.block.durationMinutes == 90)
        #expect(nextBlock.block.startMinute == 0)
        #expect(nextBlock.block.durationMinutes == 6 * 60 + 45)
    }

    @Test
    func sleepBlockedIntervalsRejectOverlappingPlannerTimes() throws {
        let calendar = gregorianCalendar
        let previousDate = try #require(date("2026-05-09T12:00:00Z"))
        let nextDate = try #require(date("2026-05-10T12:00:00Z"))
        let startedAt = try #require(date("2026-05-09T22:30:00Z"))
        let endedAt = try #require(date("2026-05-10T06:45:00Z"))
        let session = SleepSession(startedAt: startedAt, endedAt: endedAt)

        let previousConflict = DayPlanSleepBlocks.conflictingInterval(
            on: previousDate,
            from: [session],
            startMinute: 23 * 60,
            durationMinutes: 30,
            referenceDate: endedAt,
            calendar: calendar
        )
        let previousOpenSlot = DayPlanSleepBlocks.conflictingInterval(
            on: previousDate,
            from: [session],
            startMinute: 21 * 60,
            durationMinutes: 30,
            referenceDate: endedAt,
            calendar: calendar
        )
        let nextConflict = DayPlanSleepBlocks.conflictingInterval(
            on: nextDate,
            from: [session],
            startMinute: 6 * 60 + 30,
            durationMinutes: 30,
            referenceDate: endedAt,
            calendar: calendar
        )

        #expect(previousConflict?.title == "Sleep")
        #expect(previousOpenSlot == nil)
        #expect(nextConflict?.title == "Sleep")
    }

    @Test
    func movingTimelineActivityUpdatesLogAndTaskCompletionDate() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let originalTimestamp = try #require(date("2026-05-07T09:45:00Z"))
        let targetDate = try #require(date("2026-05-08T12:00:00Z"))
        let task = RoutineTask(
            name: "Review inbox",
            scheduleMode: .fixedInterval,
            lastDone: originalTimestamp,
            estimatedDurationMinutes: 40
        )
        let log = RoutineLog(
            timestamp: originalTimestamp,
            taskID: task.id,
            kind: .completed,
            actualDurationMinutes: 40
        )
        context.insert(task)
        context.insert(log)
        try context.save()

        let activity = try #require(
            DayPlanTimelineTasks.activityBlocks(
                on: originalTimestamp,
                from: [task],
                logs: [log],
                plannedBlocks: [],
                calendar: calendar
            )
            .first
        )

        let didMove = DayPlanTimelineTasks.moveActivity(
            activity,
            to: targetDate,
            startMinute: 11 * 60 + 15,
            tasks: [task],
            logs: [log],
            context: context,
            calendar: calendar
        )

        let expectedTimestamp = try #require(date("2026-05-08T11:15:00Z"))
        #expect(didMove)
        #expect(log.timestamp == expectedTimestamp)
        #expect(task.lastDone == expectedTimestamp)
    }

    @Test
    func movingOlderTimelineCompletionDoesNotLowerLatestTaskCompletionDate() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let originalTimestamp = try #require(date("2026-05-07T09:45:00Z"))
        let latestTimestamp = try #require(date("2026-05-09T14:00:00Z"))
        let targetDate = try #require(date("2026-05-08T12:00:00Z"))
        let task = RoutineTask(
            name: "Review inbox",
            scheduleMode: .fixedInterval,
            lastDone: latestTimestamp,
            estimatedDurationMinutes: 40
        )
        let log = RoutineLog(
            timestamp: originalTimestamp,
            taskID: task.id,
            kind: .completed,
            actualDurationMinutes: 40
        )
        context.insert(task)
        context.insert(log)
        try context.save()

        let activity = try #require(
            DayPlanTimelineTasks.activityBlocks(
                on: originalTimestamp,
                from: [task],
                logs: [log],
                plannedBlocks: [],
                calendar: calendar
            )
            .first
        )

        let didMove = DayPlanTimelineTasks.moveActivity(
            activity,
            to: targetDate,
            startMinute: 11 * 60 + 15,
            tasks: [task],
            logs: [log],
            context: context,
            calendar: calendar
        )

        let expectedMovedTimestamp = try #require(date("2026-05-08T11:15:00Z"))
        #expect(didMove)
        #expect(log.timestamp == expectedMovedTimestamp)
        #expect(task.lastDone == latestTimestamp)
    }

    @Test
    func movingLegacyTimelineActivityCreatesMatchingLog() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let originalTimestamp = try #require(date("2026-05-07T09:45:00Z"))
        let targetDate = try #require(date("2026-05-08T12:00:00Z"))
        let task = RoutineTask(
            name: "Legacy completion",
            scheduleMode: .fixedInterval,
            lastDone: originalTimestamp,
            estimatedDurationMinutes: 40
        )
        context.insert(task)
        try context.save()

        let activity = try #require(
            DayPlanTimelineTasks.activityBlocks(
                on: originalTimestamp,
                from: [task],
                logs: [],
                plannedBlocks: [],
                calendar: calendar
            )
            .first
        )

        let didMove = DayPlanTimelineTasks.moveActivity(
            activity,
            to: targetDate,
            startMinute: 11 * 60 + 15,
            tasks: [task],
            logs: [],
            context: context,
            calendar: calendar
        )

        let expectedTimestamp = try #require(date("2026-05-08T11:15:00Z"))
        let taskID = task.id
        let persistedLogs = try context.fetch(
            FetchDescriptor<RoutineLog>(
                predicate: #Predicate<RoutineLog> { log in
                    log.taskID == taskID
                }
            )
        )
        #expect(didMove)
        #expect(task.lastDone == expectedTimestamp)
        #expect(persistedLogs.count == 1)
        #expect(persistedLogs.first?.kind == .completed)
        #expect(persistedLogs.first?.timestamp == expectedTimestamp)
    }

    @Test
    func dropTargetTreatsTimeGutterAsFirstDayColumn() throws {
        let dates = try plannerDates()

        let target = DayPlanDropTargetResolver.target(
            for: CGPoint(x: 20, y: 9.2 * 64),
            dates: dates,
            dayWidth: 120,
            timeColumnWidth: 64,
            hourHeight: 64
        )

        #expect(target?.dayIndex == 0)
        #expect(target?.date == dates[0])
        #expect(target?.startMinute == 9 * 60)
    }

    @Test
    func dropTargetMapsColumnsAndSnapsToQuarterHour() throws {
        let dates = try plannerDates()

        let target = DayPlanDropTargetResolver.target(
            for: CGPoint(x: 64 + (2 * 120) + 10, y: 2.6 * 64),
            dates: dates,
            dayWidth: 120,
            timeColumnWidth: 64,
            hourHeight: 64
        )

        #expect(target?.dayIndex == 2)
        #expect(target?.date == dates[2])
        #expect(target?.startMinute == 2 * 60 + 30)
    }

    @Test
    func dropTargetRejectsEmptyDates() {
        let target = DayPlanDropTargetResolver.target(
            for: CGPoint(x: 20, y: 20),
            dates: [],
            dayWidth: 120,
            timeColumnWidth: 64,
            hourHeight: 64
        )

        #expect(target == nil)
    }
}

private let gregorianCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

private func date(_ string: String) -> Date? {
    ISO8601DateFormatter().date(from: string)
}

private func plannerDates() throws -> [Date] {
    try [
        #require(date("2026-05-09T12:00:00Z")),
        #require(date("2026-05-10T12:00:00Z")),
        #require(date("2026-05-11T12:00:00Z")),
        #require(date("2026-05-12T12:00:00Z")),
    ]
}

private func dayPlanBlock(on date: Date, calendar: Calendar) -> DayPlanBlock {
    DayPlanBlock(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
        taskID: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
        dayKey: DayPlanStorage.dayKey(for: date, calendar: calendar),
        startMinute: 18 * 60 + 30,
        durationMinutes: 90,
        titleSnapshot: "Group session",
        emojiSnapshot: "✨",
        createdAt: date,
        updatedAt: date
    )
}
