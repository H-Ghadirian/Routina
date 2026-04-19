import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct RoutineAssumedCompletionTests {
    @Test
    func eligibility_requiresSimpleDailyRoutineWithOptIn() {
        let eligible = RoutineTask(
            name: "Brush teeth",
            scheduleMode: .fixedInterval,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 21, minute: 0)),
            autoAssumeDailyDone: true
        )
        let weekly = RoutineTask(
            name: "Review",
            scheduleMode: .fixedInterval,
            recurrenceRule: .weekly(on: 2, at: nil),
            autoAssumeDailyDone: true
        )
        let withSteps = RoutineTask(
            name: "Morning routine",
            steps: [RoutineStep(title: "Stretch")],
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 1),
            autoAssumeDailyDone: true
        )

        #expect(RoutineAssumedCompletion.isEligible(eligible))
        #expect(!RoutineAssumedCompletion.isEligible(weekly))
        #expect(!RoutineAssumedCompletion.isEligible(withSteps))
    }

    @Test
    func today_waitsUntilDailyTime() {
        let calendar = makeTestCalendar()
        let today = makeDate("2026-02-25T00:00:00Z")
        let morning = makeDate("2026-02-25T08:00:00Z")
        let evening = makeDate("2026-02-25T22:00:00Z")
        let task = RoutineTask(
            name: "Brush teeth",
            scheduleMode: .fixedInterval,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 21, minute: 0)),
            createdAt: makeDate("2026-02-20T00:00:00Z"),
            autoAssumeDailyDone: true
        )

        #expect(
            !RoutineAssumedCompletion.isAssumedDone(
                for: task,
                on: today,
                referenceDate: morning,
                calendar: calendar
            )
        )
        #expect(
            RoutineAssumedCompletion.isAssumedDone(
                for: task,
                on: today,
                referenceDate: evening,
                calendar: calendar
            )
        )
    }

    @Test
    func pastAssumedDates_skipCompletedAndCanceledDays() {
        let calendar = makeTestCalendar()
        let referenceDate = makeDate("2026-02-25T08:00:00Z")
        let task = RoutineTask(
            name: "Brush teeth",
            scheduleMode: .fixedInterval,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 21, minute: 0)),
            createdAt: makeDate("2026-02-22T00:00:00Z"),
            autoAssumeDailyDone: true
        )
        let logs = [
            RoutineLog(timestamp: makeDate("2026-02-23T12:00:00Z"), taskID: task.id, kind: .completed),
            RoutineLog(timestamp: makeDate("2026-02-24T12:00:00Z"), taskID: task.id, kind: .canceled),
        ]

        let assumedDates = RoutineAssumedCompletion.pastAssumedDates(
            for: task,
            referenceDate: referenceDate,
            logs: logs,
            calendar: calendar
        )

        #expect(assumedDates == [makeDate("2026-02-22T00:00:00Z")])
    }
}
