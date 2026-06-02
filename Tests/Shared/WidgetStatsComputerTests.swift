import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct WidgetStatsComputerTests {
    @Test
    func todayFocusIncludesCompletedBoardAndActiveFocus() {
        let calendar = makeTestCalendar()
        let referenceDate = makeDate("2026-03-14T12:00:00Z")
        let taskID = UUID()

        let completedTaskFocus = FocusSession(
            taskID: taskID,
            startedAt: makeDate("2026-03-14T08:00:00Z"),
            plannedDurationSeconds: 30 * 60,
            completedAt: makeDate("2026-03-14T08:30:00Z")
        )
        let yesterdayFocus = FocusSession(
            taskID: taskID,
            startedAt: makeDate("2026-03-13T08:00:00Z"),
            plannedDurationSeconds: 20 * 60,
            completedAt: makeDate("2026-03-13T08:20:00Z")
        )
        let abandonedFocus = FocusSession(
            taskID: taskID,
            startedAt: makeDate("2026-03-14T09:00:00Z"),
            plannedDurationSeconds: 20 * 60,
            abandonedAt: makeDate("2026-03-14T09:05:00Z")
        )
        let activeFocus = FocusSession(
            taskID: FocusSession.unassignedTaskID,
            startedAt: makeDate("2026-03-14T11:50:00Z"),
            plannedDurationSeconds: 0
        )
        let completedBoardFocus = SprintFocusSessionRecord(
            sprintID: UUID(),
            startedAt: makeDate("2026-03-14T10:00:00Z"),
            stoppedAt: makeDate("2026-03-14T10:20:00Z")
        )

        let stats = WidgetStatsComputer.compute(
            tasks: [],
            logs: [],
            focusSessions: [completedTaskFocus, yesterdayFocus, abandonedFocus, activeFocus],
            sprintFocusSessions: [completedBoardFocus],
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(stats.focusSecondsToday == TimeInterval(60 * 60))
        #expect(stats.focusSessionsToday == 3)
        #expect(stats.activeFocusIncrementStartedAt == referenceDate)
        #expect(stats.hasActiveFocusToday)
        #expect(stats.focusSecondsToday(at: referenceDate.addingTimeInterval(5 * 60)) == TimeInterval(65 * 60))
    }

    @Test
    func todayFocusCountsOnlyReferenceDaySpanForOvernightActiveFocus() {
        let calendar = makeTestCalendar()
        let referenceDate = makeDate("2026-03-14T00:10:00Z")
        let overnightFocus = FocusSession(
            taskID: FocusSession.unassignedTaskID,
            startedAt: makeDate("2026-03-13T23:50:00Z"),
            plannedDurationSeconds: 0
        )

        let stats = WidgetStatsComputer.compute(
            tasks: [],
            logs: [],
            focusSessions: [overnightFocus],
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(stats.focusSecondsToday == TimeInterval(10 * 60))
        #expect(stats.focusSessionsToday == 1)
        #expect(stats.activeFocusIncrementStartedAt == referenceDate)
        #expect(stats.focusSecondsToday(at: referenceDate.addingTimeInterval(5 * 60)) == TimeInterval(15 * 60))
    }

    @Test
    func todayFocusFreezesPausedActiveFocus() {
        let calendar = makeTestCalendar()
        let referenceDate = makeDate("2026-03-14T12:00:00Z")
        let pausedFocus = FocusSession(
            taskID: FocusSession.unassignedTaskID,
            startedAt: makeDate("2026-03-14T11:45:00Z"),
            plannedDurationSeconds: 0,
            pausedAt: makeDate("2026-03-14T11:55:00Z")
        )

        let stats = WidgetStatsComputer.compute(
            tasks: [],
            logs: [],
            focusSessions: [pausedFocus],
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(stats.focusSecondsToday == TimeInterval(10 * 60))
        #expect(stats.focusSessionsToday == 1)
        #expect(stats.activeFocusIncrementStartedAt == nil)
        #expect(!stats.hasActiveFocusToday)
        #expect(stats.focusSecondsToday(at: referenceDate.addingTimeInterval(10 * 60)) == TimeInterval(10 * 60))
    }

    @Test
    func widgetStatsDecodesPayloadBeforeFocusFields() throws {
        let payload = LegacyWidgetStatsPayload(
            tasksDueToday: 2,
            completedToday: 1,
            completedThisWeek: 6,
            totalCompleted: 42,
            currentStreak: 3,
            lastUpdated: makeDate("2026-03-14T12:00:00Z")
        )

        let data = try JSONEncoder().encode(payload)
        let stats = try JSONDecoder().decode(WidgetStats.self, from: data)

        #expect(stats.tasksDueToday == 2)
        #expect(stats.focusSecondsToday == 0)
        #expect(stats.focusSessionsToday == 0)
        #expect(stats.activeFocusIncrementStartedAt == nil)
    }
}

private struct LegacyWidgetStatsPayload: Encodable {
    let tasksDueToday: Int
    let completedToday: Int
    let completedThisWeek: Int
    let totalCompleted: Int
    let currentStreak: Int
    let lastUpdated: Date
}
