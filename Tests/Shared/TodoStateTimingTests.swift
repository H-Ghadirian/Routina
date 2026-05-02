import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct TodoStateTimingTests {
    @Test
    func summary_countsDaysAcrossStateChanges() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let task = RoutineTask(
            name: "Ship report",
            scheduleMode: .oneOff,
            createdAt: makeDate("2026-01-01T09:00:00Z")
        )
        task.changeLogEntries = [
            RoutineTaskChangeLogEntry(
                timestamp: makeDate("2026-01-01T09:00:00Z"),
                kind: .created
            ),
            RoutineTaskChangeLogEntry(
                timestamp: makeDate("2026-01-03T10:00:00Z"),
                kind: .stateChanged,
                previousValue: "Ready",
                newValue: "In Progress"
            ),
            RoutineTaskChangeLogEntry(
                timestamp: makeDate("2026-01-05T12:00:00Z"),
                kind: .stateChanged,
                previousValue: "In Progress",
                newValue: "Blocked"
            ),
            RoutineTaskChangeLogEntry(
                timestamp: makeDate("2026-01-06T12:00:00Z"),
                kind: .stateChanged,
                previousValue: "Blocked",
                newValue: "Ready"
            )
        ]

        let summary = TodoStateTiming.summary(
            for: task,
            referenceDate: makeDate("2026-01-08T09:00:00Z"),
            calendar: calendar
        )

        #expect(summary?.currentState == .ready)
        #expect(summary?.currentStateElapsedDays == 2)
        #expect(summary?.totalDays(for: .ready) == 4)
        #expect(summary?.totalDays(for: .inProgress) == 2)
        #expect(summary?.totalDays(for: .blocked) == 1)
        #expect(summary?.totalDays(for: .paused) == 0)
    }

    @Test
    func summary_reportsCreationToDoneLeadTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let task = RoutineTask(
            name: "Fix bug",
            scheduleMode: .oneOff,
            lastDone: makeDate("2026-01-07T18:00:00Z"),
            createdAt: makeDate("2026-01-01T09:00:00Z"),
            todoStateRawValue: TodoState.inProgress.rawValue
        )
        task.changeLogEntries = [
            RoutineTaskChangeLogEntry(
                timestamp: makeDate("2026-01-01T09:00:00Z"),
                kind: .created
            ),
            RoutineTaskChangeLogEntry(
                timestamp: makeDate("2026-01-02T10:00:00Z"),
                kind: .stateChanged,
                previousValue: "Ready",
                newValue: "In Progress"
            ),
            RoutineTaskChangeLogEntry(
                timestamp: makeDate("2026-01-07T18:00:00Z"),
                kind: .stateChanged,
                previousValue: "In Progress",
                newValue: "Done"
            )
        ]

        let summary = TodoStateTiming.summary(
            for: task,
            referenceDate: makeDate("2026-01-10T09:00:00Z"),
            calendar: calendar
        )

        #expect(summary?.completedAt == makeDate("2026-01-07T18:00:00Z"))
        #expect(summary?.completedLeadDays == 6)
        #expect(summary?.currentState == nil)
        #expect(summary?.totalDays(for: .ready) == 1)
        #expect(summary?.totalDays(for: .inProgress) == 5)
    }

    @Test
    func summary_usesCurrentStoredStateWhenNoHistoryExists() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let task = RoutineTask(
            name: "Wait on review",
            scheduleMode: .oneOff,
            createdAt: makeDate("2026-01-01T09:00:00Z"),
            todoStateRawValue: TodoState.blocked.rawValue
        )
        task.changeLogEntries = [
            RoutineTaskChangeLogEntry(
                timestamp: makeDate("2026-01-01T09:00:00Z"),
                kind: .created
            )
        ]

        let summary = TodoStateTiming.summary(
            for: task,
            referenceDate: makeDate("2026-01-04T09:00:00Z"),
            calendar: calendar
        )

        #expect(summary?.currentState == .blocked)
        #expect(summary?.currentStateElapsedDays == 3)
        #expect(summary?.totalDays(for: .blocked) == 3)
    }

    @Test
    func stateParser_acceptsRawValuesAndDisplayTitles() {
        #expect(TodoStateTiming.state(from: "inProgress") == .inProgress)
        #expect(TodoStateTiming.state(from: "In Progress") == .inProgress)
        #expect(TodoStateTiming.state(from: "blocked") == .blocked)
        #expect(TodoStateTiming.state(from: "Paused") == .paused)
    }
}
