import Foundation
import Testing
#if os(macOS)
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
        timestamp: Date
    ) -> RoutineLog {
        RoutineLog(id: id, timestamp: timestamp, taskID: taskID)
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

    // MARK: - groupedByDay

    @Test
    func groupedByDay_groupsEntriesByCalendarDay() {
        let calendar = makeTestCalendar()
        let entry1 = TimelineEntry(
            id: UUID(), taskID: nil, timestamp: makeDate("2026-03-20T08:00:00Z"),
            taskName: "A", taskEmoji: "🔧", tags: [], isOneOff: false
        )
        let entry2 = TimelineEntry(
            id: UUID(), taskID: nil, timestamp: makeDate("2026-03-20T14:00:00Z"),
            taskName: "B", taskEmoji: "🔧", tags: [], isOneOff: false
        )
        let entry3 = TimelineEntry(
            id: UUID(), taskID: nil, timestamp: makeDate("2026-03-19T10:00:00Z"),
            taskName: "C", taskEmoji: "🔧", tags: [], isOneOff: false
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
            taskName: "Old", taskEmoji: "🔧", tags: [], isOneOff: false
        )
        let march20 = TimelineEntry(
            id: UUID(), taskID: nil, timestamp: makeDate("2026-03-20T10:00:00Z"),
            taskName: "New", taskEmoji: "🔧", tags: [], isOneOff: false
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
                isOneOff: false
            ),
            TimelineEntry(
                id: UUID(),
                taskID: UUID(),
                timestamp: makeDate("2026-03-20T09:00:00Z"),
                taskName: "B",
                taskEmoji: "📝",
                tags: ["focus", "Health"],
                isOneOff: true
            )
        ]

        #expect(TimelineLogic.availableTags(from: entries) == ["Focus", "Health", "Morning"])
    }
}
