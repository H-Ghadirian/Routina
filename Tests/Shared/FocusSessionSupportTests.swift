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
    func focusSessionDurationExcludesPausedIntervals() throws {
        let startedAt = makeDate("2026-05-30T08:00:00Z")
        let pausedAt = makeDate("2026-05-30T08:10:00Z")
        let resumedAt = makeDate("2026-05-30T08:30:00Z")
        let endedAt = makeDate("2026-05-30T08:45:00Z")
        let session = FocusSession(
            taskID: UUID(),
            startedAt: startedAt,
            plannedDurationSeconds: 0
        )

        #expect(session.activeDurationSeconds(at: pausedAt) == 10 * 60)
        #expect(session.pause(at: pausedAt))
        #expect(session.activeDurationSeconds(at: resumedAt) == 10 * 60)
        #expect(session.resume(at: resumedAt))
        #expect(session.accumulatedPausedSeconds == 20 * 60)
        #expect(session.activeDurationSeconds(at: endedAt) == 25 * 60)

        session.completedAt = endedAt
        #expect(session.actualDurationSeconds == 25 * 60)
    }

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
    func startTaskFocusCreatesPlannerBlock() throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let task = makeTask(in: context, name: "Write", interval: 1, lastDone: nil, emoji: nil)
        let startedAt = makeDate("2026-05-30T08:15:00Z")

        let session = try FocusSessionSupport.startTaskFocus(
            task: task,
            startedAt: startedAt,
            plannedDurationSeconds: 45 * 60,
            context: context,
            calendar: calendar
        )

        let plannerBlock = try #require(try context.fetch(FetchDescriptor<DayPlanBlockRecord>()).first)
        #expect(session.taskID == task.id)
        #expect(session.plannedDurationSeconds == 45 * 60)
        #expect(plannerBlock.id == session.id)
        #expect(plannerBlock.taskID == task.id)
        #expect(plannerBlock.startMinute == 8 * 60 + 15)
        #expect(plannerBlock.durationMinutes == 45)
    }

    @Test
    func startTagFocusCreatesPlannerBlock() throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let startedAt = makeDate("2026-05-30T08:15:00Z")

        let session = try FocusSessionSupport.startTagFocus(
            tagName: "Admin",
            startedAt: startedAt,
            plannedDurationSeconds: 45 * 60,
            context: context,
            calendar: calendar
        )

        let plannerBlock = try #require(try context.fetch(FetchDescriptor<DayPlanBlockRecord>()).first)
        #expect(session.isTagFocus)
        #expect(!session.isUnassigned)
        #expect(session.taskID == FocusSession.unassignedTaskID)
        #expect(session.focusTagName == "Admin")
        #expect(session.plannedDurationSeconds == 45 * 60)
        #expect(plannerBlock.id == session.id)
        #expect(plannerBlock.taskID == FocusSession.unassignedTaskID)
        #expect(plannerBlock.titleSnapshot == "#Admin")
        #expect(plannerBlock.startMinute == 8 * 60 + 15)
        #expect(plannerBlock.durationMinutes == 45)
    }

    @Test
    func finishCountUpTagFocusUpdatesPlannerBlockToFocusedDuration() throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let startedAt = makeDate("2026-05-30T08:00:00Z")
        let endedAt = makeDate("2026-05-30T08:12:00Z")

        let session = try FocusSessionSupport.startTagFocus(
            tagName: "Admin",
            startedAt: startedAt,
            plannedDurationSeconds: 0,
            context: context,
            calendar: calendar
        )
        let finished = try FocusSessionSupport.finishFocus(
            sessionID: session.id,
            kind: .tag,
            endedAt: endedAt,
            context: context,
            calendar: calendar
        )

        let plannerBlock = try #require(try context.fetch(FetchDescriptor<DayPlanBlockRecord>()).first)
        #expect(finished)
        #expect(session.completedAt == endedAt)
        #expect(plannerBlock.id == session.id)
        #expect(plannerBlock.titleSnapshot == "#Admin")
        #expect(plannerBlock.durationMinutes == 12)
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
    func finishPausedUnassignedFocusCountsOnlyFocusedTime() throws {
        let context = makeInMemoryContext()
        let sessionID = UUID()
        let startedAt = makeDate("2026-05-30T08:00:00Z")
        let pausedAt = makeDate("2026-05-30T08:10:00Z")
        let endedAt = makeDate("2026-05-30T08:30:00Z")

        _ = try FocusSessionSupport.startUnassignedFocus(
            id: sessionID,
            startedAt: startedAt,
            context: context
        )
        let paused = try FocusSessionSupport.pauseFocus(
            sessionID: sessionID,
            kind: .unassigned,
            pausedAt: pausedAt,
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
        #expect(paused)
        #expect(finished)
        #expect(session.completedAt == endedAt)
        #expect(session.pausedAt == nil)
        #expect(session.accumulatedPausedSeconds == 20 * 60)
        #expect(session.actualDurationSeconds == 10 * 60)
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
