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
        // Most recent day first
        #expect(groups[0].date == makeDate("2026-03-20T00:00:00Z"))
        #expect(groups[0].entries.count == 2)
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
