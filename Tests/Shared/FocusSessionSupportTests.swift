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
struct FocusSessionSupportTests {
    @Test
    func startUnassignedFocusCreatesCountUpSession() throws {
        let context = makeInMemoryContext()
        let sessionID = UUID()
        let startedAt = makeDate("2026-05-30T08:00:00Z")

        let session = try FocusSessionSupport.startUnassignedFocus(
            id: sessionID,
            startedAt: startedAt,
            context: context
        )

        #expect(session.id == sessionID)
        #expect(session.isUnassigned)
        #expect(session.startedAt == startedAt)
        #expect(session.plannedDurationSeconds == 0)
        #expect(session.state == .active)
    }

    @Test
    func startUnassignedFocusIsIdempotentForDuplicateWatchMessage() throws {
        let context = makeInMemoryContext()
        let sessionID = UUID()
        let startedAt = makeDate("2026-05-30T08:00:00Z")
        let repeatedAt = makeDate("2026-05-30T08:01:00Z")

        let first = try FocusSessionSupport.startUnassignedFocus(
            id: sessionID,
            startedAt: startedAt,
            context: context
        )
        let duplicate = try FocusSessionSupport.startUnassignedFocus(
            id: sessionID,
            startedAt: repeatedAt,
            context: context
        )

        #expect(first.id == duplicate.id)
        #expect(duplicate.startedAt == startedAt)
        #expect(try context.fetch(FetchDescriptor<FocusSession>()).count == 1)
    }

    @Test
    func finishUnassignedFocusCompletesSessionWithoutPlannerBlock() throws {
        let context = makeInMemoryContext()
        let sessionID = UUID()
        let startedAt = makeDate("2026-05-30T08:00:00Z")
        let endedAt = makeDate("2026-05-30T08:45:00Z")

        _ = try FocusSessionSupport.startUnassignedFocus(
            id: sessionID,
            startedAt: startedAt,
            context: context
        )

        let finished = try FocusSessionSupport.finishFocus(
            sessionID: sessionID,
            kind: .unassigned,
            endedAt: endedAt,
            context: context,
            calendar: makeTestCalendar()
        )

        let session = try #require(try context.fetch(FetchDescriptor<FocusSession>()).first)
        #expect(finished)
        #expect(session.completedAt == endedAt)
        #expect(session.actualDurationSeconds == 45 * 60)
        #expect(try context.fetch(FetchDescriptor<DayPlanBlockRecord>()).isEmpty)
    }

    @Test
    func finishUnassignedFocusDoesNotFinishTaskFocusWithoutMatchingKind() throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Write", interval: 1, lastDone: nil, emoji: nil)
        let taskFocus = FocusSession(
            taskID: task.id,
            startedAt: makeDate("2026-05-30T08:00:00Z"),
            plannedDurationSeconds: 0
        )
        context.insert(taskFocus)
        try context.save()

        let finished = try FocusSessionSupport.finishFocus(
            sessionID: nil,
            kind: .unassigned,
            endedAt: makeDate("2026-05-30T08:30:00Z"),
            context: context
        )

        #expect(!finished)
        #expect(taskFocus.state == .active)
    }

    @Test
    func assignUnassignedFocusToTaskKeepsFocusHistory() throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: nil)
        let sessionID = UUID()
        _ = try FocusSessionSupport.startUnassignedFocus(
            id: sessionID,
            startedAt: makeDate("2026-05-30T08:00:00Z"),
            context: context
        )
        _ = try FocusSessionSupport.finishFocus(
            sessionID: sessionID,
            kind: .unassigned,
            endedAt: makeDate("2026-05-30T08:30:00Z"),
            context: context
        )

        let assigned = try FocusSessionSupport.assignUnassignedFocus(
            sessionID: sessionID,
            toTask: task.id,
            context: context
        )

        let session = try #require(try context.fetch(FetchDescriptor<FocusSession>()).first)
        #expect(assigned)
        #expect(!session.isUnassigned)
        #expect(session.taskID == task.id)
        #expect(session.state == .completed)
    }

    @Test
    func assignUnassignedFocusToSprintConvertsToSprintFocusHistory() throws {
        let context = makeInMemoryContext()
        let sprint = BoardSprintRecord(
            title: "Current board",
            status: .active,
            createdAt: makeDate("2026-05-30T07:00:00Z"),
            startedAt: makeDate("2026-05-30T07:00:00Z")
        )
        context.insert(sprint)
        let sessionID = UUID()
        let startedAt = makeDate("2026-05-30T08:00:00Z")
        let endedAt = makeDate("2026-05-30T08:30:00Z")
        _ = try FocusSessionSupport.startUnassignedFocus(
            id: sessionID,
            startedAt: startedAt,
            context: context
        )
        _ = try FocusSessionSupport.finishFocus(
            sessionID: sessionID,
            kind: .unassigned,
            endedAt: endedAt,
            context: context
        )

        let assigned = try FocusSessionSupport.assignUnassignedFocusToSprint(
            sessionID: sessionID,
            sprintID: sprint.id,
            context: context
        )

        let focusSessions = try context.fetch(FetchDescriptor<FocusSession>())
        let sprintSessions = try context.fetch(FetchDescriptor<SprintFocusSessionRecord>())
        let sprintSession = try #require(sprintSessions.first)
        #expect(assigned)
        #expect(focusSessions.isEmpty)
        #expect(sprintSessions.count == 1)
        #expect(sprintSession.id == sessionID)
        #expect(sprintSession.sprintID == sprint.id)
        #expect(sprintSession.startedAt == startedAt)
        #expect(sprintSession.stoppedAt == endedAt)
    }
}
