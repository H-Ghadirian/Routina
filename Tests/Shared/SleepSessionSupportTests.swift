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

struct SleepSessionSupportTests {
    @MainActor
    @Test
    func startSleep_createsSingleActiveSessionUntilWake() throws {
        let context = makeInMemoryContext()
        let startedAt = makeDate("2026-05-09T22:45:00Z")
        let duplicateStart = makeDate("2026-05-09T23:10:00Z")
        let endedAt = makeDate("2026-05-10T06:40:00Z")

        let session = try SleepSessionSupport.startSleep(in: context, at: startedAt)
        let duplicate = try SleepSessionSupport.startSleep(in: context, at: duplicateStart)

        #expect(duplicate.id == session.id)
        #expect(try context.fetch(FetchDescriptor<SleepSession>()).count == 1)
        #expect(try SleepSessionSupport.activeSession(in: context)?.id == session.id)

        let endedSession = try #require(try SleepSessionSupport.endActiveSleep(in: context, at: endedAt))

        #expect(!endedSession.isActive)
        #expect(endedSession.endedAt == endedAt)
        #expect(try SleepSessionSupport.activeSession(in: context) == nil)
        #expect(endedSession.durationMinutes(referenceDate: endedAt) == 475)
    }

    @MainActor
    @Test
    func endActiveSleep_closesAllActiveSessions() throws {
        let context = makeInMemoryContext()
        let olderSession = SleepSession(
            id: UUID(),
            startedAt: makeDate("2026-05-09T22:30:00Z")
        )
        let newerSession = SleepSession(
            id: UUID(),
            startedAt: makeDate("2026-05-09T22:45:00Z")
        )
        let endedAt = makeDate("2026-05-10T06:40:00Z")
        context.insert(olderSession)
        context.insert(newerSession)
        try context.save()

        let endedSession = try #require(try SleepSessionSupport.endActiveSleep(in: context, at: endedAt))

        #expect(endedSession.id == newerSession.id)
        #expect(olderSession.endedAt == endedAt)
        #expect(newerSession.endedAt == endedAt)
        #expect(try SleepSessionSupport.activeSessions(in: context).isEmpty)
    }

    @MainActor
    @Test
    func logSleep_createsCompletedSessionForSelectedInterval() throws {
        let context = makeInMemoryContext()
        let startedAt = makeDate("2026-06-01T21:45:00Z")
        let expectedEnd = makeDate("2026-06-02T05:45:00Z")

        let session = try SleepSessionSupport.logSleep(
            durationMinutes: 8 * 60,
            startedAt: startedAt,
            context: context
        )

        #expect(session.startedAt == startedAt)
        #expect(session.endedAt == expectedEnd)
        #expect(session.targetDurationMinutes == 8 * 60)
        #expect(!session.isActive)
        #expect(try SleepSessionSupport.activeSession(in: context) == nil)
    }

    @MainActor
    @Test
    func logSleep_rejectsOverlappingProtectedSessions() throws {
        let context = makeInMemoryContext()
        let awayKey = UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue
        let previousAwayValue = SharedDefaults.app.object(forKey: awayKey)
        defer {
            if let previousAwayValue {
                SharedDefaults.app.set(previousAwayValue, forKey: awayKey)
            } else {
                SharedDefaults.app.removeObject(forKey: awayKey)
            }
        }
        SharedDefaults.app[.appSettingAwayEnabled] = true
        let existingSleepStart = makeDate("2026-06-01T21:00:00Z")
        let away = AwaySession(
            preset: .outside,
            startedAt: makeDate("2026-06-01T10:00:00Z"),
            plannedDurationSeconds: 30 * 60,
            completedAt: makeDate("2026-06-01T10:30:00Z")
        )
        let focus = FocusSession(
            taskID: UUID(),
            startedAt: makeDate("2026-06-01T11:00:00Z"),
            plannedDurationSeconds: 25 * 60,
            completedAt: makeDate("2026-06-01T11:25:00Z")
        )
        context.insert(away)
        context.insert(focus)
        try context.save()
        _ = try SleepSessionSupport.logSleep(
            durationMinutes: 8 * 60,
            startedAt: existingSleepStart,
            context: context
        )

        for overlappingStart in [
            makeDate("2026-06-01T10:15:00Z"),
            makeDate("2026-06-01T11:10:00Z"),
            makeDate("2026-06-02T00:00:00Z"),
        ] {
            do {
                _ = try SleepSessionSupport.logSleep(
                    durationMinutes: 10,
                    startedAt: overlappingStart,
                    context: context
                )
                Issue.record("Expected overlapping sleep log to fail.")
            } catch let error as SleepSessionSupportError {
                #expect(error == .overlappingProtectedSession)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @MainActor
    @Test
    func startSleep_stopsActiveFocusTimers() throws {
        let context = makeInMemoryContext()
        let task = makeTask(
            in: context,
            name: "Deep work",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        let startedAt = makeDate("2026-05-10T14:00:00Z")
        let taskFocus = FocusSession(
            taskID: task.id,
            startedAt: makeDate("2026-05-10T13:30:00Z"),
            plannedDurationSeconds: 25 * 60
        )
        let finishedTaskFocus = FocusSession(
            taskID: UUID(),
            startedAt: makeDate("2026-05-10T12:00:00Z"),
            plannedDurationSeconds: 25 * 60,
            completedAt: makeDate("2026-05-10T12:25:00Z")
        )
        let sprintFocus = SprintFocusSessionRecord(
            sprintID: UUID(),
            startedAt: makeDate("2026-05-10T13:45:00Z")
        )
        let finishedSprintFocus = SprintFocusSessionRecord(
            sprintID: UUID(),
            startedAt: makeDate("2026-05-10T11:30:00Z"),
            stoppedAt: makeDate("2026-05-10T11:55:00Z")
        )
        context.insert(taskFocus)
        context.insert(finishedTaskFocus)
        context.insert(sprintFocus)
        context.insert(finishedSprintFocus)
        let calendar = makeTestCalendar()
        _ = DayPlanFocusSessionPlannerSync.saveStartedFocusBlock(
            for: task,
            session: taskFocus,
            startedAt: taskFocus.startedAt ?? startedAt,
            durationSeconds: taskFocus.plannedDurationSeconds,
            calendar: calendar,
            context: context
        )
        let taskFocusDayKey = DayPlanStorage.dayKey(
            for: taskFocus.startedAt ?? startedAt,
            calendar: calendar
        )
        try context.save()

        #expect(DayPlanStorage.loadBlocks(forDayKey: taskFocusDayKey, context: context).count == 1)
        let warningMessage = try #require(try SleepSessionSupport.activeFocusTimerWarningMessage(in: context))
        #expect(warningMessage == "2 focus timers are running. Starting sleep mode will stop them.")

        _ = try SleepSessionSupport.startSleep(in: context, at: startedAt)

        #expect(taskFocus.abandonedAt == startedAt)
        #expect(DayPlanStorage.loadBlocks(forDayKey: taskFocusDayKey, context: context).isEmpty)
        #expect(finishedTaskFocus.completedAt == makeDate("2026-05-10T12:25:00Z"))
        #expect(finishedTaskFocus.abandonedAt == nil)
        #expect(sprintFocus.stoppedAt == startedAt)
        #expect(finishedSprintFocus.stoppedAt == makeDate("2026-05-10T11:55:00Z"))
        #expect(try SleepSessionSupport.activeFocusTimerWarningMessage(in: context) == nil)
    }

    @MainActor
    @Test
    func activeFocusTimerWarningMessage_includesTaskNameForSingleTaskFocus() throws {
        let context = makeInMemoryContext()
        let task = makeTask(
            in: context,
            name: "Deep work",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        context.insert(
            FocusSession(
                taskID: task.id,
                startedAt: makeDate("2026-05-10T13:30:00Z"),
                plannedDurationSeconds: 25 * 60
            )
        )
        try context.save()

        let warningMessage = try #require(try SleepSessionSupport.activeFocusTimerWarningMessage(in: context))

        #expect(warningMessage == "Focus timer for Deep work is running. Starting sleep mode will stop it.")
    }

    @MainActor
    @Test
    func startFocusSession_failsWhileSleepIsActive() throws {
        let context = makeInMemoryContext()
        let task = makeTask(
            in: context,
            name: "Deep work",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        task.focusModeEnabled = true
        try context.save()
        _ = try SleepSessionSupport.startSleep(
            in: context,
            at: makeDate("2026-05-10T14:00:00Z")
        )

        do {
            _ = try RoutinaQuickAddService.startFocusSession(
                taskName: "Deep work",
                durationMinutes: 25,
                context: context,
                referenceDate: makeDate("2026-05-10T14:05:00Z"),
                calendar: makeTestCalendar()
            )
            Issue.record("Expected starting focus to fail while sleep mode is active.")
        } catch let error as RoutinaQuickAddError {
            #expect(error == .activeSleepSession)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(try context.fetch(FetchDescriptor<FocusSession>()).isEmpty)
    }

    @MainActor
    @Test
    func backupPackage_roundTripsSleepSessions() throws {
        let sourceContext = makeInMemoryContext()
        let session = SleepSession(
            id: UUID(),
            startedAt: makeDate("2026-05-09T22:30:00Z"),
            endedAt: makeDate("2026-05-10T06:45:00Z"),
            targetDurationMinutes: 480,
            createdAt: makeDate("2026-05-09T22:30:00Z"),
            updatedAt: makeDate("2026-05-10T06:45:00Z")
        )
        sourceContext.insert(session)
        try sourceContext.save()

        let package = try SettingsRoutineDataPersistence.buildBackupPackage(
            from: sourceContext,
            exportedAt: makeDate("2026-05-10T07:00:00Z")
        )

        let restoreContext = makeInMemoryContext()
        let summary = try SettingsRoutineDataPersistence.replaceAllRoutineData(
            with: package.manifestData,
            in: restoreContext,
            importDate: makeDate("2026-05-10T07:05:00Z")
        )
        let restored = try #require(try restoreContext.fetch(FetchDescriptor<SleepSession>()).first)

        #expect(summary.sleepSessions == 1)
        #expect(restored.id == session.id)
        #expect(restored.startedAt == session.startedAt)
        #expect(restored.endedAt == session.endedAt)
        #expect(restored.targetDurationMinutes == 480)
    }
}
