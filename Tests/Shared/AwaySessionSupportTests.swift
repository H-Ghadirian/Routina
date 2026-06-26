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

struct AwaySessionSupportTests {
    @MainActor
    @Test
    func startAway_createsActiveSessionAndTracksExtensionAndEarlyEnd() throws {
        let context = makeInMemoryContext()
        let startedAt = makeDate("2026-06-01T06:30:00Z")
        let extendedAt = makeDate("2026-06-01T06:40:00Z")
        let endedAt = makeDate("2026-06-01T06:48:00Z")

        let session = try AwaySessionSupport.startAway(
            preset: .wake,
            durationMinutes: 20,
            startedAt: startedAt,
            context: context
        )
        let extended = try #require(try AwaySessionSupport.extendActiveAway(
            byMinutes: 5,
            in: context,
            at: extendedAt
        ))
        let ended = try #require(try AwaySessionSupport.endActiveAwayEarly(
            in: context,
            at: endedAt
        ))

        #expect(session.id == extended.id)
        #expect(extended.extensionCount == 1)
        #expect(extended.plannedDurationSeconds == TimeInterval(25 * 60))
        #expect(ended.id == session.id)
        #expect(ended.state == .endedEarly)
        #expect(ended.endedEarlyAt == endedAt)
        #expect(try AwaySessionSupport.activeSession(in: context) == nil)
    }

    @MainActor
    @Test
    func completeExpiredSessions_finishesAtPlannedEnd() throws {
        let context = makeInMemoryContext()
        let startedAt = makeDate("2026-06-01T07:00:00Z")
        let referenceDate = makeDate("2026-06-01T07:16:00Z")

        let session = try AwaySessionSupport.startAway(
            preset: .reset,
            durationMinutes: 15,
            startedAt: startedAt,
            context: context
        )

        let completedCount = try AwaySessionSupport.completeExpiredSessions(
            in: context,
            referenceDate: referenceDate
        )

        #expect(completedCount == 1)
        #expect(session.state == .completed)
        #expect(session.completedAt == makeDate("2026-06-01T07:15:00Z"))
        #expect(try AwaySessionSupport.activeSessions(in: context).isEmpty)
    }

    @MainActor
    @Test
    func startAway_countUpRunsUntilUserEndsIt() throws {
        let context = makeInMemoryContext()
        let startedAt = makeDate("2026-06-01T07:00:00Z")
        let referenceDate = makeDate("2026-06-01T07:42:00Z")
        let endedAt = makeDate("2026-06-01T07:50:00Z")

        let session = try AwaySessionSupport.startAway(
            preset: .outside,
            countsUp: true,
            startedAt: startedAt,
            context: context
        )
        let completedCount = try AwaySessionSupport.completeExpiredSessions(
            in: context,
            referenceDate: referenceDate
        )
        let elapsedBeforeEnd = session.durationSeconds(referenceDate: referenceDate)
        let ended = try #require(try AwaySessionSupport.completeActiveAway(
            in: context,
            at: endedAt
        ))

        #expect(session.isCountUp)
        #expect(session.plannedDurationSeconds == 0)
        #expect(session.plannedEndAt == nil)
        #expect(session.remainingSeconds(referenceDate: referenceDate) == 0)
        #expect(elapsedBeforeEnd == TimeInterval(42 * 60))
        #expect(session.isExpired(at: referenceDate) == false)
        #expect(completedCount == 0)
        #expect(ended.id == session.id)
        #expect(ended.state == .completed)
        #expect(ended.completedAt == endedAt)
        #expect(ended.durationSeconds(referenceDate: endedAt) == TimeInterval(50 * 60))
    }

    @MainActor
    @Test
    func updateAway_linksTaskAndEditsActiveSession() throws {
        let context = makeInMemoryContext()
        let task = makeTask(
            in: context,
            name: "Morning walk",
            interval: 1,
            lastDone: nil,
            emoji: "🚶"
        )
        let startedAt = makeDate("2026-06-01T07:00:00Z")
        let editedStart = makeDate("2026-06-01T07:05:00Z")
        let editedAt = makeDate("2026-06-01T07:06:00Z")
        let session = try AwaySessionSupport.startAway(
            preset: .outside,
            durationMinutes: 30,
            startedAt: startedAt,
            context: context
        )

        let updated = try AwaySessionSupport.update(
            session,
            preset: .custom,
            title: "Walk outside",
            linkedTaskID: task.id,
            startedAt: editedStart,
            plannedDurationSeconds: 45 * 60,
            finishedAt: nil,
            in: context,
            at: editedAt
        )

        #expect(updated.id == session.id)
        #expect(updated.displayTitle == "Walk outside")
        #expect(updated.linkedTaskID == task.id)
        #expect(updated.startedAt == editedStart)
        #expect(updated.plannedDurationSeconds == 45 * 60)
        #expect(updated.state == .active)
        #expect(updated.updatedAt == editedAt)
    }

    @MainActor
    @Test
    func logAway_createsCompletedSessionForSelectedInterval() throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let task = makeTask(
            in: context,
            name: "Doctor appointment",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        let startedAt = makeDate("2026-06-01T08:15:00Z")
        let expectedEnd = makeDate("2026-06-01T08:50:00Z")

        let session = try AwaySessionSupport.logAway(
            preset: .custom,
            durationMinutes: 35,
            title: "Away appointment",
            linkedTaskID: task.id,
            startedAt: startedAt,
            context: context
        )
        let awayBlocksByDayKey = DayPlanAwayBlocks.blocksByDayKey(
            on: [startedAt],
            from: [session],
            tasks: [task],
            referenceDate: expectedEnd,
            calendar: calendar
        )
        let dayKey = DayPlanStorage.dayKey(for: startedAt, calendar: calendar)
        let awayBlock = try #require(awayBlocksByDayKey[dayKey]?.first)

        #expect(session.state == .completed)
        #expect(session.startedAt == startedAt)
        #expect(session.completedAt == expectedEnd)
        #expect(session.linkedTaskID == task.id)
        #expect(try AwaySessionSupport.activeSession(in: context) == nil)
        #expect(awayBlock.block.startMinute == 8 * 60 + 15)
        #expect(awayBlock.block.durationMinutes == 35)
        #expect(awayBlock.block.titleSnapshot == "Away appointment · Doctor appointment")
    }

    @MainActor
    @Test
    func logAway_rejectsOverlappingProtectedSessions() throws {
        let context = makeInMemoryContext()
        let existingAwayStart = makeDate("2026-06-01T09:00:00Z")
        let sleep = SleepSession(
            startedAt: makeDate("2026-06-01T10:00:00Z"),
            endedAt: makeDate("2026-06-01T10:30:00Z")
        )
        let focus = FocusSession(
            taskID: UUID(),
            startedAt: makeDate("2026-06-01T11:00:00Z"),
            plannedDurationSeconds: 25 * 60,
            completedAt: makeDate("2026-06-01T11:25:00Z")
        )
        context.insert(sleep)
        context.insert(focus)
        try context.save()
        _ = try AwaySessionSupport.logAway(
            preset: .reset,
            durationMinutes: 30,
            startedAt: existingAwayStart,
            context: context
        )

        for overlappingStart in [
            makeDate("2026-06-01T09:15:00Z"),
            makeDate("2026-06-01T10:15:00Z"),
            makeDate("2026-06-01T11:10:00Z"),
        ] {
            do {
                _ = try AwaySessionSupport.logAway(
                    preset: .custom,
                    durationMinutes: 10,
                    startedAt: overlappingStart,
                    context: context
                )
                Issue.record("Expected overlapping away log to fail.")
            } catch let error as AwaySessionSupportError {
                #expect(error == .overlappingProtectedSession)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @MainActor
    @Test
    func endActiveAwayEarly_completesCountUpAway() throws {
        let context = makeInMemoryContext()
        let startedAt = makeDate("2026-06-01T09:00:00Z")
        let endedAt = makeDate("2026-06-01T09:25:00Z")

        let session = try AwaySessionSupport.startAway(
            preset: .reset,
            countsUp: true,
            startedAt: startedAt,
            context: context
        )
        let ended = try #require(try AwaySessionSupport.endActiveAwayEarly(
            in: context,
            at: endedAt
        ))

        #expect(ended.id == session.id)
        #expect(ended.state == .completed)
        #expect(ended.completedAt == endedAt)
        #expect(ended.endedEarlyAt == nil)
    }

    @MainActor
    @Test
    func startFocusSession_failsWhileAwayIsActive() throws {
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
        let task = makeTask(
            in: context,
            name: "Deep work",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        task.focusModeEnabled = true
        try context.save()
        _ = try AwaySessionSupport.startAway(
            preset: .outside,
            durationMinutes: 30,
            startedAt: makeDate("2026-06-01T08:00:00Z"),
            context: context
        )

        do {
            _ = try RoutinaQuickAddService.startFocusSession(
                taskName: "Deep work",
                durationMinutes: 25,
                context: context,
                referenceDate: makeDate("2026-06-01T08:05:00Z"),
                calendar: makeTestCalendar()
            )
            Issue.record("Expected starting focus to fail while away mode is active.")
        } catch let error as RoutinaQuickAddError {
            #expect(error == .activeAwaySession)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(try context.fetch(FetchDescriptor<FocusSession>()).isEmpty)
    }

    @MainActor
    @Test
    func awayBlocksSplitOvernightSessionsByVisibleDay() throws {
        let calendar = makeTestCalendar()
        let previousDate = makeDate("2026-06-01T12:00:00Z")
        let nextDate = makeDate("2026-06-02T12:00:00Z")
        let startedAt = makeDate("2026-06-01T23:30:00Z")
        let completedAt = makeDate("2026-06-02T00:20:00Z")
        let session = AwaySession(
            preset: .windDown,
            startedAt: startedAt,
            plannedDurationSeconds: 50 * 60,
            completedAt: completedAt
        )

        let awayBlocksByDayKey = DayPlanAwayBlocks.blocksByDayKey(
            on: [previousDate, nextDate],
            from: [session],
            referenceDate: completedAt,
            calendar: calendar
        )

        let previousDayKey = DayPlanStorage.dayKey(for: previousDate, calendar: calendar)
        let nextDayKey = DayPlanStorage.dayKey(for: nextDate, calendar: calendar)
        let previousBlock = try #require(awayBlocksByDayKey[previousDayKey]?.first)
        let nextBlock = try #require(awayBlocksByDayKey[nextDayKey]?.first)
        #expect(previousBlock.sessionID == session.id)
        #expect(previousBlock.block.titleSnapshot == "Wind Down")
        #expect(previousBlock.block.startMinute == 23 * 60 + 30)
        #expect(previousBlock.block.durationMinutes == 30)
        #expect(nextBlock.block.startMinute == 0)
        #expect(nextBlock.block.durationMinutes == 20)
    }

    @MainActor
    @Test
    func awayBlockUsesActualEarlyEndDurationBelowPlannerMinimum() throws {
        let calendar = makeTestCalendar()
        let day = makeDate("2026-06-01T12:00:00Z")
        let startedAt = makeDate("2026-06-01T10:59:10Z")
        let endedAt = makeDate("2026-06-01T10:59:45Z")
        let session = AwaySession(
            preset: .reset,
            startedAt: startedAt,
            plannedDurationSeconds: 15 * 60,
            endedEarlyAt: endedAt
        )

        let awayBlocksByDayKey = DayPlanAwayBlocks.blocksByDayKey(
            on: [day],
            from: [session],
            referenceDate: endedAt,
            calendar: calendar
        )

        let dayKey = DayPlanStorage.dayKey(for: day, calendar: calendar)
        let block = try #require(awayBlocksByDayKey[dayKey]?.first)
        #expect(block.block.startMinute == 10 * 60 + 59)
        #expect(block.block.durationMinutes == 1)
        #expect(block.interval.durationMinutes == 1)
    }

    @MainActor
    @Test
    func awayBlockUsesReferenceDateForActiveCountUpSession() throws {
        let calendar = makeTestCalendar()
        let day = makeDate("2026-06-01T12:00:00Z")
        let startedAt = makeDate("2026-06-01T10:10:00Z")
        let referenceDate = makeDate("2026-06-01T10:33:00Z")
        let session = AwaySession(
            preset: .outside,
            startedAt: startedAt,
            plannedDurationSeconds: 0
        )

        let awayBlocksByDayKey = DayPlanAwayBlocks.blocksByDayKey(
            on: [day],
            from: [session],
            referenceDate: referenceDate,
            calendar: calendar
        )

        let dayKey = DayPlanStorage.dayKey(for: day, calendar: calendar)
        let block = try #require(awayBlocksByDayKey[dayKey]?.first)
        #expect(block.block.startMinute == 10 * 60 + 10)
        #expect(block.block.durationMinutes == 23)
        #expect(block.interval.durationMinutes == 23)
    }

    @MainActor
    @Test
    func awayBlockUsesLinkedTaskTitleAndEmoji() throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let day = makeDate("2026-06-01T12:00:00Z")
        let task = makeTask(
            in: context,
            name: "Gym",
            interval: 1,
            lastDone: nil,
            emoji: "🏋️"
        )
        let session = AwaySession(
            preset: .outside,
            linkedTaskID: task.id,
            startedAt: makeDate("2026-06-01T10:10:00Z"),
            plannedDurationSeconds: 30 * 60,
            completedAt: makeDate("2026-06-01T10:40:00Z")
        )

        let awayBlocksByDayKey = DayPlanAwayBlocks.blocksByDayKey(
            on: [day],
            from: [session],
            tasks: [task],
            referenceDate: makeDate("2026-06-01T10:40:00Z"),
            calendar: calendar
        )

        let dayKey = DayPlanStorage.dayKey(for: day, calendar: calendar)
        let block = try #require(awayBlocksByDayKey[dayKey]?.first)
        #expect(block.block.titleSnapshot == "Outside · Gym")
        #expect(block.block.emojiSnapshot == "🏋️")
        #expect(block.interval.title == "Outside · Gym")
    }

    @Test
    func statsMetricsCountAwaySessionsSeparatelyFromFocus() {
        let calendar = makeTestCalendar()
        let referenceDate = makeDate("2026-06-07T12:00:00Z")
        let task = RoutineTask(
            name: "Deep work",
            tags: ["Focus"],
            createdAt: makeDate("2026-06-01T08:00:00Z")
        )
        let focusSession = FocusSession(
            taskID: task.id,
            startedAt: makeDate("2026-06-05T09:00:00Z"),
            completedAt: makeDate("2026-06-05T10:00:00Z")
        )
        let completedAway = AwaySession(
            preset: .wake,
            startedAt: makeDate("2026-06-05T06:30:00Z"),
            plannedDurationSeconds: 20 * 60,
            completedAt: makeDate("2026-06-05T06:50:00Z")
        )
        let endedAway = AwaySession(
            preset: .outside,
            startedAt: makeDate("2026-06-06T15:00:00Z"),
            plannedDurationSeconds: 30 * 60,
            endedEarlyAt: makeDate("2026-06-06T15:12:00Z")
        )

        let state = StatsFeatureDerivedStateBuilder.build(
            tasks: [task],
            logs: [],
            focusSessions: [focusSession],
            awaySessions: [completedAway, endedAway],
            selectedRange: .week,
            taskTypeFilter: .all,
            selectedImportanceUrgencyFilter: nil,
            advancedQuery: "",
            selectedTags: [],
            includeTagMatchMode: .all,
            excludedTags: [],
            excludeTagMatchMode: .any,
            tagColors: [:],
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(state.metrics.totalFocusSeconds == TimeInterval(60 * 60))
        #expect(state.metrics.awaySessionCount == 2)
        #expect(state.metrics.completedAwaySessionCount == 1)
        #expect(state.metrics.endedEarlyAwaySessionCount == 1)
        #expect(state.metrics.totalAwaySeconds == TimeInterval(32 * 60))
        #expect(state.metrics.awayActiveDayCount == 2)
    }

    @MainActor
    @Test
    func backupPackage_roundTripsAwaySessions() throws {
        let sourceContext = makeInMemoryContext()
        let session = AwaySession(
            id: UUID(),
            preset: .outside,
            title: "Touch grass",
            startedAt: makeDate("2026-06-01T17:00:00Z"),
            plannedDurationSeconds: 35 * 60,
            completedAt: makeDate("2026-06-01T17:35:00Z"),
            extensionCount: 1,
            createdAt: makeDate("2026-06-01T17:00:00Z"),
            updatedAt: makeDate("2026-06-01T17:35:00Z")
        )
        sourceContext.insert(session)
        try sourceContext.save()

        let package = try SettingsRoutineDataPersistence.buildBackupPackage(
            from: sourceContext,
            exportedAt: makeDate("2026-06-01T18:00:00Z")
        )

        let restoreContext = makeInMemoryContext()
        let summary = try SettingsRoutineDataPersistence.replaceAllRoutineData(
            with: package.manifestData,
            in: restoreContext,
            importDate: makeDate("2026-06-01T18:05:00Z")
        )
        let restored = try #require(try restoreContext.fetch(FetchDescriptor<AwaySession>()).first)

        #expect(summary.awaySessions == 1)
        #expect(restored.id == session.id)
        #expect(restored.preset == .outside)
        #expect(restored.title == "Touch grass")
        #expect(restored.startedAt == session.startedAt)
        #expect(restored.completedAt == session.completedAt)
        #expect(restored.plannedDurationSeconds == TimeInterval(35 * 60))
        #expect(restored.extensionCount == 1)
    }

    @MainActor
    @Test
    func backupPackage_roundTripsCountUpAwaySessions() throws {
        let sourceContext = makeInMemoryContext()
        let session = AwaySession(
            id: UUID(),
            preset: .outside,
            title: "Walk",
            startedAt: makeDate("2026-06-01T17:00:00Z"),
            plannedDurationSeconds: 0,
            completedAt: makeDate("2026-06-01T17:35:00Z"),
            createdAt: makeDate("2026-06-01T17:00:00Z"),
            updatedAt: makeDate("2026-06-01T17:35:00Z")
        )
        sourceContext.insert(session)
        try sourceContext.save()

        let package = try SettingsRoutineDataPersistence.buildBackupPackage(
            from: sourceContext,
            exportedAt: makeDate("2026-06-01T18:00:00Z")
        )

        let restoreContext = makeInMemoryContext()
        _ = try SettingsRoutineDataPersistence.replaceAllRoutineData(
            with: package.manifestData,
            in: restoreContext,
            importDate: makeDate("2026-06-01T18:05:00Z")
        )
        let restored = try #require(try restoreContext.fetch(FetchDescriptor<AwaySession>()).first)

        #expect(restored.id == session.id)
        #expect(restored.isCountUp)
        #expect(restored.plannedDurationSeconds == 0)
        #expect(restored.durationSeconds() == TimeInterval(35 * 60))
    }
}
