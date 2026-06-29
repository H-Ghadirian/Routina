import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct TimelineLogicTests {

    // MARK: - Helpers

    private func makeRoutineTask(
        id: UUID = UUID(),
        name: String = "Test Routine",
        emoji: String = "🔧",
        tags: [String] = [],
        scheduleMode: RoutineScheduleMode = .fixedInterval
    ) -> RoutineTask {
        RoutineTask(
            id: id,
            name: name,
            emoji: emoji,
            tags: tags,
            scheduleMode: scheduleMode
        )
    }

    private func makeTodoTask(
        id: UUID = UUID(),
        name: String = "Test Todo",
        emoji: String = "📝",
        tags: [String] = []
    ) -> RoutineTask {
        RoutineTask(
            id: id,
            name: name,
            emoji: emoji,
            tags: tags,
            scheduleMode: .oneOff
        )
    }

    private func makeLog(
        id: UUID = UUID(),
        taskID: UUID,
        timestamp: Date,
        kind: RoutineLogKind = .completed
    ) -> RoutineLog {
        RoutineLog(id: id, timestamp: timestamp, taskID: taskID, kind: kind)
    }

    // MARK: - filteredEntries

    @Test
    func timelinePigmentCasesUsePrimaryTimelineTypes() {
        #expect(TimelineFilterType.timelinePigmentCases == [
            .all,
            .routines,
            .todos,
            .focus,
            .notes,
            .places,
            .emotions,
            .sleep,
            .away,
        ])
        #expect(TimelineFilterType.timelinePigmentCases.allSatisfy { $0.isTimelinePigmentCase })
        #expect(TimelineFilterType.events.isTimelinePigmentCase == false)
        #expect(TimelineFilterType.done.isTimelinePigmentCase == false)
    }

    @Test
    func timelineVisibleCasesCanHideEventAndEmotionFilters() {
        #expect(TimelineFilterType.visibleContentTypeCases(includingEventEmotion: false) == [
            .all,
            .routines,
            .todos,
            .focus,
            .notes,
            .places,
            .sleep,
            .away,
        ])
        #expect(TimelineFilterType.visibleTimelinePigmentCases(includingEventEmotion: false) == [
            .all,
            .routines,
            .todos,
            .focus,
            .notes,
            .places,
            .sleep,
            .away,
        ])
        #expect(TimelineFilterType.visibleCases(includingEventEmotion: false).contains(.events) == false)
        #expect(TimelineFilterType.visibleCases(includingEventEmotion: false).contains(.emotions) == false)
        #expect(TimelineFilterType.events.normalized(includingEventEmotion: false) == .all)
        #expect(TimelineFilterType.emotions.normalized(includingEventEmotion: false) == .all)
    }

    @Test
    func timelineVisibleCasesCanHidePlaceFilters() {
        #expect(TimelineFilterType.visibleContentTypeCases(includingEventEmotion: true, includingPlaces: false) == [
            .all,
            .routines,
            .todos,
            .focus,
            .events,
            .emotions,
            .notes,
            .sleep,
            .away,
        ])
        #expect(TimelineFilterType.visibleTimelinePigmentCases(includingEventEmotion: true, includingPlaces: false) == [
            .all,
            .routines,
            .todos,
            .focus,
            .notes,
            .emotions,
            .sleep,
            .away,
        ])
        #expect(TimelineFilterType.visibleCases(includingEventEmotion: true, includingPlaces: false).contains(.places) == false)
        #expect(TimelineFilterType.places.normalized(includingEventEmotion: true, includingPlaces: false) == .all)
    }

    @Test
    func timelineVisibleCasesCanHideSleepFilters() {
        #expect(TimelineFilterType.visibleContentTypeCases(includingEventEmotion: true, includingSleep: false) == [
            .all,
            .routines,
            .todos,
            .focus,
            .events,
            .emotions,
            .notes,
            .places,
            .away,
        ])
        #expect(TimelineFilterType.visibleTimelinePigmentCases(includingEventEmotion: true, includingSleep: false) == [
            .all,
            .routines,
            .todos,
            .focus,
            .notes,
            .places,
            .emotions,
            .away,
        ])
        #expect(TimelineFilterType.visibleCases(includingEventEmotion: true, includingSleep: false).contains(.sleep) == false)
        #expect(TimelineFilterType.sleep.normalized(includingEventEmotion: true, includingSleep: false) == .all)
    }

    @Test
    func filteredEntries_returnsAllEntriesForAllRange() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let task = makeRoutineTask()
        let log1 = makeLog(taskID: task.id, timestamp: makeDate("2026-01-15T08:00:00Z"))
        let log2 = makeLog(taskID: task.id, timestamp: makeDate("2026-03-20T09:00:00Z"))

        let entries = TimelineLogic.filteredEntries(
            logs: [log1, log2],
            tasks: [task],
            range: .all,
            filterType: .all,
            now: now,
            calendar: calendar
        )

        #expect(entries.count == 2)
    }

    @Test
    func filteredEntries_todayRangeExcludesYesterdayLogs() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let task = makeRoutineTask()
        let todayLog = makeLog(taskID: task.id, timestamp: makeDate("2026-03-20T08:00:00Z"))
        let yesterdayLog = makeLog(taskID: task.id, timestamp: makeDate("2026-03-19T23:00:00Z"))

        let entries = TimelineLogic.filteredEntries(
            logs: [todayLog, yesterdayLog],
            tasks: [task],
            range: .today,
            filterType: .all,
            now: now,
            calendar: calendar
        )

        #expect(entries.count == 1)
        #expect(entries[0].id == todayLog.id)
    }

    @Test
    func filteredEntries_weekRangeExcludesOldLogs() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let task = makeRoutineTask()
        let recentLog = makeLog(taskID: task.id, timestamp: makeDate("2026-03-15T08:00:00Z"))
        let oldLog = makeLog(taskID: task.id, timestamp: makeDate("2026-03-10T08:00:00Z"))

        let entries = TimelineLogic.filteredEntries(
            logs: [recentLog, oldLog],
            tasks: [task],
            range: .week,
            filterType: .all,
            now: now,
            calendar: calendar
        )

        #expect(entries.count == 1)
        #expect(entries[0].id == recentLog.id)
    }

    @Test
    func filteredEntries_monthRangeExcludesOldLogs() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let task = makeRoutineTask()
        let recentLog = makeLog(taskID: task.id, timestamp: makeDate("2026-03-01T08:00:00Z"))
        let oldLog = makeLog(taskID: task.id, timestamp: makeDate("2026-01-15T08:00:00Z"))

        let entries = TimelineLogic.filteredEntries(
            logs: [recentLog, oldLog],
            tasks: [task],
            range: .month,
            filterType: .all,
            now: now,
            calendar: calendar
        )

        #expect(entries.count == 1)
        #expect(entries[0].id == recentLog.id)
    }

    @Test
    func filteredEntries_routinesFilterExcludesTodos() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let routine = makeRoutineTask(name: "Routine")
        let todo = makeTodoTask(name: "Todo")
        let routineLog = makeLog(taskID: routine.id, timestamp: makeDate("2026-03-20T08:00:00Z"))
        let todoLog = makeLog(taskID: todo.id, timestamp: makeDate("2026-03-20T09:00:00Z"))

        let entries = TimelineLogic.filteredEntries(
            logs: [routineLog, todoLog],
            tasks: [routine, todo],
            range: .all,
            filterType: .routines,
            now: now,
            calendar: calendar
        )

        #expect(entries.count == 1)
        #expect(entries[0].taskName == "Routine")
        #expect(entries[0].isOneOff == false)
    }

    @Test
    func filteredEntries_todosFilterExcludesRoutines() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let routine = makeRoutineTask(name: "Routine")
        let todo = makeTodoTask(name: "Todo")
        let routineLog = makeLog(taskID: routine.id, timestamp: makeDate("2026-03-20T08:00:00Z"))
        let todoLog = makeLog(taskID: todo.id, timestamp: makeDate("2026-03-20T09:00:00Z"))

        let entries = TimelineLogic.filteredEntries(
            logs: [routineLog, todoLog],
            tasks: [routine, todo],
            range: .all,
            filterType: .todos,
            now: now,
            calendar: calendar
        )

        #expect(entries.count == 1)
        #expect(entries[0].taskName == "Todo")
        #expect(entries[0].isOneOff == true)
    }

    @Test
    func filteredEntries_outcomeFiltersMatchLogKind() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let task = makeRoutineTask(name: "Routine")
        let doneLog = makeLog(taskID: task.id, timestamp: makeDate("2026-03-20T08:00:00Z"), kind: .completed)
        let missedLog = makeLog(taskID: task.id, timestamp: makeDate("2026-03-19T08:00:00Z"), kind: .missed)
        let canceledLog = makeLog(taskID: task.id, timestamp: makeDate("2026-03-18T08:00:00Z"), kind: .canceled)
        let logs = [doneLog, missedLog, canceledLog]

        let doneEntries = TimelineLogic.filteredEntries(
            logs: logs,
            tasks: [task],
            range: .all,
            filterType: .done,
            now: now,
            calendar: calendar
        )
        let missedEntries = TimelineLogic.filteredEntries(
            logs: logs,
            tasks: [task],
            range: .all,
            filterType: .missed,
            now: now,
            calendar: calendar
        )
        let canceledEntries = TimelineLogic.filteredEntries(
            logs: logs,
            tasks: [task],
            range: .all,
            filterType: .canceled,
            now: now,
            calendar: calendar
        )

        #expect(doneEntries.map(\.id) == [doneLog.id])
        #expect(missedEntries.map(\.id) == [missedLog.id])
        #expect(canceledEntries.map(\.id) == [canceledLog.id])
    }

    @Test
    func filteredEntries_skipsLogsWithNilTimestamp() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let task = makeRoutineTask()
        let validLog = makeLog(taskID: task.id, timestamp: makeDate("2026-03-20T08:00:00Z"))
        let nilLog = RoutineLog(taskID: task.id) // timestamp defaults to nil

        let entries = TimelineLogic.filteredEntries(
            logs: [validLog, nilLog],
            tasks: [task],
            range: .all,
            filterType: .all,
            now: now,
            calendar: calendar
        )

        #expect(entries.count == 1)
        #expect(entries[0].id == validLog.id)
    }

    @Test
    func filteredEntries_orphanedLogShowsDeletedRoutine() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let orphanedTaskID = UUID()
        let log = makeLog(taskID: orphanedTaskID, timestamp: makeDate("2026-03-20T09:00:00Z"))

        let entries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [], // no matching task
            range: .all,
            filterType: .all,
            now: now,
            calendar: calendar
        )

        #expect(entries.count == 1)
        #expect(entries[0].taskName == "Deleted Routine")
        #expect(entries[0].taskEmoji == "🗑️")
    }

    @Test
    func filteredEntries_preservesTaskNameAndEmoji() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let task = makeRoutineTask(name: "Wash Dishes", emoji: "🧽")
        let log = makeLog(taskID: task.id, timestamp: makeDate("2026-03-20T08:00:00Z"))

        let entries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            range: .all,
            filterType: .all,
            now: now,
            calendar: calendar
        )

        #expect(entries.count == 1)
        #expect(entries[0].taskName == "Wash Dishes")
        #expect(entries[0].taskEmoji == "🧽")
    }

    @Test
    func filteredEntries_preservesCanceledKindForCanceledTodoLogs() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let task = makeTodoTask(name: "Skip errand")
        let log = makeLog(taskID: task.id, timestamp: makeDate("2026-03-20T08:00:00Z"), kind: .canceled)

        let entries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            range: .all,
            filterType: .all,
            now: now,
            calendar: calendar
        )

        #expect(entries.count == 1)
        #expect(entries[0].kind == .canceled)
        #expect(entries[0].isOneOff)
    }

    @Test
    func filteredEntries_emptyLogsReturnsEmpty() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")

        let entries = TimelineLogic.filteredEntries(
            logs: [],
            tasks: [],
            range: .all,
            filterType: .all,
            now: now,
            calendar: calendar
        )

        #expect(entries.isEmpty)
    }

    @Test
    func filteredEntries_includesSleepSessionsAndSupportsSleepFilter() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let task = makeRoutineTask(name: "Read")
        let log = makeLog(taskID: task.id, timestamp: makeDate("2026-03-20T08:00:00Z"))
        let startedAt = makeDate("2026-03-19T23:30:00Z")
        let endedAt = makeDate("2026-03-20T07:15:00Z")
        let sleepSession = SleepSession(startedAt: startedAt, endedAt: endedAt)

        let allEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            sleepSessions: [sleepSession],
            range: .all,
            filterType: .all,
            now: now,
            calendar: calendar
        )
        let sleepEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            sleepSessions: [sleepSession],
            range: .all,
            filterType: .sleep,
            now: now,
            calendar: calendar
        )
        let doneEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            sleepSessions: [sleepSession],
            range: .all,
            filterType: .done,
            now: now,
            calendar: calendar
        )

        let sleepEntry = allEntries.first { $0.id == sleepSession.id }
        #expect(allEntries.count == 2)
        #expect(sleepEntry?.isSleep == true)
        #expect(sleepEntry?.taskID == nil)
        #expect(sleepEntry?.timestamp == endedAt)
        #expect(sleepEntry?.startTimestamp == startedAt)
        #expect(sleepEntry?.endTimestamp == endedAt)
        #expect(sleepEntry?.durationSeconds == endedAt.timeIntervalSince(startedAt))
        #expect(sleepEntries.map(\.id) == [sleepSession.id])
        #expect(doneEntries.map(\.id) == [log.id])
    }

    @Test
    func filteredEntries_includesTaskFocusSessionsAtStartTimeAndSupportsFocusFilter() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let task = makeTodoTask(name: "Write brief", emoji: "✍️", tags: ["Focus"])
        let log = makeLog(taskID: task.id, timestamp: makeDate("2026-03-20T08:00:00Z"))
        let startedAt = makeDate("2026-03-20T09:00:00Z")
        let completedAt = makeDate("2026-03-20T09:25:00Z")
        let focusSession = FocusSession(
            taskID: task.id,
            startedAt: startedAt,
            completedAt: completedAt
        )

        let allEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            focusSessions: [focusSession],
            range: .all,
            filterType: .all,
            now: now,
            calendar: calendar
        )
        let focusEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            focusSessions: [focusSession],
            range: .all,
            filterType: .focus,
            now: now,
            calendar: calendar
        )
        let doneEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            focusSessions: [focusSession],
            range: .all,
            filterType: .done,
            now: now,
            calendar: calendar
        )

        let focusEntry = allEntries.first { $0.id == focusSession.id }
        #expect(allEntries.count == 2)
        #expect(focusEntry?.isFocus == true)
        #expect(focusEntry?.taskID == task.id)
        #expect(focusEntry?.taskName == "Write brief")
        #expect(focusEntry?.taskEmoji == "✍️")
        #expect(focusEntry?.tags == ["Focus"])
        #expect(focusEntry?.timestamp == startedAt)
        #expect(focusEntry?.startTimestamp == startedAt)
        #expect(focusEntry?.endTimestamp == completedAt)
        #expect(focusEntry?.durationSeconds == completedAt.timeIntervalSince(startedAt))
        #expect(focusEntry?.activityTitle == "Completed focus")
        #expect(focusEntries.map(\.id) == [focusSession.id])
        #expect(doneEntries.map(\.id) == [log.id])
    }

    @Test
    func filteredEntries_excludesAbandonedTaskFocusSessions() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let task = makeTodoTask(name: "Write brief", emoji: "✍️", tags: ["Focus"])
        let log = makeLog(taskID: task.id, timestamp: makeDate("2026-03-20T08:00:00Z"))
        let startedAt = makeDate("2026-03-20T09:00:00Z")
        let abandonedAt = makeDate("2026-03-20T09:05:00Z")
        let focusSession = FocusSession(
            taskID: task.id,
            startedAt: startedAt,
            abandonedAt: abandonedAt
        )

        let allEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            focusSessions: [focusSession],
            range: .all,
            filterType: .all,
            now: now,
            calendar: calendar
        )
        let focusEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            focusSessions: [focusSession],
            range: .all,
            filterType: .focus,
            now: now,
            calendar: calendar
        )

        #expect(allEntries.map(\.id) == [log.id])
        #expect(focusEntries.isEmpty)
    }

    @Test
    func filteredEntries_includesActiveBoardFocusSessions() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let task = makeRoutineTask(name: "Read")
        let log = makeLog(taskID: task.id, timestamp: makeDate("2026-03-20T08:00:00Z"))
        let sprint = BoardSprintRecord(
            title: "Launch board",
            startedAt: makeDate("2026-03-20T07:00:00Z")
        )
        let startedAt = makeDate("2026-03-20T09:30:00Z")
        let focusSession = SprintFocusSessionRecord(
            sprintID: sprint.id,
            startedAt: startedAt
        )

        let allEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            focusSessions: [],
            sprintFocusSessions: [focusSession],
            boardSprints: [sprint],
            range: .all,
            filterType: .all,
            now: now,
            calendar: calendar
        )
        let focusEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            sprintFocusSessions: [focusSession],
            boardSprints: [sprint],
            range: .all,
            filterType: .focus,
            now: now,
            calendar: calendar
        )
        let mediaEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            sprintFocusSessions: [focusSession],
            boardSprints: [sprint],
            range: .all,
            filterType: .all,
            mediaFilter: .withImage,
            now: now,
            calendar: calendar
        )

        let focusEntry = allEntries.first { $0.id == focusSession.id }
        #expect(allEntries.count == 2)
        #expect(focusEntry?.isFocus == true)
        #expect(focusEntry?.taskID == nil)
        #expect(focusEntry?.taskName == "Launch board")
        #expect(focusEntry?.taskEmoji == "🎯")
        #expect(focusEntry?.timestamp == startedAt)
        #expect(focusEntry?.startTimestamp == startedAt)
        #expect(focusEntry?.endTimestamp == nil)
        #expect(focusEntry?.durationSeconds == now.timeIntervalSince(startedAt))
        #expect(focusEntry?.activityTitle == "Active board focus")
        #expect(focusEntries.map(\.id) == [focusSession.id])
        #expect(mediaEntries.isEmpty)
    }

    @Test
    func filteredEntries_includesPlaceCheckInsAndSupportsPlaceFilter() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let task = makeRoutineTask(name: "Read")
        let log = makeLog(taskID: task.id, timestamp: makeDate("2026-03-20T08:00:00Z"))
        let startedAt = makeDate("2026-03-20T09:00:00Z")
        let placeSession = PlaceCheckInSession(
            placeID: UUID(),
            placeName: "Office",
            activity: .work,
            imageData: Data([0x01]),
            startedAt: startedAt,
            endedAt: nil
        )

        let allEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            placeCheckInSessions: [placeSession],
            range: .all,
            filterType: .all,
            now: now,
            calendar: calendar
        )
        let placeEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            placeCheckInSessions: [placeSession],
            range: .all,
            filterType: .places,
            now: now,
            calendar: calendar
        )
        let doneEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            placeCheckInSessions: [placeSession],
            range: .all,
            filterType: .done,
            now: now,
            calendar: calendar
        )
        let imageEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            placeCheckInSessions: [placeSession],
            range: .all,
            filterType: .all,
            mediaFilter: .withImage,
            now: now,
            calendar: calendar
        )
        let fileEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            placeCheckInSessions: [placeSession],
            range: .all,
            filterType: .all,
            mediaFilter: .withFile,
            now: now,
            calendar: calendar
        )

        let placeEntry = allEntries.first { $0.id == placeSession.id }
        #expect(allEntries.count == 2)
        #expect(placeEntry?.isPlaceCheckIn == true)
        #expect(placeEntry?.taskID == nil)
        #expect(placeEntry?.taskName == "Office")
        #expect(placeEntry?.timestamp == startedAt)
        #expect(placeEntry?.startTimestamp == startedAt)
        #expect(placeEntry?.endTimestamp == nil)
        #expect(placeEntry?.activityTitle == "Work")
        #expect(placeEntry?.hasImage == true)
        #expect(placeEntry?.durationSeconds == now.timeIntervalSince(startedAt))
        #expect(placeEntries.map(\.id) == [placeSession.id])
        #expect(doneEntries.map(\.id) == [log.id])
        #expect(imageEntries.map(\.id) == [placeSession.id])
        #expect(fileEntries.isEmpty)
    }

    @Test
    func filteredEntries_includesStandaloneNotesAndSupportsNoteFilter() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let task = makeRoutineTask(name: "Read")
        let log = makeLog(taskID: task.id, timestamp: makeDate("2026-03-20T08:00:00Z"))
        let note = RoutineNote(
            title: "Job permit",
            body: "Collect supporting documents",
            tags: ["Admin", "Visa"],
            imageData: Data([0x01]),
            voiceNoteData: Data([0x02]),
            voiceNoteDurationSeconds: 2,
            voiceNoteCreatedAt: makeDate("2026-03-20T09:20:00Z"),
            createdAt: makeDate("2026-03-20T09:30:00Z"),
            updatedAt: makeDate("2026-03-20T09:30:00Z")
        )

        let allEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            notes: [note],
            noteAttachmentNoteIDs: [note.id],
            range: .all,
            filterType: .all,
            now: now,
            calendar: calendar
        )
        let noteEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            notes: [note],
            noteAttachmentNoteIDs: [note.id],
            range: .all,
            filterType: .notes,
            now: now,
            calendar: calendar
        )
        let doneEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            notes: [note],
            noteAttachmentNoteIDs: [note.id],
            range: .all,
            filterType: .done,
            now: now,
            calendar: calendar
        )
        let fileEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            notes: [note],
            noteAttachmentNoteIDs: [note.id],
            range: .all,
            filterType: .all,
            mediaFilter: .withFile,
            now: now,
            calendar: calendar
        )

        let noteEntry = allEntries.first { $0.id == note.id }
        #expect(allEntries.count == 2)
        #expect(noteEntry?.isNote == true)
        #expect(noteEntry?.taskID == nil)
        #expect(noteEntry?.taskName == "Job permit")
        #expect(noteEntry?.timestamp == makeDate("2026-03-20T09:30:00Z"))
        #expect(noteEntry?.hasImage == true)
        #expect(noteEntry?.hasFileAttachment == true)
        #expect(noteEntry?.hasVoiceNote == true)
        #expect(noteEntry?.tags == ["Admin", "Visa"])
        #expect(noteEntry?.searchableText.localizedCaseInsensitiveContains("supporting documents") == true)
        #expect(noteEntries.map(\.id) == [note.id])
        #expect(doneEntries.map(\.id) == [log.id])
        #expect(fileEntries.map(\.id) == [note.id])
    }

    @Test
    func filteredEntries_marksStatusNotesWithDistinctPresentation() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T12:00:00Z")
        let note = RoutineNote(
            body: "Reviewing sprint notes",
            tags: ["Status"],
            createdAt: makeDate("2026-03-20T09:30:00Z"),
            updatedAt: makeDate("2026-03-20T09:30:00Z")
        )

        let entries = TimelineLogic.filteredEntries(
            logs: [],
            tasks: [],
            notes: [note],
            range: .all,
            filterType: .all,
            now: now,
            calendar: calendar
        )

        #expect(entries.count == 1)
        #expect(entries.first?.isStatusNote == true)
        #expect(entries.first?.taskEmoji == "💬")
        #expect(entries.first?.taskName == "Reviewing sprint notes")
    }

    @Test
    func filteredEntries_includesStandaloneEventsAndSupportsEventFilter() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let task = makeRoutineTask(name: "Read")
        let log = makeLog(taskID: task.id, timestamp: makeDate("2026-03-20T08:00:00Z"))
        let event = RoutineEvent(
            title: "Sick day",
            notes: "Stayed home with fever",
            emoji: "🤒",
            tags: ["Health"],
            isAllDay: true,
            startedAt: makeDate("2026-03-20T00:00:00Z"),
            endedAt: makeDate("2026-03-21T00:00:00Z"),
            createdAt: makeDate("2026-03-20T09:30:00Z"),
            updatedAt: makeDate("2026-03-20T09:30:00Z")
        )

        let allEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            events: [event],
            range: .all,
            filterType: .all,
            now: now,
            calendar: calendar
        )
        let eventEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            events: [event],
            range: .all,
            filterType: .events,
            now: now,
            calendar: calendar
        )
        let doneEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            events: [event],
            range: .all,
            filterType: .done,
            now: now,
            calendar: calendar
        )
        let imageEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            events: [event],
            range: .all,
            filterType: .all,
            mediaFilter: .withImage,
            now: now,
            calendar: calendar
        )

        let eventEntry = allEntries.first { $0.id == event.id }
        #expect(allEntries.count == 2)
        #expect(eventEntry?.isEvent == true)
        #expect(eventEntry?.taskID == nil)
        #expect(eventEntry?.taskName == "Sick day")
        #expect(eventEntry?.taskEmoji == "🤒")
        #expect(eventEntry?.tags == ["Health"])
        #expect(eventEntry?.startTimestamp == makeDate("2026-03-20T00:00:00Z"))
        #expect(eventEntry?.endTimestamp == makeDate("2026-03-21T00:00:00Z"))
        #expect(eventEntry?.searchableText.localizedCaseInsensitiveContains("fever") == true)
        #expect(eventEntries.map(\.id) == [event.id])
        #expect(doneEntries.map(\.id) == [log.id])
        #expect(imageEntries.isEmpty)
    }

    @Test
    func filteredEntries_includesEmotionLogsAndSupportsEmotionFilter() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let task = makeRoutineTask(name: "Read")
        let log = makeLog(taskID: task.id, timestamp: makeDate("2026-03-20T08:00:00Z"))
        let emotion = EmotionLog(
            families: [.fear, .anger],
            labels: ["anxious", "frustrated"],
            valence: -0.7,
            arousal: 0.8,
            intensity: 4,
            bodyAreas: [.chest, .stomach],
            reflection: "Before the appointment",
            createdAt: makeDate("2026-03-20T09:45:00Z"),
            updatedAt: makeDate("2026-03-20T09:45:00Z")
        )

        let allEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            emotionLogs: [emotion],
            range: .all,
            filterType: .all,
            now: now,
            calendar: calendar
        )
        let emotionEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            emotionLogs: [emotion],
            range: .all,
            filterType: .emotions,
            now: now,
            calendar: calendar
        )
        let doneEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            emotionLogs: [emotion],
            range: .all,
            filterType: .done,
            now: now,
            calendar: calendar
        )
        let imageEntries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            emotionLogs: [emotion],
            range: .all,
            filterType: .all,
            mediaFilter: .withImage,
            now: now,
            calendar: calendar
        )

        let emotionEntry = allEntries.first { $0.id == emotion.id }
        #expect(allEntries.count == 2)
        #expect(emotionEntry?.isEmotion == true)
        #expect(emotionEntry?.taskID == nil)
        #expect(emotionEntry?.taskName == "Anxious, Frustrated")
        #expect(emotionEntry?.timestamp == makeDate("2026-03-20T09:45:00Z"))
        #expect(emotionEntry?.activityTitle == "Fear, Anger · 4/5")
        #expect(emotionEntry?.searchableText.localizedCaseInsensitiveContains("appointment") == true)
        #expect(emotionEntries.map(\.id) == [emotion.id])
        #expect(doneEntries.map(\.id) == [log.id])
        #expect(imageEntries.isEmpty)
    }

    @Test
    func filteredEntries_mediaFilterMatchesDoneEntriesWithImagesOrFiles() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let plainTask = makeRoutineTask(name: "Plain done")
        let imageTask = RoutineTask(
            name: "Image done",
            emoji: "🖼️",
            imageData: Data([1]),
            scheduleMode: .fixedInterval
        )
        let fileTask = makeRoutineTask(name: "File done")
        let bothTask = RoutineTask(
            name: "Image and file done",
            emoji: "📎",
            imageData: Data([1]),
            scheduleMode: .fixedInterval
        )
        let plainLog = makeLog(taskID: plainTask.id, timestamp: makeDate("2026-03-20T07:00:00Z"))
        let imageLog = makeLog(taskID: imageTask.id, timestamp: makeDate("2026-03-20T08:00:00Z"))
        let fileLog = makeLog(taskID: fileTask.id, timestamp: makeDate("2026-03-20T09:00:00Z"))
        let bothLog = makeLog(taskID: bothTask.id, timestamp: makeDate("2026-03-20T10:00:00Z"))
        let logs = [plainLog, imageLog, fileLog, bothLog]
        let tasks = [plainTask, imageTask, fileTask, bothTask]
        let fileAttachmentTaskIDs: Set<UUID> = [fileTask.id, bothTask.id]

        let anyMediaEntries = TimelineLogic.filteredEntries(
            logs: logs,
            tasks: tasks,
            fileAttachmentTaskIDs: fileAttachmentTaskIDs,
            range: .all,
            filterType: .done,
            mediaFilter: .anyMedia,
            now: now,
            calendar: calendar
        )
        let imageEntries = TimelineLogic.filteredEntries(
            logs: logs,
            tasks: tasks,
            fileAttachmentTaskIDs: fileAttachmentTaskIDs,
            range: .all,
            filterType: .done,
            mediaFilter: .withImage,
            now: now,
            calendar: calendar
        )
        let fileEntries = TimelineLogic.filteredEntries(
            logs: logs,
            tasks: tasks,
            fileAttachmentTaskIDs: fileAttachmentTaskIDs,
            range: .all,
            filterType: .done,
            mediaFilter: .withFile,
            now: now,
            calendar: calendar
        )

        #expect(Set(anyMediaEntries.map(\.taskName)) == ["Image done", "File done", "Image and file done"])
        #expect(Set(imageEntries.map(\.taskName)) == ["Image done", "Image and file done"])
        #expect(Set(fileEntries.map(\.taskName)) == ["File done", "Image and file done"])
        #expect(imageEntries.allSatisfy { $0.hasImage })
        #expect(fileEntries.allSatisfy { $0.hasFileAttachment })
    }

    // MARK: - groupedByDay

    @Test
    func groupedByDay_groupsEntriesByCalendarDay() {
        let calendar = makeTestCalendar()
        let entry1 = TimelineEntry(
            id: UUID(), taskID: nil, timestamp: makeDate("2026-03-20T08:00:00Z"),
            taskName: "A", taskEmoji: "🔧", tags: [], isOneOff: false, kind: .completed
        )
        let entry2 = TimelineEntry(
            id: UUID(), taskID: nil, timestamp: makeDate("2026-03-20T14:00:00Z"),
            taskName: "B", taskEmoji: "🔧", tags: [], isOneOff: false, kind: .completed
        )
        let entry3 = TimelineEntry(
            id: UUID(), taskID: nil, timestamp: makeDate("2026-03-19T10:00:00Z"),
            taskName: "C", taskEmoji: "🔧", tags: [], isOneOff: false, kind: .completed
        )

        let groups = TimelineLogic.groupedByDay(
            entries: [entry1, entry2, entry3],
            calendar: calendar
        )

        #expect(groups.count == 2)
        #expect(groups[0].date == makeDate("2026-03-20T00:00:00Z"))
        #expect(groups[0].entries.map(\.taskName) == ["B", "A"])
        #expect(groups[1].date == makeDate("2026-03-19T00:00:00Z"))
        #expect(groups[1].entries.count == 1)
    }

    @Test
    func groupedByDay_sortsDaysNewestFirst() {
        let calendar = makeTestCalendar()
        let march18 = TimelineEntry(
            id: UUID(), taskID: nil, timestamp: makeDate("2026-03-18T10:00:00Z"),
            taskName: "Old", taskEmoji: "🔧", tags: [], isOneOff: false, kind: .completed
        )
        let march20 = TimelineEntry(
            id: UUID(), taskID: nil, timestamp: makeDate("2026-03-20T10:00:00Z"),
            taskName: "New", taskEmoji: "🔧", tags: [], isOneOff: false, kind: .completed
        )

        let groups = TimelineLogic.groupedByDay(
            entries: [march18, march20],
            calendar: calendar
        )

        #expect(groups.count == 2)
        #expect(groups[0].date > groups[1].date)
    }

    @Test
    func groupedByDay_emptyEntriesReturnsEmpty() {
        let calendar = makeTestCalendar()

        let groups = TimelineLogic.groupedByDay(entries: [], calendar: calendar)

        #expect(groups.isEmpty)
    }

    // MARK: - daySectionTitle

    @Test
    func daySectionTitle_returnsYesterdayForYesterdaysDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let startOfYesterday = calendar.startOfDay(for: yesterday)

        let title = TimelineLogic.daySectionTitle(for: startOfYesterday, calendar: calendar)

        #expect(title == "Yesterday")
    }

    @Test
    func daySectionTitle_returnsTodayForTodaysDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let startOfToday = calendar.startOfDay(for: Date())

        let title = TimelineLogic.daySectionTitle(for: startOfToday, calendar: calendar)

        #expect(title == "Today")
    }

    @Test
    func daySectionTitle_returnsFormattedDateForOlderDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let oldDate = calendar.date(byAdding: .day, value: -10, to: Date())!
        let startOfOld = calendar.startOfDay(for: oldDate)

        let title = TimelineLogic.daySectionTitle(for: startOfOld, calendar: calendar)

        // Should not be "Today" or "Yesterday"
        #expect(title != "Today")
        #expect(title != "Yesterday")
        #expect(!title.isEmpty)
    }

    // MARK: - Combined range + filter scenarios

    @Test
    func filteredEntries_todayRangeWithTodosFilterOnlyShowsTodayTodos() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let routine = makeRoutineTask(name: "Routine")
        let todo = makeTodoTask(name: "Today Todo")
        let oldTodo = makeTodoTask(name: "Old Todo")

        let logs = [
            makeLog(taskID: routine.id, timestamp: makeDate("2026-03-20T08:00:00Z")),
            makeLog(taskID: todo.id, timestamp: makeDate("2026-03-20T09:00:00Z")),
            makeLog(taskID: oldTodo.id, timestamp: makeDate("2026-03-18T09:00:00Z")),
        ]

        let entries = TimelineLogic.filteredEntries(
            logs: logs,
            tasks: [routine, todo, oldTodo],
            range: .today,
            filterType: .todos,
            now: now,
            calendar: calendar
        )

        #expect(entries.count == 1)
        #expect(entries[0].taskName == "Today Todo")
    }

    @Test
    func filteredEntries_multipleLogsForSameTaskAllAppear() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let task = makeRoutineTask(name: "Daily Task")
        let log1 = makeLog(taskID: task.id, timestamp: makeDate("2026-03-18T08:00:00Z"))
        let log2 = makeLog(taskID: task.id, timestamp: makeDate("2026-03-19T08:00:00Z"))
        let log3 = makeLog(taskID: task.id, timestamp: makeDate("2026-03-20T08:00:00Z"))

        let entries = TimelineLogic.filteredEntries(
            logs: [log1, log2, log3],
            tasks: [task],
            range: .all,
            filterType: .all,
            now: now,
            calendar: calendar
        )

        #expect(entries.count == 3)
        #expect(entries.allSatisfy { $0.taskName == "Daily Task" })
    }

    @Test
    func filteredEntries_preservesTaskTags() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let task = makeRoutineTask(name: "Tagged Task", tags: ["Focus", "Morning"])
        let log = makeLog(taskID: task.id, timestamp: makeDate("2026-03-20T08:00:00Z"))

        let entries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [task],
            range: .all,
            filterType: .all,
            now: now,
            calendar: calendar
        )

        #expect(entries.count == 1)
        #expect(entries[0].tags == ["Focus", "Morning"])
    }

    @Test
    func matchesSelectedTag_returnsTrueForMatchingTag() {
        #expect(TimelineLogic.matchesSelectedTag("focus", in: ["Morning", "Focus"]))
    }

    @Test
    func matchesSelectedTag_returnsFalseForMissingTag() {
        #expect(TimelineLogic.matchesSelectedTag("health", in: ["Morning", "Focus"]) == false)
    }

    @Test
    func availableTags_collectsSortedUniqueTagsFromEntries() {
        let entries = [
            TimelineEntry(
                id: UUID(),
                taskID: UUID(),
                timestamp: makeDate("2026-03-20T08:00:00Z"),
                taskName: "A",
                taskEmoji: "🔧",
                tags: ["Focus", "Morning"],
                isOneOff: false,
                kind: .completed
            ),
            TimelineEntry(
                id: UUID(),
                taskID: UUID(),
                timestamp: makeDate("2026-03-20T09:00:00Z"),
                taskName: "B",
                taskEmoji: "📝",
                tags: ["focus", "Health"],
                isOneOff: true,
                kind: .completed
            )
        ]

        #expect(TimelineLogic.availableTags(from: entries) == ["Focus", "Health", "Morning"])
    }

    @Test
    func filterPresentationSuggestsRelatedTagsFromCurrentAnchor() {
        let presentation = TimelineFilterPresentation(
            selectedTags: ["Focus", "Admin"],
            excludedTags: [],
            includeTagMatchMode: .all,
            availableTags: ["Focus", "Admin", "Deep Work", "Errand"],
            relatedTagRules: [
                RoutineRelatedTagRule(tag: "Focus", relatedTags: ["Deep Work"]),
                RoutineRelatedTagRule(tag: "Admin", relatedTags: ["Errand"])
            ]
        )

        #expect(presentation.suggestedRelatedTags(suggestionAnchor: "Focus") == ["Deep Work"])
        #expect(presentation.suggestedRelatedTags(suggestionAnchor: nil) == ["Deep Work", "Errand"])
    }

    @Test
    func filterPresentationScopesExcludedTagsToIncludedEntries() {
        let entries = [
            TimelineEntry(
                id: UUID(),
                taskID: UUID(),
                timestamp: makeDate("2026-03-20T08:00:00Z"),
                taskName: "A",
                taskEmoji: "🔧",
                tags: ["Focus", "Deep Work"],
                isOneOff: false,
                kind: .completed
            ),
            TimelineEntry(
                id: UUID(),
                taskID: UUID(),
                timestamp: makeDate("2026-03-20T09:00:00Z"),
                taskName: "B",
                taskEmoji: "📝",
                tags: ["Errand"],
                isOneOff: true,
                kind: .completed
            )
        ]
        let presentation = TimelineFilterPresentation(
            selectedTags: ["Focus"],
            excludedTags: [],
            includeTagMatchMode: .all,
            availableTags: ["Focus", "Deep Work", "Errand"],
            relatedTagRules: []
        )

        #expect(presentation.availableExcludeTags(from: entries) == ["Deep Work"])
    }

    @Test
    func filteredEntries_toleratesDuplicateTaskIDs() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let sharedID = UUID()
        let firstTask = makeRoutineTask(id: sharedID, name: "First copy", emoji: "🥇")
        let secondTask = makeRoutineTask(id: sharedID, name: "Second copy", emoji: "🥈")
        let log = makeLog(taskID: sharedID, timestamp: makeDate("2026-03-20T08:00:00Z"))

        let entries = TimelineLogic.filteredEntries(
            logs: [log],
            tasks: [firstTask, secondTask],
            range: .all,
            filterType: .all,
            now: now,
            calendar: calendar
        )

        #expect(entries.count == 1)
        #expect(entries[0].taskName == "First copy")
        #expect(entries[0].taskEmoji == "🥇")
    }
}
