import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct DayPlanDayTaskListPresentationTests {
    @Test
    func itemsShowAllDayTasksBeforeTimedBlocks() throws {
        let calendar = testCalendar
        let day = try #require(testDate(year: 2026, month: 6, day: 29, calendar: calendar))
        let dayKey = DayPlanStorage.dayKey(for: day, calendar: calendar)
        let allDayTaskID = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let morningTaskID = try #require(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let afternoonTaskID = try #require(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let morningBlockID = try #require(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let afternoonBlockID = try #require(UUID(uuidString: "55555555-5555-5555-5555-555555555555"))
        let allDayEnd = try #require(calendar.date(byAdding: .day, value: 1, to: day))

        let allDayBlock = DayPlanAllDayBlock(
            id: allDayTaskID,
            taskID: allDayTaskID,
            eventID: nil,
            title: "All day review",
            emoji: nil,
            startDate: day,
            endDate: allDayEnd,
            isLegacyDateOnlyCalendarTask: false,
            isEvent: false
        )
        let afternoonBlock = DayPlanBlock(
            id: afternoonBlockID,
            taskID: afternoonTaskID,
            dayKey: dayKey,
            startMinute: 13 * 60,
            durationMinutes: 45,
            titleSnapshot: "Afternoon block"
        )
        let morningBlock = DayPlanBlock(
            id: morningBlockID,
            taskID: morningTaskID,
            dayKey: dayKey,
            startMinute: 9 * 60,
            durationMinutes: 30,
            titleSnapshot: "Morning block"
        )

        let items = DayPlanDayTaskListPresentation.items(
            on: day,
            timedBlocks: [afternoonBlock, morningBlock],
            allDayBlocks: [allDayBlock],
            calendar: calendar
        )

        #expect(items.map(\.title) == ["All day review", "Morning block", "Afternoon block"])
        #expect(items.map(\.placement) == [
            .allDay,
            .timed(startMinute: 9 * 60, durationMinutes: 30),
            .timed(startMinute: 13 * 60, durationMinutes: 45),
        ])
        #expect(items.map(\.blockID) == [nil, morningBlockID, afternoonBlockID])
    }

    @Test
    func itemsIncludeOnlyTaskBackedAllDayBlocksIntersectingSelectedDate() throws {
        let calendar = testCalendar
        let day = try #require(testDate(year: 2026, month: 6, day: 29, calendar: calendar))
        let previousDay = try #require(calendar.date(byAdding: .day, value: -1, to: day))
        let nextDay = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        let twoDaysLater = try #require(calendar.date(byAdding: .day, value: 2, to: day))
        let taskID = try #require(UUID(uuidString: "66666666-6666-6666-6666-666666666666"))
        let eventID = try #require(UUID(uuidString: "77777777-7777-7777-7777-777777777777"))
        let otherTaskID = try #require(UUID(uuidString: "88888888-8888-8888-8888-888888888888"))

        let spanningTask = DayPlanAllDayBlock(
            id: taskID,
            taskID: taskID,
            eventID: nil,
            title: "Spanning task",
            emoji: nil,
            startDate: previousDay,
            endDate: nextDay,
            isLegacyDateOnlyCalendarTask: false,
            isEvent: false
        )
        let event = DayPlanAllDayBlock(
            id: eventID,
            taskID: nil,
            eventID: eventID,
            title: "Calendar event",
            emoji: nil,
            startDate: day,
            endDate: nextDay,
            isLegacyDateOnlyCalendarTask: false,
            isEvent: true
        )
        let otherDayTask = DayPlanAllDayBlock(
            id: otherTaskID,
            taskID: otherTaskID,
            eventID: nil,
            title: "Other day task",
            emoji: nil,
            startDate: nextDay,
            endDate: twoDaysLater,
            isLegacyDateOnlyCalendarTask: false,
            isEvent: false
        )

        let items = DayPlanDayTaskListPresentation.items(
            on: day,
            timedBlocks: [],
            allDayBlocks: [event, otherDayTask, spanningTask],
            calendar: calendar
        )

        #expect(items.map(\.title) == ["Spanning task"])
        #expect(items.map(\.taskID) == [taskID])
    }

    @Test
    func itemsIncludeDateOnlyPlannedTasksForSelectedDate() throws {
        let calendar = testCalendar
        let day = try #require(testDate(year: 2026, month: 6, day: 29, calendar: calendar))
        let nextDay = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        let dayKey = DayPlanStorage.dayKey(for: day, calendar: calendar)
        let plannedTaskID = try #require(UUID(uuidString: "99999999-9999-9999-9999-999999999999"))
        let otherDayTaskID = try #require(UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"))
        let timedTaskID = try #require(UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"))
        let timedBlockID = try #require(UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc"))

        let plannedTask = RoutineTask(
            id: plannedTaskID,
            name: "Monday plan",
            scheduleMode: .oneOff
        )
        plannedTask.plannedDate = day
        let otherDayTask = RoutineTask(
            id: otherDayTaskID,
            name: "Tuesday plan",
            scheduleMode: .oneOff
        )
        otherDayTask.plannedDate = nextDay
        let timedBlock = DayPlanBlock(
            id: timedBlockID,
            taskID: timedTaskID,
            dayKey: dayKey,
            startMinute: 10 * 60,
            durationMinutes: 30,
            titleSnapshot: "Timed block"
        )

        let items = DayPlanDayTaskListPresentation.items(
            on: day,
            timedBlocks: [timedBlock],
            allDayBlocks: [],
            plannedDateTasks: [otherDayTask, plannedTask],
            calendar: calendar
        )

        #expect(items.map(\.title) == ["Monday plan", "Timed block"])
        #expect(items.map(\.placement) == [
            .allDay,
            .timed(startMinute: 10 * 60, durationMinutes: 30),
        ])
        #expect(items.map(\.blockID) == [nil, timedBlockID])
    }

    @Test
    func itemsDoNotDuplicatePlannedDateTasksAlreadyShownAsPlannerItems() throws {
        let calendar = testCalendar
        let day = try #require(testDate(year: 2026, month: 6, day: 29, calendar: calendar))
        let nextDay = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        let dayKey = DayPlanStorage.dayKey(for: day, calendar: calendar)
        let allDayTaskID = try #require(UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd"))
        let timedTaskID = try #require(UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee"))
        let timedBlockID = try #require(UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff"))

        let allDayTask = RoutineTask(
            id: allDayTaskID,
            name: "All-day date plan",
            scheduleMode: .oneOff
        )
        allDayTask.plannedDate = day
        let timedTask = RoutineTask(
            id: timedTaskID,
            name: "Timed date plan",
            scheduleMode: .oneOff
        )
        timedTask.plannedDate = day

        let allDayBlock = DayPlanAllDayBlock(
            id: allDayTaskID,
            taskID: allDayTaskID,
            eventID: nil,
            title: "All-day block",
            emoji: nil,
            startDate: day,
            endDate: nextDay,
            isLegacyDateOnlyCalendarTask: false,
            isEvent: false
        )
        let timedBlock = DayPlanBlock(
            id: timedBlockID,
            taskID: timedTaskID,
            dayKey: dayKey,
            startMinute: 11 * 60,
            durationMinutes: 45,
            titleSnapshot: "Timed block"
        )

        let items = DayPlanDayTaskListPresentation.items(
            on: day,
            timedBlocks: [timedBlock],
            allDayBlocks: [allDayBlock],
            plannedDateTasks: [allDayTask, timedTask],
            calendar: calendar
        )

        #expect(items.map(\.title) == ["All-day block", "Timed block"])
        #expect(items.map(\.taskID) == [allDayTaskID, timedTaskID])
    }

    @Test
    func itemsIgnoreInactivePinnedAndDailyPlannedDateTasks() throws {
        let calendar = testCalendar
        let day = try #require(testDate(year: 2026, month: 6, day: 29, calendar: calendar))

        func plannedTask(
            id: UUID,
            name: String,
            scheduleMode: RoutineScheduleMode = .oneOff,
            lastDone: Date? = nil,
            canceledAt: Date? = nil,
            pausedAt: Date? = nil,
            pinnedAt: Date? = nil
        ) -> RoutineTask {
            let task = RoutineTask(
                id: id,
                name: name,
                scheduleMode: scheduleMode,
                lastDone: lastDone,
                canceledAt: canceledAt,
                pausedAt: pausedAt,
                pinnedAt: pinnedAt
            )
            task.plannedDate = day
            return task
        }

        let completedTask = plannedTask(
            id: try #require(UUID(uuidString: "10101010-1010-1010-1010-101010101010")),
            name: "Completed",
            lastDone: day
        )
        let canceledTask = plannedTask(
            id: try #require(UUID(uuidString: "20202020-2020-2020-2020-202020202020")),
            name: "Canceled",
            canceledAt: day
        )
        let pausedTask = plannedTask(
            id: try #require(UUID(uuidString: "30303030-3030-3030-3030-303030303030")),
            name: "Paused",
            pausedAt: day
        )
        let pinnedTask = plannedTask(
            id: try #require(UUID(uuidString: "40404040-4040-4040-4040-404040404040")),
            name: "Pinned",
            pinnedAt: day
        )
        let dailyRoutine = plannedTask(
            id: try #require(UUID(uuidString: "50505050-5050-5050-5050-505050505050")),
            name: "Daily routine",
            scheduleMode: .fixedInterval
        )

        let items = DayPlanDayTaskListPresentation.items(
            on: day,
            timedBlocks: [],
            allDayBlocks: [],
            plannedDateTasks: [completedTask, canceledTask, pausedTask, pinnedTask, dailyRoutine],
            calendar: calendar
        )

        #expect(items.isEmpty)
    }

    @Test
    func plannerBackedCompletedTaskMovesToDoneSection() throws {
        let calendar = testCalendar
        let day = try #require(testDate(year: 2026, month: 6, day: 29, calendar: calendar))
        let dayKey = DayPlanStorage.dayKey(for: day, calendar: calendar)
        let taskID = try #require(UUID(uuidString: "51515151-5151-5151-5151-515151515151"))
        let blockID = try #require(UUID(uuidString: "52525252-5252-5252-5252-525252525252"))
        let completedAt = try #require(calendar.date(byAdding: .hour, value: 11, to: day))

        let task = RoutineTask(
            id: taskID,
            name: "check work emails",
            scheduleMode: .oneOff,
            lastDone: completedAt
        )
        let block = DayPlanBlock(
            id: blockID,
            taskID: taskID,
            dayKey: dayKey,
            startMinute: 10 * 60,
            durationMinutes: 30,
            titleSnapshot: "check work emails"
        )

        let items = DayPlanDayTaskListPresentation.items(
            on: day,
            timedBlocks: [block],
            allDayBlocks: [],
            tasks: [task],
            calendar: calendar
        )

        #expect(items.map(\.title) == ["check work emails"])
        #expect(items.map(\.section) == [.done])
        #expect(DayPlanDayTaskCounts(items: items) == DayPlanDayTaskCounts(done: 1))
    }

    @Test
    func unassignedFocusBlocksRenderInDoneSection() throws {
        let calendar = testCalendar
        let day = try #require(testDate(year: 2026, month: 6, day: 29, calendar: calendar))
        let dayKey = DayPlanStorage.dayKey(for: day, calendar: calendar)
        let firstSessionID = try #require(UUID(uuidString: "51515151-5151-5151-5151-515151515152"))
        let secondSessionID = try #require(UUID(uuidString: "51515151-5151-5151-5151-515151515153"))

        let firstFocusBlock = DayPlanBlock(
            id: firstSessionID,
            taskID: FocusSession.unassignedTaskID,
            dayKey: dayKey,
            startMinute: 9 * 60 + 36,
            durationMinutes: 57,
            titleSnapshot: "#HSE"
        )
        let secondFocusBlock = DayPlanBlock(
            id: secondSessionID,
            taskID: FocusSession.unassignedTaskID,
            dayKey: dayKey,
            startMinute: 11 * 60 + 19,
            durationMinutes: 21,
            titleSnapshot: "#HSE"
        )

        let items = DayPlanDayTaskListPresentation.items(
            on: day,
            timedBlocks: [secondFocusBlock, firstFocusBlock],
            allDayBlocks: [],
            calendar: calendar
        )

        #expect(items.map(\.title) == ["#HSE", "#HSE"])
        #expect(items.map(\.section) == [.done, .done])
        #expect(items.map(\.placement) == [
            .timed(startMinute: 9 * 60 + 36, durationMinutes: 57),
            .timed(startMinute: 11 * 60 + 19, durationMinutes: 21),
        ])
        #expect(DayPlanDayTaskCounts(items: items) == DayPlanDayTaskCounts(done: 2))
    }

    @Test
    func completedOneOffPlannerBlockWithoutSelectedDayCompletionIsOmitted() throws {
        let calendar = testCalendar
        let day = try #require(testDate(year: 2026, month: 6, day: 29, calendar: calendar))
        let nextDay = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        let dayKey = DayPlanStorage.dayKey(for: day, calendar: calendar)
        let taskID = try #require(UUID(uuidString: "53535353-5353-5353-5353-535353535353"))
        let blockID = try #require(UUID(uuidString: "54545454-5454-5454-5454-545454545454"))

        let task = RoutineTask(
            id: taskID,
            name: "Already finished tomorrow",
            scheduleMode: .oneOff,
            lastDone: nextDay
        )
        let block = DayPlanBlock(
            id: blockID,
            taskID: taskID,
            dayKey: dayKey,
            startMinute: 9 * 60,
            durationMinutes: 30,
            titleSnapshot: "Already finished tomorrow"
        )

        let items = DayPlanDayTaskListPresentation.items(
            on: day,
            timedBlocks: [block],
            allDayBlocks: [],
            tasks: [task],
            calendar: calendar
        )

        #expect(items.isEmpty)
    }

    @Test
    func completedPlannedDateRoutineUsesDoneActivityWithoutPlannerConfirmation() throws {
        let calendar = testCalendar
        let day = try #require(testDate(year: 2026, month: 6, day: 29, calendar: calendar))
        let dayKey = DayPlanStorage.dayKey(for: day, calendar: calendar)
        let taskID = try #require(UUID(uuidString: "57575757-5757-5757-5757-575757575757"))
        let logID = try #require(UUID(uuidString: "58585858-5858-5858-5858-585858585858"))
        let completedAt = try #require(calendar.date(byAdding: .hour, value: 10, to: day))

        let task = RoutineTask(
            id: taskID,
            name: "Review pull requests",
            scheduleMode: .fixedInterval,
            lastDone: completedAt
        )
        task.plannedDate = day
        let log = RoutineLog(
            id: logID,
            timestamp: completedAt,
            taskID: taskID,
            kind: .completed
        )
        let done = DayPlanTimelineActivityBlock(
            block: DayPlanBlock(
                id: taskID,
                taskID: taskID,
                dayKey: dayKey,
                startMinute: 9 * 60 + 30,
                durationMinutes: 30,
                titleSnapshot: "Review pull requests"
            ),
            kind: .completed,
            source: .log(logID)
        )

        let items = DayPlanDayTaskListPresentation.items(
            on: day,
            timedBlocks: [],
            allDayBlocks: [],
            plannedDateTasks: [task],
            timelineActivityBlocks: [done],
            tasks: [task],
            logs: [log],
            calendar: calendar
        )

        #expect(items.map(\.title) == ["Review pull requests"])
        #expect(items.map(\.section) == [.done])
        #expect(items.map(\.placement) == [
            .timed(startMinute: 9 * 60 + 30, durationMinutes: 30),
        ])
        #expect(DayPlanDayTaskCounts(items: items) == DayPlanDayTaskCounts(done: 1))
    }

    @Test
    func completedPlannedDateRoutineIsNotPlannedWhenDoneLayerIsHidden() throws {
        let calendar = testCalendar
        let day = try #require(testDate(year: 2026, month: 6, day: 29, calendar: calendar))
        let taskID = try #require(UUID(uuidString: "59595959-5959-5959-5959-595959595959"))
        let completedAt = try #require(calendar.date(byAdding: .hour, value: 10, to: day))

        let task = RoutineTask(
            id: taskID,
            name: "Write report",
            scheduleMode: .fixedInterval,
            lastDone: completedAt
        )
        task.plannedDate = day

        let items = DayPlanDayTaskListPresentation.items(
            on: day,
            timedBlocks: [],
            allDayBlocks: [],
            plannedDateTasks: [task],
            tasks: [task],
            calendar: calendar
        )

        #expect(items.isEmpty)
    }

    @Test
    func itemsGroupPlannedAssumedDoneAndDoneSections() throws {
        let calendar = testCalendar
        let day = try #require(testDate(year: 2026, month: 6, day: 29, calendar: calendar))
        let dayKey = DayPlanStorage.dayKey(for: day, calendar: calendar)
        let plannedTaskID = try #require(UUID(uuidString: "61616161-6161-6161-6161-616161616161"))
        let assumedTaskID = try #require(UUID(uuidString: "62626262-6262-6262-6262-626262626262"))
        let doneTaskID = try #require(UUID(uuidString: "63636363-6363-6363-6363-636363636363"))
        let missedTaskID = try #require(UUID(uuidString: "64646464-6464-6464-6464-646464646464"))
        let doneLogID = try #require(UUID(uuidString: "65656565-6565-6565-6565-656565656565"))
        let missedLogID = try #require(UUID(uuidString: "66666666-6666-6666-6666-666666666666"))

        let plannedTask = RoutineTask(
            id: plannedTaskID,
            name: "Monday plan",
            scheduleMode: .oneOff
        )
        plannedTask.plannedDate = day

        let assumedDone = DayPlanTimelineActivityBlock(
            block: DayPlanBlock(
                id: assumedTaskID,
                taskID: assumedTaskID,
                dayKey: dayKey,
                startMinute: 8 * 60,
                durationMinutes: 30,
                titleSnapshot: "Morning reset"
            ),
            kind: .completed,
            source: .assumedDone
        )
        let done = DayPlanTimelineActivityBlock(
            block: DayPlanBlock(
                id: doneTaskID,
                taskID: doneTaskID,
                dayKey: dayKey,
                startMinute: 9 * 60,
                durationMinutes: 45,
                titleSnapshot: "Inbox review"
            ),
            kind: .completed,
            source: .log(doneLogID)
        )
        let missed = DayPlanTimelineActivityBlock(
            block: DayPlanBlock(
                id: missedTaskID,
                taskID: missedTaskID,
                dayKey: dayKey,
                startMinute: 10 * 60,
                durationMinutes: 20,
                titleSnapshot: "Missed call"
            ),
            kind: .missed,
            source: .log(missedLogID)
        )

        let items = DayPlanDayTaskListPresentation.items(
            on: day,
            timedBlocks: [],
            allDayBlocks: [],
            plannedDateTasks: [plannedTask],
            timelineActivityBlocks: [done, missed, assumedDone],
            calendar: calendar
        )

        #expect(items.map(\.title) == ["Monday plan", "Morning reset", "Inbox review"])
        #expect(items.map(\.section) == [.planned, .assumedDone, .done])
        #expect(items.map(\.placement) == [
            .allDay,
            .timed(startMinute: 8 * 60, durationMinutes: 30),
            .timed(startMinute: 9 * 60, durationMinutes: 45),
        ])
        #expect(DayPlanDayTaskCounts(items: items) == DayPlanDayTaskCounts(planned: 1, assumedDone: 1, done: 1))
    }

    @Test
    func assumedDoneActivityReplacesMatchingTimedPlannedRow() throws {
        let calendar = testCalendar
        let day = try #require(testDate(year: 2026, month: 6, day: 29, calendar: calendar))
        let dayKey = DayPlanStorage.dayKey(for: day, calendar: calendar)
        let taskID = try #require(UUID(uuidString: "67676767-6767-6767-6767-676767676767"))
        let plannedBlockID = try #require(UUID(uuidString: "68686868-6868-6868-6868-686868686868"))

        let plannedBlock = DayPlanBlock(
            id: plannedBlockID,
            taskID: taskID,
            dayKey: dayKey,
            startMinute: 21 * 60,
            durationMinutes: 5,
            titleSnapshot: "Brush Teeth"
        )
        let assumedDone = DayPlanTimelineActivityBlock(
            block: DayPlanBlock(
                id: taskID,
                taskID: taskID,
                dayKey: dayKey,
                startMinute: 12 * 60,
                durationMinutes: 5,
                titleSnapshot: "Brush Teeth"
            ),
            kind: .completed,
            source: .assumedDone
        )

        let items = DayPlanDayTaskListPresentation.items(
            on: day,
            timedBlocks: [plannedBlock],
            allDayBlocks: [],
            timelineActivityBlocks: [assumedDone],
            calendar: calendar
        )

        #expect(items.map(\.section) == [.assumedDone])
        #expect(items.map(\.title) == ["Brush Teeth"])
        #expect(items.map(\.placement) == [.timed(startMinute: 12 * 60, durationMinutes: 15)])
    }

    @Test
    func doneSectionIncludesLastDoneFallbackActivity() throws {
        let calendar = testCalendar
        let day = try #require(testDate(year: 2026, month: 6, day: 29, calendar: calendar))
        let dayKey = DayPlanStorage.dayKey(for: day, calendar: calendar)
        let taskID = try #require(UUID(uuidString: "67676767-6767-6767-6767-676767676767"))
        let updatedAt = try #require(calendar.date(byAdding: .hour, value: 14, to: day))

        let lastDone = DayPlanTimelineActivityBlock(
            block: DayPlanBlock(
                id: taskID,
                taskID: taskID,
                dayKey: dayKey,
                startMinute: 13 * 60 + 30,
                durationMinutes: 30,
                titleSnapshot: "Stretch",
                updatedAt: updatedAt
            ),
            kind: .completed,
            source: .taskLastDone
        )

        let items = DayPlanDayTaskListPresentation.items(
            on: day,
            timedBlocks: [],
            allDayBlocks: [],
            timelineActivityBlocks: [lastDone],
            calendar: calendar
        )

        #expect(items.map(\.title) == ["Stretch"])
        #expect(items.map(\.section) == [.done])
        #expect(DayPlanDayTaskCounts(items: items) == DayPlanDayTaskCounts(done: 1))
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func testDate(
        year: Int,
        month: Int,
        day: Int,
        calendar: Calendar
    ) -> Date? {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day
        )
        .date
    }
}
