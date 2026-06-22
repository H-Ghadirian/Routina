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
    func dayModeShowsOnlySelectedDate() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let selectedDate = try #require(date("2026-05-03T12:00:00Z"))
        let planner = DayPlanPlannerState(selectedDate: selectedDate)

        planner.setVisibleRangeMode(.day, calendar: calendar, context: context)

        #expect(planner.visibleRangeMode == .day)
        #expect(planner.visibleDates(calendar: calendar) == [calendar.startOfDay(for: selectedDate)])
    }

    @Test
    func dayModeNavigationMovesOneDay() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let selectedDate = try #require(date("2026-05-03T12:00:00Z"))
        let expectedSelectedDate = try #require(date("2026-05-04T12:00:00Z"))
        let expectedVisibleDate = try #require(date("2026-05-04T00:00:00Z"))
        let planner = DayPlanPlannerState(selectedDate: selectedDate, visibleRangeMode: .day)

        planner.moveVisibleRange(by: 1, calendar: calendar, context: context)

        #expect(planner.selectedDate == expectedSelectedDate)
        #expect(planner.visibleDates(calendar: calendar) == [expectedVisibleDate])
    }

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
    func resizingPlannerBlockKeepsHandlesOutsideChangingCardContent() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let calendarSource = try String(
            contentsOf: projectRoot.appendingPathComponent("SharedCore/Views/DayPlan/DayPlanWeekCalendarView.swift"),
            encoding: .utf8
        )
        let blockLayerSource = try String(
            contentsOf: projectRoot.appendingPathComponent("SharedCore/Views/DayPlan/DayPlanBlockLayer.swift"),
            encoding: .utf8
        )

        #expect(calendarSource.contains("resizingContentLayoutHeight: resizeSession?.contentLayoutHeight"))
        #expect(calendarSource.contains("contentLayoutHeight: blockHeight(forDurationMinutes: block.durationMinutes)"))
        #expect(blockLayerSource.contains("renderedHeight: blockHeight"))
        #expect(blockLayerSource.contains("contentLayoutHeight: contentLayoutHeight(for: block)"))
        #expect(blockLayerSource.contains("showsResizeHandles: false"))
        #expect(blockLayerSource.contains(".clipped(antialiased: true)"))
        #expect(blockLayerSource.contains("resizeHandle(for: block, date: date, edge: .top, blockHeight: blockHeight)"))
        #expect(blockLayerSource.contains("resizeHandle(for: block, date: date, edge: .bottom, blockHeight: blockHeight)"))
    }

    @Test
    func smallPlannerBlocksKeepMoveDragAreaBetweenResizeHandles() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let resizeHandleSource = try String(
            contentsOf: projectRoot.appendingPathComponent("SharedCore/Views/DayPlan/DayPlanResizeHandle.swift"),
            encoding: .utf8
        )
        let blockLayerSource = try String(
            contentsOf: projectRoot.appendingPathComponent("SharedCore/Views/DayPlan/DayPlanBlockLayer.swift"),
            encoding: .utf8
        )

        #expect(resizeHandleSource.contains("var hitHeight: CGFloat = 16"))
        #expect(resizeHandleSource.contains(".frame(height: hitHeight)"))
        #expect(blockLayerSource.contains("let minimumMoveDragArea: CGFloat = 8"))
        #expect(blockLayerSource.contains("return max(5, (blockHeight - minimumMoveDragArea) / 2)"))
        #expect(blockLayerSource.contains("outwardOverlap: resizeHandleOutwardOverlap(forHitHeight: hitHeight)"))
    }

    @Test
    func focusSleepSessionSelectsStartDayAndScrollMinute() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let selectedDate = try #require(date("2026-05-03T12:00:00Z"))
        let startedAt = try #require(date("2026-05-07T22:30:00Z"))
        let endedAt = try #require(date("2026-05-08T06:45:00Z"))
        let sleepID = UUID()
        let planner = DayPlanPlannerState(selectedDate: selectedDate)
        planner.selectedTaskID = UUID()
        planner.selectedBlockID = UUID()
        planner.focusedUnplannedCompletedDate = selectedDate

        planner.focusSleepSession(
            SleepSession(id: sleepID, startedAt: startedAt, endedAt: endedAt),
            calendar: calendar,
            context: context
        )

        #expect(planner.selectedDate == calendar.startOfDay(for: startedAt))
        #expect(planner.weekDates(calendar: calendar).contains(where: { calendar.isDate($0, inSameDayAs: startedAt) }))
        #expect(planner.selectedTaskID == nil)
        #expect(planner.selectedBlockID == nil)
        #expect(planner.focusedUnplannedCompletedDate == nil)
        #expect(planner.startMinute == 22 * 60 + 30)
        #expect(planner.focusedSleep?.sessionID == sleepID)
        #expect(planner.focusedSleep?.startMinute == 22 * 60 + 30)
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
    func visiblePlannerBlocksHideCanceledAndMissedTasks() throws {
        let calendar = gregorianCalendar
        let blockDate = try #require(date("2026-05-07T12:00:00Z"))
        let canceledAt = try #require(date("2026-05-07T10:00:00Z"))
        let missedAt = try #require(date("2026-05-07T11:00:00Z"))
        let activeTaskID = UUID()
        let canceledTaskID = UUID()
        let missedTaskID = UUID()
        let activeTask = RoutineTask(
            id: activeTaskID,
            name: "Still planned",
            scheduleMode: .oneOff
        )
        let canceledTask = RoutineTask(
            id: canceledTaskID,
            name: "Canceled errand",
            scheduleMode: .oneOff,
            canceledAt: canceledAt
        )
        let missedTask = RoutineTask(
            id: missedTaskID,
            name: "Missed call",
            scheduleMode: .fixedInterval
        )
        let blocks = [
            plannerBlock(taskID: activeTaskID, title: "Still planned", on: blockDate, calendar: calendar),
            plannerBlock(taskID: canceledTaskID, title: "Canceled errand", on: blockDate, calendar: calendar),
            plannerBlock(taskID: missedTaskID, title: "Missed call", on: blockDate, calendar: calendar),
        ]
        let logs = [
            RoutineLog(
                timestamp: missedAt,
                taskID: missedTaskID,
                kind: .missed
            ),
        ]

        let visibleBlocks = DayPlanVisibleBlocks.blocks(
            blocks,
            tasks: [activeTask, canceledTask, missedTask],
            logs: logs,
            calendar: calendar
        )

        #expect(visibleBlocks.map(\.taskID) == [activeTaskID])
    }

    @Test
    func visiblePlannerBlocksKeepCompletedAndDifferentDayOutcomes() throws {
        let calendar = gregorianCalendar
        let blockDate = try #require(date("2026-05-07T12:00:00Z"))
        let completedAt = try #require(date("2026-05-07T10:00:00Z"))
        let missedOnDifferentDay = try #require(date("2026-05-08T11:00:00Z"))
        let completedTaskID = UUID()
        let missedTomorrowTaskID = UUID()
        let completedTask = RoutineTask(
            id: completedTaskID,
            name: "Done later",
            scheduleMode: .fixedInterval
        )
        let missedTomorrowTask = RoutineTask(
            id: missedTomorrowTaskID,
            name: "Missed tomorrow",
            scheduleMode: .fixedInterval
        )
        let blocks = [
            plannerBlock(taskID: completedTaskID, title: "Done later", on: blockDate, calendar: calendar),
            plannerBlock(taskID: missedTomorrowTaskID, title: "Missed tomorrow", on: blockDate, calendar: calendar),
        ]
        let logs = [
            RoutineLog(
                timestamp: completedAt,
                taskID: completedTaskID,
                kind: .completed
            ),
            RoutineLog(
                timestamp: missedOnDifferentDay,
                taskID: missedTomorrowTaskID,
                kind: .missed
            ),
        ]

        let visibleBlocks = DayPlanVisibleBlocks.blocks(
            blocks,
            tasks: [completedTask, missedTomorrowTask],
            logs: logs,
            calendar: calendar
        )

        #expect(visibleBlocks.map(\.taskID) == [completedTaskID, missedTomorrowTaskID])
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
    func automaticPlannerSuggestionsLinkIntoOverlappingAwayBlocks() throws {
        let calendar = gregorianCalendar
        let activityDate = try #require(date("2026-06-04T12:00:00Z"))
        let awayStartedAt = try #require(date("2026-06-04T17:40:00Z"))
        let awayCompletedAt = try #require(date("2026-06-04T19:05:00Z"))
        let exerciseCompletedAt = try #require(date("2026-06-04T19:55:00Z"))
        let taskID = UUID()
        let exercise = RoutineTask(
            id: taskID,
            name: "Exercise",
            emoji: "🏃",
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 60
        )
        let logs = [
            RoutineLog(
                timestamp: exerciseCompletedAt,
                taskID: taskID,
                kind: .completed,
                actualDurationMinutes: 60
            ),
        ]
        let awaySession = AwaySession(
            preset: .custom,
            startedAt: awayStartedAt,
            plannedDurationSeconds: 85 * 60,
            completedAt: awayCompletedAt
        )
        let awayBlocksByDayKey = DayPlanAwayBlocks.blocksByDayKey(
            on: [activityDate],
            from: [awaySession],
            referenceDate: awayCompletedAt,
            calendar: calendar
        )
        let rawSuggestionsByDayKey = DayPlanTimelineTasks.automaticSuggestionBlocksByDayKey(
            on: [activityDate],
            from: [exercise],
            logs: logs,
            plannedBlocksByDayKey: [:],
            calendar: calendar
        )
        let blockedIntervalsByDayKey = awayBlocksByDayKey.mapValues { blocks in
            blocks.map(\.interval)
        }

        let linkedAwayBlocksByDayKey = DayPlanAwayBlocks.linkedBlocksByDayKey(
            awayBlocksByDayKey,
            timelineActivitiesByDayKey: rawSuggestionsByDayKey
        )
        let visibleSuggestionsByDayKey = DayPlanTimelineTasks.automaticSuggestionBlocksByDayKey(
            on: [activityDate],
            from: [exercise],
            logs: logs,
            plannedBlocksByDayKey: [:],
            blockedIntervalsByDayKey: blockedIntervalsByDayKey,
            calendar: calendar
        )

        let dayKey = DayPlanStorage.dayKey(for: activityDate, calendar: calendar)
        let linkedAwayBlock = try #require(linkedAwayBlocksByDayKey[dayKey]?.first)
        #expect(rawSuggestionsByDayKey[dayKey]?.map(\.block.titleSnapshot) == ["Exercise"])
        #expect(linkedAwayBlock.block.titleSnapshot == "Away · Exercise")
        #expect(linkedAwayBlock.block.emojiSnapshot == "🏃")
        #expect(linkedAwayBlock.linkedActivityTitles == ["Exercise"])
        #expect(visibleSuggestionsByDayKey[dayKey]?.isEmpty ?? true)
    }

    @Test
    func automaticPlannerSuggestionsExcludeMissedAndCanceledActivity() throws {
        let calendar = gregorianCalendar
        let activityDate = try #require(date("2026-05-07T12:00:00Z"))
        let completedAt = try #require(date("2026-05-07T08:00:00Z"))
        let missedAt = try #require(date("2026-05-07T09:00:00Z"))
        let canceledAt = try #require(date("2026-05-07T10:00:00Z"))
        let legacyCanceledAt = try #require(date("2026-05-07T11:00:00Z"))
        let completedTaskID = UUID()
        let missedTaskID = UUID()
        let canceledTaskID = UUID()
        let legacyCanceledTaskID = UUID()
        let completedTask = RoutineTask(
            id: completedTaskID,
            name: "Completed task",
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 30
        )
        let missedTask = RoutineTask(
            id: missedTaskID,
            name: "Missed task",
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 30
        )
        let canceledTask = RoutineTask(
            id: canceledTaskID,
            name: "Canceled task",
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 30
        )
        let legacyCanceledTask = RoutineTask(
            id: legacyCanceledTaskID,
            name: "Legacy canceled task",
            scheduleMode: .oneOff,
            canceledAt: legacyCanceledAt,
            estimatedDurationMinutes: 30
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

        let suggestions = DayPlanTimelineTasks.automaticSuggestionBlocks(
            on: activityDate,
            from: [completedTask, missedTask, canceledTask, legacyCanceledTask],
            logs: logs,
            plannedBlocks: [],
            calendar: calendar
        )

        #expect(suggestions.map(\.block.taskID) == [completedTaskID])
        #expect(suggestions.map(\.kind) == [.completed])
    }

    @Test
    func automaticPlannerSuggestionsExcludeAllDayTasks() throws {
        let calendar = gregorianCalendar
        let activityDate = try #require(date("2026-05-07T12:00:00Z"))
        let completedAt = try #require(date("2026-05-07T09:45:00Z"))
        let taskID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Travel",
            isAllDay: true,
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 30
        )
        let logs = [
            RoutineLog(
                timestamp: completedAt,
                taskID: taskID,
                kind: .completed,
                actualDurationMinutes: 30
            ),
        ]

        let suggestions = DayPlanTimelineTasks.automaticSuggestionBlocks(
            on: activityDate,
            from: [task],
            logs: logs,
            plannedBlocks: [],
            calendar: calendar
        )

        #expect(suggestions.isEmpty)
    }

    @Test
    func hiddenTimelineActivityBlocksAreExcludedFromAutomaticPlannerSuggestions() throws {
        let calendar = gregorianCalendar
        let activityDate = try #require(date("2026-05-07T12:00:00Z"))
        let completedAt = try #require(date("2026-05-07T09:45:00Z"))
        let taskID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Review inbox",
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 30
        )
        let logs = [
            RoutineLog(
                timestamp: completedAt,
                taskID: taskID,
                kind: .completed,
                actualDurationMinutes: 30
            ),
        ]
        let visibleBlocks = DayPlanTimelineTasks.automaticSuggestionBlocks(
            on: activityDate,
            from: [task],
            logs: logs,
            plannedBlocks: [],
            calendar: calendar
        )
        let visibleBlock = try #require(visibleBlocks.first)
        let hiddenStorage = DayPlanHiddenTimelineActivityStore.storageString(
            afterHiding: visibleBlock,
            in: nil
        )
        let hiddenIDs = DayPlanHiddenTimelineActivityStore.hiddenIDs(from: hiddenStorage)

        let hiddenBlocks = DayPlanTimelineTasks.automaticSuggestionBlocks(
            on: activityDate,
            from: [task],
            logs: logs,
            plannedBlocks: [],
            calendar: calendar,
            hiddenActivityIDs: hiddenIDs
        )
        let hiddenTasks = DayPlanTimelineTasks.tasks(
            on: activityDate,
            from: [task],
            logs: logs,
            plannedBlocks: [],
            calendar: calendar,
            hiddenActivityIDs: hiddenIDs
        )

        #expect(hiddenBlocks.isEmpty)
        #expect(hiddenTasks.isEmpty)
        #expect(
            DayPlanTimelineTasks.count(
                on: activityDate,
                tasks: [task],
                logs: logs,
                plannedBlocks: [],
                calendar: calendar,
                hiddenActivityIDs: hiddenIDs
            ) == 0
        )
    }

    @Test
    func allDayBlocksUseImportedCalendarMetadataAcrossVisibleDates() throws {
        let calendar = gregorianCalendar
        let startDate = try #require(date("2026-05-10T00:00:00Z"))
        let endDate = try #require(date("2026-05-13T00:00:00Z"))
        let taskID = UUID()
        let suggestion = CalendarTaskSuggestion(
            id: "outlook:travel",
            eventIdentifier: "outlook:travel",
            calendarIdentifier: "outlook",
            calendarTitle: "Outlook",
            eventTitle: "Travel",
            eventStartDate: startDate,
            eventEndDate: endDate,
            isAllDay: true,
            taskTitle: "Travel",
            deadline: startDate,
            reviewState: .pending
        )
        let task = RoutineTask(
            id: taskID,
            name: "Travel",
            emoji: "✈️",
            notes: CalendarTaskImportSupport.notes(for: suggestion, calendar: calendar),
            deadline: startDate,
            scheduleMode: .oneOff
        )

        let blocks = DayPlanAllDayTasks.blocks(
            on: try plannerDates(),
            from: [task],
            calendar: calendar
        )

        #expect(blocks.compactMap(\.taskID) == [taskID])
        #expect(blocks.first?.title == "Travel")
        #expect(blocks.first?.startDate == startDate)
        #expect(blocks.first?.endDate == endDate)
        #expect(blocks.first?.isLegacyDateOnlyCalendarTask == false)
    }

    @Test
    func allDayBlocksTreatLegacyDateOnlyCalendarTasksAsSingleDayEvents() throws {
        let calendar = gregorianCalendar
        let deadline = try #require(date("2026-05-11T00:00:00Z"))
        let expectedEnd = try #require(date("2026-05-12T00:00:00Z"))
        let taskID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Sick day",
            emoji: "🤒",
            notes: """
            Imported from Outlook.
            Calendar event: outlook:sick-day
            """,
            deadline: deadline,
            scheduleMode: .oneOff
        )

        let blocks = DayPlanAllDayTasks.blocks(
            on: try plannerDates(),
            from: [task],
            calendar: calendar
        )

        #expect(blocks.compactMap(\.taskID) == [taskID])
        #expect(blocks.first?.startDate == deadline)
        #expect(blocks.first?.endDate == expectedEnd)
        #expect(blocks.first?.isLegacyDateOnlyCalendarTask == true)
    }

    @Test
    func allDayBlocksUseManualAllDayTaskFlag() throws {
        let calendar = gregorianCalendar
        let deadline = try #require(date("2026-05-11T15:30:00Z"))
        let expectedStart = try #require(date("2026-05-11T00:00:00Z"))
        let expectedEnd = try #require(date("2026-05-12T00:00:00Z"))
        let taskID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Conference",
            emoji: "🎟️",
            deadline: deadline,
            isAllDay: true,
            scheduleMode: .oneOff
        )

        let blocks = DayPlanAllDayTasks.blocks(
            on: try plannerDates(),
            from: [task],
            calendar: calendar
        )

        #expect(blocks.compactMap(\.taskID) == [taskID])
        #expect(blocks.first?.startDate == expectedStart)
        #expect(blocks.first?.endDate == expectedEnd)
        #expect(blocks.first?.isLegacyDateOnlyCalendarTask == false)
    }

    @Test
    func allDayBlocksUseTodoAvailabilityDateWithoutDeadline() throws {
        let calendar = gregorianCalendar
        let availabilityDate = try #require(date("2026-05-11T15:30:00Z"))
        let expectedStart = try #require(date("2026-05-11T00:00:00Z"))
        let expectedEnd = try #require(date("2026-05-12T00:00:00Z"))
        let taskID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Conference",
            emoji: "🎟️",
            isAllDay: true,
            availabilityStartDate: availabilityDate,
            scheduleMode: .oneOff
        )

        let blocks = DayPlanAllDayTasks.blocks(
            on: try plannerDates(),
            from: [task],
            calendar: calendar
        )

        #expect(blocks.compactMap(\.taskID) == [taskID])
        #expect(blocks.first?.startDate == expectedStart)
        #expect(blocks.first?.endDate == expectedEnd)
        #expect(blocks.first?.isLegacyDateOnlyCalendarTask == false)
    }

    @Test
    func allDayBlocksUseTodoAvailabilityDateWindowWithoutDeadline() throws {
        let calendar = gregorianCalendar
        let availabilityStartDate = try #require(date("2026-05-10T09:00:00Z"))
        let availabilityEndDate = try #require(date("2026-05-12T18:00:00Z"))
        let expectedStarts = try [
            #require(date("2026-05-10T00:00:00Z")),
            #require(date("2026-05-11T00:00:00Z")),
            #require(date("2026-05-12T00:00:00Z")),
        ]
        let taskID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Conference",
            emoji: "🎟️",
            isAllDay: true,
            availabilityStartDate: availabilityStartDate,
            availabilityEndDate: availabilityEndDate,
            scheduleMode: .oneOff
        )

        let blocks = DayPlanAllDayTasks.blocks(
            on: try plannerDates(),
            from: [task],
            calendar: calendar
        )

        #expect(blocks.compactMap(\.taskID) == [taskID, taskID, taskID])
        #expect(blocks.map(\.startDate) == expectedStarts)
        #expect(blocks.allSatisfy { !$0.isLegacyDateOnlyCalendarTask })
    }

    @Test
    func allDayBlocksUseManualAllDayRoutineFlagOnOccurrenceDates() throws {
        let calendar = gregorianCalendar
        let occurrence = try #require(date("2026-05-11T12:00:00Z"))
        let expectedStart = try #require(date("2026-05-11T00:00:00Z"))
        let expectedEnd = try #require(date("2026-05-12T00:00:00Z"))
        let taskID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Studio day",
            emoji: "🎨",
            isAllDay: true,
            scheduleMode: .fixedInterval,
            recurrenceRule: .weekly(
                on: calendar.component(.weekday, from: occurrence)
            )
        )

        let blocks = DayPlanAllDayTasks.blocks(
            on: try plannerDates(),
            from: [task],
            calendar: calendar
        )

        #expect(blocks.compactMap(\.taskID) == [taskID])
        #expect(blocks.first?.startDate == expectedStart)
        #expect(blocks.first?.endDate == expectedEnd)
        #expect(blocks.first?.isLegacyDateOnlyCalendarTask == false)
    }

    @Test
    func allDayBlocksKeepMultiDayRoutineOccurrencesOneDayWide() throws {
        let calendar = gregorianCalendar
        let occurrence = try #require(date("2026-05-11T12:00:00Z"))
        let expectedStart = try #require(date("2026-05-11T00:00:00Z"))
        let expectedEnd = try #require(date("2026-05-12T00:00:00Z"))
        let taskID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Travel",
            emoji: "✈️",
            isAllDay: true,
            routineDurationMode: .multiDay,
            scheduleMode: .fixedInterval,
            recurrenceRule: .weekly(
                on: calendar.component(.weekday, from: occurrence)
            )
        )

        let blocks = DayPlanAllDayTasks.blocks(
            on: try plannerDates(),
            from: [task],
            calendar: calendar
        )

        #expect(blocks.compactMap(\.taskID) == [taskID])
        #expect(blocks.first?.startDate == expectedStart)
        #expect(blocks.first?.endDate == expectedEnd)
        #expect(blocks.first?.isLegacyDateOnlyCalendarTask == false)
    }

    @Test
    func allDayBlocksUseCompletedActivityDatesForAllDayRoutines() throws {
        let calendar = gregorianCalendar
        let completedAt = try #require(date("2026-05-11T14:30:00Z"))
        let expectedStart = try #require(date("2026-05-11T00:00:00Z"))
        let expectedEnd = try #require(date("2026-05-12T00:00:00Z"))
        let taskID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Travel",
            isAllDay: true,
            scheduleMode: .fixedInterval,
            recurrenceRule: .monthly(on: 30)
        )
        let logs = [
            RoutineLog(
                timestamp: completedAt,
                taskID: taskID,
                kind: .completed
            ),
        ]

        let blocks = DayPlanAllDayTasks.blocks(
            on: try plannerDates(),
            from: [task],
            logs: logs,
            calendar: calendar
        )

        #expect(blocks.compactMap(\.taskID) == [taskID])
        #expect(blocks.first?.startDate == expectedStart)
        #expect(blocks.first?.endDate == expectedEnd)
        #expect(blocks.first?.isLegacyDateOnlyCalendarTask == false)
    }

    @Test
    func allDayRoutinesDoNotCreateTimedPlannerBlocks() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let occurrence = try #require(date("2026-05-11T12:00:00Z"))
        let task = RoutineTask(
            name: "Studio day",
            isAllDay: true,
            scheduleMode: .fixedInterval,
            recurrenceRule: .weekly(
                on: calendar.component(.weekday, from: occurrence),
                at: RoutineTimeOfDay(hour: 9, minute: 0)
            )
        )
        context.insert(task)
        try context.save()
        let planner = DayPlanPlannerState(selectedDate: occurrence)

        planner.showExactTimedTasks(
            from: [task],
            calendar: calendar,
            context: context
        )

        let timedBlocks = planner.weekBlocksByDayKey.values.flatMap { $0 }
        #expect(timedBlocks.isEmpty)
    }

    @Test
    func exactTimedRoutineUsesShortEstimateForPlannerBlockDuration() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let occurrence = try #require(date("2026-05-11T12:00:00Z"))
        let taskID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Brush teeth",
            emoji: "✨",
            scheduleMode: .fixedInterval,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 21, minute: 0)),
            estimatedDurationMinutes: 5
        )
        context.insert(task)
        try context.save()
        let planner = DayPlanPlannerState(selectedDate: occurrence)

        planner.showExactTimedTasks(
            from: [task],
            calendar: calendar,
            context: context
        )

        let block = try #require(planner.weekBlocksByDayKey.values.flatMap { $0 }.first)
        #expect(block.taskID == taskID)
        #expect(block.startMinute == 21 * 60)
        #expect(block.durationMinutes == 5)
    }

    @Test
    func exactTimedRoutineRefreshesStaleDefaultDurationWhenEstimateChanges() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let occurrence = try #require(date("2026-05-11T12:00:00Z"))
        let dayKey = DayPlanStorage.dayKey(for: occurrence, calendar: calendar)
        let blockID = UUID()
        let taskID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Brush teeth",
            emoji: "✨",
            scheduleMode: .fixedInterval,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 21, minute: 0)),
            estimatedDurationMinutes: 5
        )
        let staleBlock = DayPlanBlock(
            id: blockID,
            taskID: taskID,
            dayKey: dayKey,
            startMinute: 21 * 60,
            durationMinutes: 60,
            titleSnapshot: "Brush teeth",
            emojiSnapshot: "✨"
        )
        context.insert(task)
        DayPlanStorage.saveBlocks([staleBlock], forDayKey: dayKey, context: context)
        let planner = DayPlanPlannerState(selectedDate: occurrence)

        planner.showExactTimedTasks(
            from: [task],
            calendar: calendar,
            context: context
        )

        let block = try #require(planner.weekBlocksByDayKey[dayKey]?.first)
        #expect(block.id == blockID)
        #expect(block.taskID == taskID)
        #expect(block.startMinute == 21 * 60)
        #expect(block.durationMinutes == 5)
    }

    @Test
    func exactAvailabilityTodoCreatesTimedPlannerBlockWithoutDeadline() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let availabilityDate = try #require(date("2026-05-11T09:15:00Z"))
        let taskID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Call accountant",
            emoji: "📞",
            availabilityStartDate: availabilityDate,
            scheduleMode: .oneOff,
            recurrenceRule: .interval(days: 1, at: RoutineTimeOfDay(hour: 9, minute: 15)),
            estimatedDurationMinutes: 45
        )
        context.insert(task)
        try context.save()
        let planner = DayPlanPlannerState(selectedDate: availabilityDate)

        planner.showExactTimedTasks(
            from: [task],
            calendar: calendar,
            context: context
        )

        let block = try #require(planner.weekBlocksByDayKey.values.flatMap { $0 }.first)
        #expect(block.taskID == taskID)
        #expect(block.startMinute == 9 * 60 + 15)
        #expect(block.durationMinutes == 45)
    }

    @Test
    func availabilityWindowTodoCreatesTimedPlannerBlockWithWindowDuration() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let availabilityStart = try #require(date("2026-05-11T09:15:00Z"))
        let availabilityEnd = try #require(date("2026-05-11T11:00:00Z"))
        let taskID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Call accountant",
            emoji: "📞",
            availabilityStartDate: availabilityStart,
            availabilityEndDate: availabilityEnd,
            scheduleMode: .oneOff,
            recurrenceRule: .interval(
                days: 1,
                timeRange: RoutineTimeRange(
                    start: RoutineTimeOfDay(hour: 9, minute: 15),
                    end: RoutineTimeOfDay(hour: 11, minute: 0)
                )
            ),
            estimatedDurationMinutes: 45
        )
        context.insert(task)
        try context.save()
        let planner = DayPlanPlannerState(selectedDate: availabilityStart)

        planner.showExactTimedTasks(
            from: [task],
            calendar: calendar,
            context: context
        )

        let block = try #require(planner.weekBlocksByDayKey.values.flatMap { $0 }.first)
        #expect(block.taskID == taskID)
        #expect(block.startMinute == 9 * 60 + 15)
        #expect(block.durationMinutes == 105)
    }

    @Test
    func dateWindowTodoCreatesTimedPlannerBlocksOnEveryEligibleDate() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let availabilityStart = try #require(date("2026-05-11T09:15:00Z"))
        let availabilityEnd = try #require(date("2026-05-12T11:00:00Z"))
        let taskID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Call accountant",
            emoji: "📞",
            availabilityStartDate: availabilityStart,
            availabilityEndDate: availabilityEnd,
            scheduleMode: .oneOff,
            recurrenceRule: .interval(
                days: 1,
                timeRange: RoutineTimeRange(
                    start: RoutineTimeOfDay(hour: 9, minute: 15),
                    end: RoutineTimeOfDay(hour: 11, minute: 0)
                )
            ),
            estimatedDurationMinutes: 45
        )
        context.insert(task)
        try context.save()
        let planner = DayPlanPlannerState(selectedDate: availabilityStart)

        planner.showExactTimedTasks(
            from: [task],
            calendar: calendar,
            context: context
        )

        let blocks = planner.weekBlocksByDayKey
            .flatMap { entry in entry.value.map { (entry.key, $0) } }
            .sorted { lhs, rhs in lhs.0 < rhs.0 }
        #expect(blocks.map { $0.1.taskID } == [taskID, taskID])
        #expect(blocks.map { $0.1.startMinute } == [9 * 60 + 15, 9 * 60 + 15])
        #expect(blocks.map { $0.1.durationMinutes } == [105, 105])
    }

    @Test
    func allDayBlocksIncludeStandaloneEventsWithoutTaskIDs() throws {
        let calendar = gregorianCalendar
        let startDate = try #require(date("2026-05-11T00:00:00Z"))
        let endDate = try #require(date("2026-05-13T00:00:00Z"))
        let eventID = UUID()
        let event = RoutineEvent(
            id: eventID,
            title: "Sick days",
            emoji: "🤒",
            isAllDay: true,
            startedAt: startDate,
            endedAt: endDate
        )

        let blocks = DayPlanAllDayTasks.blocks(
            on: try plannerDates(),
            from: [],
            events: [event],
            calendar: calendar
        )

        let block = try #require(blocks.first)
        #expect(blocks.count == 1)
        #expect(block.id == eventID)
        #expect(block.taskID == nil)
        #expect(block.eventID == eventID)
        #expect(block.title == "Sick days")
        #expect(block.emoji == "🤒")
        #expect(block.startDate == startDate)
        #expect(block.endDate == endDate)
        #expect(block.isEvent)
    }

    @Test
    func eventBlocksSplitTimedStandaloneEventsAcrossVisibleDays() throws {
        let calendar = gregorianCalendar
        let startedAt = try #require(date("2026-05-10T23:30:00Z"))
        let endedAt = try #require(date("2026-05-11T01:15:00Z"))
        let event = RoutineEvent(
            title: "Late travel",
            emoji: "🚆",
            tags: ["Travel"],
            isAllDay: false,
            startedAt: startedAt,
            endedAt: endedAt
        )

        let blocksByDayKey = DayPlanEventBlocks.blocksByDayKey(
            on: try plannerDates(),
            from: [event],
            calendar: calendar
        )

        let firstKey = DayPlanStorage.dayKey(for: startedAt, calendar: calendar)
        let secondKey = DayPlanStorage.dayKey(for: endedAt, calendar: calendar)
        let firstBlock = try #require(blocksByDayKey[firstKey]?.first)
        let secondBlock = try #require(blocksByDayKey[secondKey]?.first)

        #expect(firstBlock.eventID == event.id)
        #expect(firstBlock.block.taskID == event.id)
        #expect(firstBlock.block.startMinute == 23 * 60 + 30)
        #expect(firstBlock.block.durationMinutes == 30)
        #expect(firstBlock.block.titleSnapshot == "Late travel")
        #expect(secondBlock.eventID == event.id)
        #expect(secondBlock.block.startMinute == 0)
        #expect(secondBlock.block.durationMinutes == 75)
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
    func activePausedFocusSessionBlocksUseFocusedDuration() throws {
        let calendar = gregorianCalendar
        let visibleDate = try #require(date("2026-05-07T12:00:00Z"))
        let startedAt = try #require(date("2026-05-07T09:30:00Z"))
        let pausedAt = try #require(date("2026-05-07T09:40:00Z"))
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
            plannedDurationSeconds: 0,
            pausedAt: pausedAt
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
        #expect(focusBlock.durationMinutes == 10)
        #expect(focusBlock.block.durationMinutes == DayPlanBlock.minimumDurationMinutes)
    }

    @Test
    func activeTagFocusSessionBlocksUseTagTitleAndDoNotOpenTaskDetails() throws {
        let calendar = gregorianCalendar
        let visibleDate = try #require(date("2026-05-07T12:00:00Z"))
        let startedAt = try #require(date("2026-05-07T09:30:00Z"))
        let now = try #require(date("2026-05-07T10:05:00Z"))
        let sessionID = UUID()
        let session = FocusSession(
            id: sessionID,
            taskID: FocusSession.unassignedTaskID,
            startedAt: startedAt,
            plannedDurationSeconds: 0,
            tagName: "Admin"
        )

        let focusBlocksByDayKey = DayPlanFocusSessionBlocks.activeBlocksByDayKey(
            on: [visibleDate],
            from: [],
            sessions: [session],
            now: now,
            calendar: calendar
        )

        let dayKey = DayPlanStorage.dayKey(for: visibleDate, calendar: calendar)
        let focusBlock = try #require(focusBlocksByDayKey[dayKey]?.first)
        #expect(focusBlock.sessionID == sessionID)
        #expect(focusBlock.block.id == sessionID)
        #expect(focusBlock.block.taskID == FocusSession.unassignedTaskID)
        #expect(focusBlock.block.titleSnapshot == "#Admin")
        #expect(focusBlock.block.startMinute == 9 * 60 + 30)
        #expect(focusBlock.durationMinutes == 35)
        #expect(!focusBlock.opensTaskDetails)
    }

    @Test
    func startedFocusSessionCreatesPersistedPlannerBlock() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let startedAt = try #require(date("2026-05-07T09:30:00Z"))
        let taskID = UUID()
        let sessionID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Write notes",
            emoji: "📝",
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 45
        )
        let session = FocusSession(
            id: sessionID,
            taskID: taskID,
            startedAt: startedAt,
            plannedDurationSeconds: 25 * 60
        )
        context.insert(task)
        context.insert(session)

        let savedBlock = try #require(
            DayPlanFocusSessionPlannerSync.saveStartedFocusBlock(
                for: task,
                session: session,
                startedAt: startedAt,
                durationSeconds: session.plannedDurationSeconds,
                calendar: calendar,
                context: context
            )
        )
        let loadedBlocks = DayPlanStorage.loadBlocks(forDayKey: savedBlock.dayKey, context: context)

        #expect(loadedBlocks.count == 1)
        #expect(loadedBlocks.first?.id == sessionID)
        #expect(loadedBlocks.first?.taskID == taskID)
        #expect(loadedBlocks.first?.startMinute == 9 * 60 + 30)
        #expect(loadedBlocks.first?.durationMinutes == 25)
        #expect(loadedBlocks.first?.titleSnapshot == "Write notes")
        #expect(loadedBlocks.first?.emojiSnapshot == "📝")
    }

    @Test
    func startedTagFocusSessionCreatesPersistedPlannerBlock() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let startedAt = try #require(date("2026-05-07T09:30:00Z"))
        let sessionID = UUID()
        let session = FocusSession(
            id: sessionID,
            taskID: FocusSession.unassignedTaskID,
            startedAt: startedAt,
            plannedDurationSeconds: 25 * 60,
            tagName: "Admin"
        )
        context.insert(session)

        let savedBlock = try #require(
            DayPlanFocusSessionPlannerSync.saveStartedTagFocusBlock(
                tagName: "Admin",
                session: session,
                startedAt: startedAt,
                durationSeconds: session.plannedDurationSeconds,
                calendar: calendar,
                context: context
            )
        )
        let loadedBlocks = DayPlanStorage.loadBlocks(forDayKey: savedBlock.dayKey, context: context)

        #expect(loadedBlocks.count == 1)
        #expect(loadedBlocks.first?.id == sessionID)
        #expect(loadedBlocks.first?.taskID == FocusSession.unassignedTaskID)
        #expect(loadedBlocks.first?.startMinute == 9 * 60 + 30)
        #expect(loadedBlocks.first?.durationMinutes == 25)
        #expect(loadedBlocks.first?.titleSnapshot == "#Admin")
        #expect(loadedBlocks.first?.emojiSnapshot == nil)
    }

    @Test
    func countUpFocusSessionPlannerBlockStartsAtOneMinute() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let startedAt = try #require(date("2026-05-07T09:30:00Z"))
        let taskID = UUID()
        let sessionID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Open ended focus",
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 45
        )
        let session = FocusSession(
            id: sessionID,
            taskID: taskID,
            startedAt: startedAt,
            plannedDurationSeconds: 0
        )
        context.insert(task)
        context.insert(session)

        let savedBlock = try #require(
            DayPlanFocusSessionPlannerSync.saveStartedFocusBlock(
                for: task,
                session: session,
                startedAt: startedAt,
                durationSeconds: session.plannedDurationSeconds,
                calendar: calendar,
                context: context
            )
        )
        let loadedBlocks = DayPlanStorage.loadBlocks(forDayKey: savedBlock.dayKey, context: context)

        #expect(loadedBlocks.count == 1)
        #expect(loadedBlocks.first?.id == sessionID)
        #expect(loadedBlocks.first?.durationMinutes == 1)
    }

    @Test
    func endedCountUpFocusSessionUpdatesPlannerBlockToExactElapsedMinutes() throws {
        let calendar = gregorianCalendar
        let startedAt = try #require(date("2026-05-07T09:30:00Z"))

        for expectedMinutes in [3, 5, 131] {
            let context = makeInMemoryContext()
            let taskID = UUID()
            let sessionID = UUID()
            let task = RoutineTask(
                id: taskID,
                name: "Open ended focus",
                scheduleMode: .fixedInterval,
                estimatedDurationMinutes: 45
            )
            let session = FocusSession(
                id: sessionID,
                taskID: taskID,
                startedAt: startedAt,
                plannedDurationSeconds: 0
            )
            context.insert(task)
            context.insert(session)
            let endedAt = startedAt.addingTimeInterval(TimeInterval(expectedMinutes * 60))

            _ = DayPlanFocusSessionPlannerSync.saveStartedFocusBlock(
                for: task,
                session: session,
                startedAt: startedAt,
                durationSeconds: session.plannedDurationSeconds,
                calendar: calendar,
                context: context
            )
            let savedBlock = try #require(
                DayPlanFocusSessionPlannerSync.saveEndedCountUpFocusBlock(
                    for: task,
                    session: session,
                    endedAt: endedAt,
                    calendar: calendar,
                    context: context
                )
            )
            let loadedBlocks = DayPlanStorage.loadBlocks(forDayKey: savedBlock.dayKey, context: context)

            #expect(loadedBlocks.count == 1)
            #expect(loadedBlocks.first?.id == sessionID)
            #expect(loadedBlocks.first?.durationMinutes == expectedMinutes)
        }
    }

    @Test
    func endedPausedCountUpFocusSessionUpdatesPlannerBlockToFocusedMinutes() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let startedAt = try #require(date("2026-05-07T09:30:00Z"))
        let pausedAt = try #require(date("2026-05-07T09:40:00Z"))
        let endedAt = try #require(date("2026-05-07T10:05:00Z"))
        let taskID = UUID()
        let sessionID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Open ended focus",
            scheduleMode: .fixedInterval,
            estimatedDurationMinutes: 45
        )
        let session = FocusSession(
            id: sessionID,
            taskID: taskID,
            startedAt: startedAt,
            plannedDurationSeconds: 0,
            pausedAt: pausedAt
        )
        context.insert(task)
        context.insert(session)

        _ = DayPlanFocusSessionPlannerSync.saveStartedFocusBlock(
            for: task,
            session: session,
            startedAt: startedAt,
            durationSeconds: session.plannedDurationSeconds,
            calendar: calendar,
            context: context
        )
        session.closePauseIfNeeded(at: endedAt)
        session.completedAt = endedAt

        let savedBlock = try #require(
            DayPlanFocusSessionPlannerSync.saveEndedCountUpFocusBlock(
                for: task,
                session: session,
                endedAt: endedAt,
                calendar: calendar,
                context: context
            )
        )
        let loadedBlocks = DayPlanStorage.loadBlocks(forDayKey: savedBlock.dayKey, context: context)

        #expect(loadedBlocks.count == 1)
        #expect(loadedBlocks.first?.id == sessionID)
        #expect(loadedBlocks.first?.durationMinutes == 10)
    }

    @Test
    func abandonedFocusSessionRemovesPersistedPlannerBlock() throws {
        let calendar = gregorianCalendar
        let startedAt = try #require(date("2026-05-07T09:30:00Z"))

        for plannedDurationSeconds in [TimeInterval(0), TimeInterval(25 * 60)] {
            let context = makeInMemoryContext()
            let taskID = UUID()
            let sessionID = UUID()
            let task = RoutineTask(
                id: taskID,
                name: "Focus target",
                scheduleMode: .fixedInterval,
                estimatedDurationMinutes: 45
            )
            let session = FocusSession(
                id: sessionID,
                taskID: taskID,
                startedAt: startedAt,
                plannedDurationSeconds: plannedDurationSeconds
            )
            context.insert(task)
            context.insert(session)

            let savedBlock = try #require(
                DayPlanFocusSessionPlannerSync.saveStartedFocusBlock(
                    for: task,
                    session: session,
                    startedAt: startedAt,
                    durationSeconds: session.plannedDurationSeconds,
                    calendar: calendar,
                    context: context
                )
            )

            #expect(DayPlanStorage.loadBlocks(forDayKey: savedBlock.dayKey, context: context).count == 1)
            #expect(
                DayPlanFocusSessionPlannerSync.removeFocusBlock(
                    for: session,
                    context: context
                )
            )
            #expect(DayPlanStorage.loadBlocks(forDayKey: savedBlock.dayKey, context: context).isEmpty)
        }
    }

    @Test
    func sprintFocusSessionsRenderAsPlannerBlocks() throws {
        let calendar = gregorianCalendar
        let visibleDate = try #require(date("2026-05-07T12:00:00Z"))
        let startedAt = try #require(date("2026-05-07T09:30:00Z"))
        let stoppedAt = try #require(date("2026-05-07T10:05:00Z"))
        let sprint = BoardSprintRecord(
            title: "Launch board",
            startedAt: date("2026-05-07T09:00:00Z")
        )
        let session = SprintFocusSessionRecord(
            sprintID: sprint.id,
            startedAt: startedAt,
            stoppedAt: stoppedAt
        )

        let blocksByDayKey = DayPlanSprintFocusBlocks.blocksByDayKey(
            on: [visibleDate],
            from: [session],
            allocations: [],
            sprints: [sprint],
            tasks: [],
            referenceDate: stoppedAt,
            calendar: calendar
        )

        let dayKey = DayPlanStorage.dayKey(for: visibleDate, calendar: calendar)
        let block = try #require(blocksByDayKey[dayKey]?.first)
        #expect(block.sessionID == session.id)
        #expect(block.block.id == session.id)
        #expect(block.block.taskID == sprint.id)
        #expect(block.block.titleSnapshot == "Launch board")
        #expect(block.block.emojiSnapshot == "🏁")
        #expect(block.block.startMinute == 9 * 60 + 30)
        #expect(block.block.durationMinutes == 35)
        #expect(block.interval.durationMinutes == 35)
        #expect(!block.isActive)
        #expect(!block.isAllocatedToTask)
    }

    @Test
    func sprintFocusPlannerBlockDoesNotRoundPastStoppedTime() throws {
        let calendar = gregorianCalendar
        let visibleDate = try #require(date("2026-05-07T12:00:00Z"))
        let startedAt = try #require(date("2026-05-07T10:00:00Z"))
        let stoppedAt = try #require(date("2026-05-07T10:08:59Z"))
        let sprint = BoardSprintRecord(title: "HSE")
        let session = SprintFocusSessionRecord(
            sprintID: sprint.id,
            startedAt: startedAt,
            stoppedAt: stoppedAt
        )

        let blocksByDayKey = DayPlanSprintFocusBlocks.blocksByDayKey(
            on: [visibleDate],
            from: [session],
            allocations: [],
            sprints: [sprint],
            tasks: [],
            referenceDate: stoppedAt,
            calendar: calendar
        )

        let dayKey = DayPlanStorage.dayKey(for: visibleDate, calendar: calendar)
        let block = try #require(blocksByDayKey[dayKey]?.first)
        #expect(block.block.startMinute == 10 * 60)
        #expect(block.block.durationMinutes == 8)
        #expect(block.block.endMinute == 10 * 60 + 8)
        #expect(block.interval.endMinute == 10 * 60 + 8)
    }

    @Test
    func activeSprintFocusRenderedDurationDoesNotRunAheadOfNow() throws {
        let calendar = gregorianCalendar
        let visibleDate = try #require(date("2026-05-07T12:00:00Z"))
        let startedAt = try #require(date("2026-05-07T10:00:00Z"))
        let now = try #require(date("2026-05-07T10:01:00Z"))
        let sprint = BoardSprintRecord(title: "HSE")
        let session = SprintFocusSessionRecord(
            sprintID: sprint.id,
            startedAt: startedAt
        )

        let blocksByDayKey = DayPlanSprintFocusBlocks.blocksByDayKey(
            on: [visibleDate],
            from: [session],
            allocations: [],
            sprints: [sprint],
            tasks: [],
            referenceDate: now,
            calendar: calendar
        )

        let dayKey = DayPlanStorage.dayKey(for: visibleDate, calendar: calendar)
        let block = try #require(blocksByDayKey[dayKey]?.first)
        #expect(block.isActive)
        #expect(block.block.startMinute == 10 * 60)
        #expect(block.interval.endMinute == 10 * 60 + 1)
        #expect(block.renderedDurationMinutes == 1)
    }

    @Test
    func sprintFocusAllocationsSplitPlannerBlocksAndLeaveResidualBoardFocus() throws {
        let calendar = gregorianCalendar
        let visibleDate = try #require(date("2026-05-07T12:00:00Z"))
        let startedAt = try #require(date("2026-05-07T09:00:00Z"))
        let stoppedAt = try #require(date("2026-05-07T10:00:00Z"))
        let firstTask = RoutineTask(
            id: UUID(),
            name: "Implement board",
            emoji: "🧩",
            scheduleMode: .oneOff
        )
        let secondTask = RoutineTask(
            id: UUID(),
            name: "Review board",
            emoji: "🔎",
            scheduleMode: .oneOff
        )
        let sprint = BoardSprintRecord(title: "Launch board")
        let session = SprintFocusSessionRecord(
            sprintID: sprint.id,
            startedAt: startedAt,
            stoppedAt: stoppedAt
        )
        let firstAllocation = SprintFocusAllocationRecord(
            sessionID: session.id,
            taskID: firstTask.id,
            minutes: 20,
            sortOrder: 0
        )
        let secondAllocation = SprintFocusAllocationRecord(
            sessionID: session.id,
            taskID: secondTask.id,
            minutes: 15,
            sortOrder: 1
        )

        let blocksByDayKey = DayPlanSprintFocusBlocks.blocksByDayKey(
            on: [visibleDate],
            from: [session],
            allocations: [secondAllocation, firstAllocation],
            sprints: [sprint],
            tasks: [firstTask, secondTask],
            referenceDate: stoppedAt,
            calendar: calendar
        )
        let blockedIntervalsByDayKey = DayPlanSprintFocusBlocks.blockedIntervalsByDayKey(
            on: [visibleDate],
            from: [session],
            allocations: [secondAllocation, firstAllocation],
            sprints: [sprint],
            tasks: [firstTask, secondTask],
            referenceDate: stoppedAt,
            calendar: calendar
        )

        let dayKey = DayPlanStorage.dayKey(for: visibleDate, calendar: calendar)
        let blocks = try #require(blocksByDayKey[dayKey])
        #expect(blocks.count == 3)
        #expect(blocks[0].block.id == firstAllocation.id)
        #expect(blocks[0].block.taskID == firstTask.id)
        #expect(blocks[0].block.titleSnapshot == "Implement board")
        #expect(blocks[0].block.startMinute == 9 * 60)
        #expect(blocks[0].block.durationMinutes == 20)
        #expect(blocks[0].isAllocatedToTask)
        #expect(blocks[1].block.id == secondAllocation.id)
        #expect(blocks[1].block.taskID == secondTask.id)
        #expect(blocks[1].block.startMinute == 9 * 60 + 20)
        #expect(blocks[1].block.durationMinutes == 15)
        #expect(blocks[1].isAllocatedToTask)
        #expect(blocks[2].block.id == session.id)
        #expect(blocks[2].block.taskID == sprint.id)
        #expect(blocks[2].block.titleSnapshot == "Launch board")
        #expect(blocks[2].block.startMinute == 9 * 60 + 35)
        #expect(blocks[2].block.durationMinutes == 25)
        #expect(!blocks[2].isAllocatedToTask)
        #expect(blockedIntervalsByDayKey[dayKey]?.map(\.durationMinutes) == [20, 15, 25])
    }

    @Test
    func activeFocusSessionBlocksExcludePersistedPlannerBlocks() throws {
        let calendar = gregorianCalendar
        let visibleDate = try #require(date("2026-05-07T12:00:00Z"))
        let startedAt = try #require(date("2026-05-07T09:30:00Z"))
        let now = try #require(date("2026-05-07T10:05:00Z"))
        let taskID = UUID()
        let sessionID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Write notes",
            scheduleMode: .fixedInterval
        )
        let session = FocusSession(
            id: sessionID,
            taskID: taskID,
            startedAt: startedAt,
            plannedDurationSeconds: 25 * 60
        )
        let persistedBlock = DayPlanBlock(
            id: sessionID,
            taskID: taskID,
            dayKey: DayPlanStorage.dayKey(for: visibleDate, calendar: calendar),
            startMinute: 9 * 60 + 30,
            durationMinutes: 25,
            titleSnapshot: "Write notes",
            createdAt: startedAt,
            updatedAt: startedAt
        )

        let focusBlocksByDayKey = DayPlanFocusSessionBlocks.activeBlocksByDayKey(
            on: [visibleDate],
            from: [task],
            sessions: [session],
            now: now,
            calendar: calendar,
            excluding: [persistedBlock]
        )

        #expect(focusBlocksByDayKey.isEmpty)
    }

    @Test
    func activePlanFocusSessionBlocksStartAfterAllocatedPlannerBlocks() throws {
        let calendar = gregorianCalendar
        let visibleDate = try #require(date("2026-05-07T12:00:00Z"))
        let startedAt = try #require(date("2026-05-07T09:30:00Z"))
        let now = try #require(date("2026-05-07T10:05:00Z"))
        let taskID = UUID()
        let sessionID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Home chores",
            scheduleMode: .fixedInterval
        )
        let session = FocusSession(
            id: sessionID,
            taskID: FocusSession.unassignedTaskID,
            startedAt: startedAt,
            plannedDurationSeconds: 0
        )
        let allocationBlock = DayPlanBlock(
            id: DayPlanFocusSessionPlannerSync.allocationBlockID(
                sessionID: sessionID,
                taskID: taskID
            ),
            taskID: taskID,
            dayKey: DayPlanStorage.dayKey(for: visibleDate, calendar: calendar),
            startMinute: 9 * 60 + 30,
            durationMinutes: 15,
            titleSnapshot: "Home chores",
            createdAt: startedAt,
            updatedAt: now,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )

        let focusBlocksByDayKey = DayPlanFocusSessionBlocks.activeBlocksByDayKey(
            on: [visibleDate],
            from: [task],
            sessions: [session],
            now: now,
            calendar: calendar,
            excluding: [allocationBlock]
        )

        let dayKey = DayPlanStorage.dayKey(for: visibleDate, calendar: calendar)
        let focusBlock = try #require(focusBlocksByDayKey[dayKey]?.first)
        #expect(focusBlock.sessionID == sessionID)
        #expect(focusBlock.block.id == sessionID)
        #expect(focusBlock.block.taskID == FocusSession.unassignedTaskID)
        #expect(focusBlock.block.titleSnapshot == "Plan Focus")
        #expect(focusBlock.block.startMinute == 9 * 60 + 45)
        #expect(focusBlock.durationMinutes == 20)
        #expect(focusBlock.block.durationMinutes == 20)
    }

    @Test
    func activePlanFocusSessionBlocksExcludeFullyAllocatedPlannerBlocks() throws {
        let calendar = gregorianCalendar
        let visibleDate = try #require(date("2026-05-07T12:00:00Z"))
        let startedAt = try #require(date("2026-05-07T09:30:00Z"))
        let now = try #require(date("2026-05-07T10:05:00Z"))
        let taskID = UUID()
        let sessionID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Home chores",
            scheduleMode: .fixedInterval
        )
        let session = FocusSession(
            id: sessionID,
            taskID: FocusSession.unassignedTaskID,
            startedAt: startedAt,
            plannedDurationSeconds: 0
        )
        let allocationBlock = DayPlanBlock(
            id: DayPlanFocusSessionPlannerSync.allocationBlockID(
                sessionID: sessionID,
                taskID: taskID
            ),
            taskID: taskID,
            dayKey: DayPlanStorage.dayKey(for: visibleDate, calendar: calendar),
            startMinute: 9 * 60 + 30,
            durationMinutes: 35,
            titleSnapshot: "Home chores",
            createdAt: startedAt,
            updatedAt: now,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )

        let focusBlocksByDayKey = DayPlanFocusSessionBlocks.activeBlocksByDayKey(
            on: [visibleDate],
            from: [task],
            sessions: [session],
            now: now,
            calendar: calendar,
            excluding: [allocationBlock]
        )

        #expect(focusBlocksByDayKey.isEmpty)
    }

    @Test
    func activeCountUpFocusSessionBlocksIgnorePersistedStarterBlock() throws {
        let calendar = gregorianCalendar
        let visibleDate = try #require(date("2026-05-07T12:00:00Z"))
        let startedAt = try #require(date("2026-05-07T09:30:00Z"))
        let now = try #require(date("2026-05-07T09:35:00Z"))
        let taskID = UUID()
        let sessionID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Write notes",
            scheduleMode: .fixedInterval
        )
        let session = FocusSession(
            id: sessionID,
            taskID: taskID,
            startedAt: startedAt,
            plannedDurationSeconds: 0
        )
        let persistedBlock = DayPlanBlock(
            id: sessionID,
            taskID: taskID,
            dayKey: DayPlanStorage.dayKey(for: visibleDate, calendar: calendar),
            startMinute: 9 * 60 + 30,
            durationMinutes: 1,
            titleSnapshot: "Write notes",
            createdAt: startedAt,
            updatedAt: startedAt,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )

        let focusBlocksByDayKey = DayPlanFocusSessionBlocks.activeBlocksByDayKey(
            on: [visibleDate],
            from: [task],
            sessions: [session],
            now: now,
            calendar: calendar,
            excluding: [persistedBlock]
        )

        let dayKey = DayPlanStorage.dayKey(for: visibleDate, calendar: calendar)
        let focusBlock = try #require(focusBlocksByDayKey[dayKey]?.first)
        #expect(focusBlock.sessionID == sessionID)
        #expect(focusBlock.durationMinutes == 5)
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
    func sleepBlocksMergeOverlappingSessionsBeforeRendering() throws {
        let calendar = gregorianCalendar
        let visibleDate = try #require(date("2026-06-03T12:00:00Z"))
        let primaryID = UUID()
        let duplicateID = UUID()
        let primary = SleepSession(
            id: primaryID,
            startedAt: date("2026-06-03T03:06:00Z"),
            endedAt: date("2026-06-03T09:11:00Z")
        )
        let duplicate = SleepSession(
            id: duplicateID,
            startedAt: date("2026-06-03T03:06:00Z"),
            endedAt: date("2026-06-03T03:21:00Z")
        )
        let referenceDate = try #require(date("2026-06-03T09:30:00Z"))

        let sleepBlocksByDayKey = DayPlanSleepBlocks.blocksByDayKey(
            on: [visibleDate],
            from: [duplicate, primary],
            referenceDate: referenceDate,
            calendar: calendar
        )

        let dayKey = DayPlanStorage.dayKey(for: visibleDate, calendar: calendar)
        let blocks = sleepBlocksByDayKey[dayKey] ?? []
        #expect(blocks.count == 1)
        guard let block = blocks.first else { return }
        #expect(block.block.startMinute == 3 * 60 + 6)
        #expect(block.block.durationMinutes == 6 * 60 + 5)
        #expect(block.sourceSessionIDs == Set([primaryID, duplicateID]))
        #expect(block.contains(sessionID: primaryID))
        #expect(block.contains(sessionID: duplicateID))
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

    @Test
    func timedBlockColumnLayoutSplitsSameTimeEventsIntoSideBySideColumns() {
        let placements = DayPlanTimedBlockColumnLayout.placements(
            for: [
                DayPlanTimedBlockColumnItem(id: "a", startMinute: 10 * 60, endMinute: 12 * 60),
                DayPlanTimedBlockColumnItem(id: "b", startMinute: 10 * 60, endMinute: 12 * 60),
            ]
        )

        #expect(
            placements == [
                DayPlanTimedBlockColumnPlacement(id: "a", columnIndex: 0, columnCount: 2),
                DayPlanTimedBlockColumnPlacement(id: "b", columnIndex: 1, columnCount: 2),
            ]
        )
    }

    @Test
    func timedBlockColumnLayoutSplitsSameTimeEventAndTaskIntoSideBySideColumns() {
        let placements = DayPlanTimedBlockColumnLayout.placements(
            for: [
                DayPlanTimedBlockColumnItem(id: "planned-task", startMinute: 10 * 60, endMinute: 12 * 60),
                DayPlanTimedBlockColumnItem(id: "calendar-event", startMinute: 10 * 60, endMinute: 12 * 60),
            ]
        )

        #expect(
            placements == [
                DayPlanTimedBlockColumnPlacement(id: "planned-task", columnIndex: 1, columnCount: 2),
                DayPlanTimedBlockColumnPlacement(id: "calendar-event", columnIndex: 0, columnCount: 2),
            ]
        )
    }

    @Test
    func timedBlockColumnLayoutReusesColumnsWithinConnectedOverlapGroups() {
        let placements = DayPlanTimedBlockColumnLayout.placements(
            for: [
                DayPlanTimedBlockColumnItem(id: "a", startMinute: 9 * 60, endMinute: 10 * 60),
                DayPlanTimedBlockColumnItem(id: "b", startMinute: 9 * 60 + 30, endMinute: 10 * 60 + 30),
                DayPlanTimedBlockColumnItem(id: "c", startMinute: 10 * 60, endMinute: 11 * 60),
                DayPlanTimedBlockColumnItem(id: "d", startMinute: 12 * 60, endMinute: 13 * 60),
            ]
        )

        #expect(
            placements == [
                DayPlanTimedBlockColumnPlacement(id: "a", columnIndex: 0, columnCount: 2),
                DayPlanTimedBlockColumnPlacement(id: "b", columnIndex: 1, columnCount: 2),
                DayPlanTimedBlockColumnPlacement(id: "c", columnIndex: 0, columnCount: 2),
                DayPlanTimedBlockColumnPlacement(id: "d", columnIndex: 0, columnCount: 1),
            ]
        )
    }

    @Test
    func plannerMoveUndoRestoresBlockAndFocusesOriginalDate() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let undoManager = UndoManager()
        RoutinaUndoSupport.setActiveUndoManager(undoManager)
        RoutinaUndoSupport.configure(
            undoManagerProvider: { undoManager },
            contextPreparer: { $0.undoManager = undoManager }
        )
        defer {
            RoutinaUndoSupport.setActiveUndoManager(nil)
            RoutinaUndoSupport.configure(
                undoManagerProvider: { nil },
                contextPreparer: { _ in }
            )
        }

        let sourceDate = try #require(date("2026-05-02T12:00:00Z"))
        let targetDate = try #require(date("2026-06-25T12:00:00Z"))
        let block = dayPlanBlock(on: sourceDate, calendar: calendar)
        let sourceDayKey = DayPlanStorage.dayKey(for: sourceDate, calendar: calendar)
        let targetDayKey = DayPlanStorage.dayKey(for: targetDate, calendar: calendar)
        DayPlanStorage.saveBlocks([block], forDayKey: sourceDayKey, context: context)
        let planner = DayPlanPlannerState(selectedDate: targetDate)
        planner.weekBlocksByDayKey = [sourceDayKey: [block]]

        let didMove = planner.moveBlock(
            block.id,
            to: targetDate,
            startMinute: 9 * 60,
            calendar: calendar,
            context: context
        )
        undoManager.undo()

        let restoredSourceBlocks = DayPlanStorage.loadBlocks(forDayKey: sourceDayKey, context: context)
        let restoredTargetBlocks = DayPlanStorage.loadBlocks(forDayKey: targetDayKey, context: context)
        let restoredBlock = try #require(restoredSourceBlocks.first)
        #expect(didMove)
        #expect(restoredSourceBlocks.map(\.id) == [block.id])
        #expect(restoredTargetBlocks.isEmpty)
        #expect(restoredBlock.startMinute == block.startMinute)
        #expect(planner.selectedDate == calendar.startOfDay(for: sourceDate))
        #expect(planner.selectedBlockID == block.id)
        #expect(planner.highlightedBlockID == block.id)
        #expect(planner.highlightedBlockScrollMinute == block.startMinute)
    }

    @Test
    func plannerResizeUndoRestoresInitialResizeStateAsSingleUndo() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let undoManager = UndoManager()
        RoutinaUndoSupport.setActiveUndoManager(undoManager)
        RoutinaUndoSupport.configure(
            undoManagerProvider: { undoManager },
            contextPreparer: { $0.undoManager = undoManager }
        )
        defer {
            RoutinaUndoSupport.setActiveUndoManager(nil)
            RoutinaUndoSupport.configure(
                undoManagerProvider: { nil },
                contextPreparer: { _ in }
            )
        }

        let blockDate = try #require(date("2026-05-02T12:00:00Z"))
        let block = dayPlanBlock(on: blockDate, calendar: calendar)
        let dayKey = DayPlanStorage.dayKey(for: blockDate, calendar: calendar)
        DayPlanStorage.saveBlocks([block], forDayKey: dayKey, context: context)
        let planner = DayPlanPlannerState(selectedDate: blockDate)
        planner.weekBlocksByDayKey = [dayKey: [block]]

        planner.beginResizeBlock(block, on: blockDate, calendar: calendar, context: context)
        let didResizeFirst = planner.resizeBlock(
            block.id,
            on: blockDate,
            startMinute: block.startMinute - 30,
            durationMinutes: block.durationMinutes + 30,
            calendar: calendar,
            context: context
        )
        let didResizeSecond = planner.resizeBlock(
            block.id,
            on: blockDate,
            startMinute: block.startMinute - 45,
            durationMinutes: block.durationMinutes + 60,
            calendar: calendar,
            context: context
        )
        planner.endResizeBlock(block.id, calendar: calendar, context: context)

        undoManager.undo()

        let restoredBlock = try #require(DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context).first)
        #expect(didResizeFirst)
        #expect(didResizeSecond)
        #expect(!undoManager.canUndo)
        #expect(undoManager.canRedo)
        #expect(restoredBlock.startMinute == block.startMinute)
        #expect(restoredBlock.durationMinutes == block.durationMinutes)
        #expect(planner.selectedDate == calendar.startOfDay(for: blockDate))
        #expect(planner.highlightedBlockID == block.id)
        #expect(planner.highlightedBlockScrollMinute == block.startMinute)
    }

    @Test
    func commandLayerPlannerUndoRestoresResizeWithoutNativeUndoManager() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        RoutinaUndoSupport.configure(
            undoManagerProvider: { nil },
            contextPreparer: { _ in }
        )
        defer {
            RoutinaUndoSupport.clearActiveScopedUndo()
            RoutinaUndoSupport.configure(
                undoManagerProvider: { nil },
                contextPreparer: { _ in }
            )
        }

        let blockDate = try #require(date("2026-05-02T12:00:00Z"))
        let block = dayPlanBlock(on: blockDate, calendar: calendar)
        let dayKey = DayPlanStorage.dayKey(for: blockDate, calendar: calendar)
        DayPlanStorage.saveBlocks([block], forDayKey: dayKey, context: context)
        let planner = DayPlanPlannerState(selectedDate: blockDate)
        planner.weekBlocksByDayKey = [dayKey: [block]]
        RoutinaUndoSupport.setActiveScopedUndo(
            undo: { planner.performPlannerUndo(calendar: calendar, context: context) },
            redo: { planner.performPlannerRedo(calendar: calendar, context: context) }
        )

        planner.beginResizeBlock(block, on: blockDate, calendar: calendar, context: context)
        let didResize = planner.resizeBlock(
            block.id,
            on: blockDate,
            startMinute: block.startMinute,
            durationMinutes: block.durationMinutes + 45,
            calendar: calendar,
            context: context
        )
        planner.endResizeBlock(block.id, calendar: calendar, context: context)

        #expect(didResize)
        #expect(RoutinaUndoSupport.performUndo())
        let restoredBlock = try #require(DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context).first)
        #expect(restoredBlock.durationMinutes == block.durationMinutes)
        #expect(planner.highlightedBlockID == block.id)
        #expect(planner.highlightedBlockScrollMinute == block.startMinute)
    }

    @Test
    func clearingPlannerUndoRemovesPendingPlannerUndoAction() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let undoManager = UndoManager()
        RoutinaUndoSupport.setActiveUndoManager(undoManager)
        RoutinaUndoSupport.configure(
            undoManagerProvider: { undoManager },
            contextPreparer: { $0.undoManager = undoManager }
        )
        defer {
            RoutinaUndoSupport.setActiveUndoManager(nil)
            RoutinaUndoSupport.configure(
                undoManagerProvider: { nil },
                contextPreparer: { _ in }
            )
        }

        let sourceDate = try #require(date("2026-05-02T12:00:00Z"))
        let targetDate = try #require(date("2026-06-25T12:00:00Z"))
        let block = dayPlanBlock(on: sourceDate, calendar: calendar)
        let sourceDayKey = DayPlanStorage.dayKey(for: sourceDate, calendar: calendar)
        DayPlanStorage.saveBlocks([block], forDayKey: sourceDayKey, context: context)
        let planner = DayPlanPlannerState(selectedDate: targetDate)
        planner.weekBlocksByDayKey = [sourceDayKey: [block]]

        let didMove = planner.moveBlock(
            block.id,
            to: targetDate,
            startMinute: 9 * 60,
            calendar: calendar,
            context: context
        )

        #expect(didMove)
        #expect(undoManager.canUndo)
        planner.clearPlannerUndo()
        undoManager.undo()
        let targetDayKey = DayPlanStorage.dayKey(for: targetDate, calendar: calendar)
        #expect(DayPlanStorage.loadBlocks(forDayKey: sourceDayKey, context: context).isEmpty)
        #expect(DayPlanStorage.loadBlocks(forDayKey: targetDayKey, context: context).map(\.id) == [block.id])
    }

    @Test
    func plannerUndoRegistersWithActiveUndoManager() throws {
        let calendar = gregorianCalendar
        let context = makeInMemoryContext()
        let bridgeUndoManager = UndoManager()
        let activeUndoManager = UndoManager()
        RoutinaUndoSupport.configure(
            undoManagerProvider: { bridgeUndoManager },
            contextPreparer: { $0.undoManager = activeUndoManager }
        )
        RoutinaUndoSupport.setActiveUndoManager(activeUndoManager)
        defer {
            RoutinaUndoSupport.setActiveUndoManager(nil)
            RoutinaUndoSupport.configure(
                undoManagerProvider: { nil },
                contextPreparer: { _ in }
            )
        }

        let sourceDate = try #require(date("2026-05-02T12:00:00Z"))
        let targetDate = try #require(date("2026-06-25T12:00:00Z"))
        let block = dayPlanBlock(on: sourceDate, calendar: calendar)
        let sourceDayKey = DayPlanStorage.dayKey(for: sourceDate, calendar: calendar)
        DayPlanStorage.saveBlocks([block], forDayKey: sourceDayKey, context: context)
        let planner = DayPlanPlannerState(selectedDate: targetDate)
        planner.weekBlocksByDayKey = [sourceDayKey: [block]]

        let didMove = planner.moveBlock(
            block.id,
            to: targetDate,
            startMinute: 9 * 60,
            calendar: calendar,
            context: context
        )

        #expect(didMove)
        #expect(!bridgeUndoManager.canUndo)
        #expect(activeUndoManager.canUndo)

        activeUndoManager.undo()
        #expect(DayPlanStorage.loadBlocks(forDayKey: sourceDayKey, context: context).map(\.id) == [block.id])
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

private func plannerBlock(
    taskID: UUID,
    title: String,
    on date: Date,
    calendar: Calendar
) -> DayPlanBlock {
    DayPlanBlock(
        taskID: taskID,
        dayKey: DayPlanStorage.dayKey(for: date, calendar: calendar),
        startMinute: 9 * 60,
        durationMinutes: 60,
        titleSnapshot: title,
        createdAt: date,
        updatedAt: date
    )
}
