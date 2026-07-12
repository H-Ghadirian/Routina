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
    func eligibility_allowsDailyStandardAndChecklistCompletionRoutinesWithOptIn() {
        let checklistItem = RoutineChecklistItem(title: "Breakfast", intervalDays: 1)
        let due = RoutineTask(
            name: "Brush teeth",
            scheduleMode: .fixedInterval,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 21, minute: 0)),
            autoAssumeDailyDone: true
        )
        let gentle = RoutineTask(
            name: "Journal",
            scheduleMode: .softInterval,
            recurrenceRule: .interval(days: 1),
            autoAssumeDailyDone: true
        )
        let weekly = RoutineTask(
            name: "Review",
            scheduleMode: .fixedInterval,
            recurrenceRule: .weekly(on: 2, at: nil),
            autoAssumeDailyDone: true
        )
        let checklist = RoutineTask(
            name: "Meals",
            checklistItems: [checklistItem],
            scheduleMode: .fixedIntervalChecklist,
            recurrenceRule: .interval(days: 1),
            autoAssumeDailyDone: true
        )
        let gentleChecklist = RoutineTask(
            name: "Study blocks",
            checklistItems: [checklistItem],
            scheduleMode: .softIntervalChecklist,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 9, minute: 0)),
            autoAssumeDailyDone: true
        )
        let optionalChecklist = RoutineTask(
            name: "Read",
            checklistItems: [checklistItem],
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 1),
            autoAssumeDailyDone: true
        )
        let runout = RoutineTask(
            name: "Groceries",
            checklistItems: [checklistItem],
            scheduleMode: .derivedFromChecklist,
            recurrenceRule: .interval(days: 1),
            autoAssumeDailyDone: true
        )
        let withSteps = RoutineTask(
            name: "Morning routine",
            steps: [RoutineStep(title: "Stretch")],
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 1),
            autoAssumeDailyDone: true
        )

        #expect(RoutineAssumedCompletion.isEligible(due))
        #expect(RoutineAssumedCompletion.isEligible(gentle))
        #expect(RoutineAssumedCompletion.isEligible(checklist))
        #expect(RoutineAssumedCompletion.isEligible(gentleChecklist))
        #expect(!RoutineAssumedCompletion.isEligible(weekly))
        #expect(!RoutineAssumedCompletion.isEligible(optionalChecklist))
        #expect(!RoutineAssumedCompletion.isEligible(runout))
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
    func overnightWindowEarlyMorningCurrentOccurrenceUsesPreviousDay() {
        let calendar = makeTestCalendar()
        let referenceDate = makeDate("2026-02-26T01:00:00Z")
        let timeRange = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 21, minute: 0),
            end: RoutineTimeOfDay(hour: 3, minute: 0)
        )
        let task = RoutineTask(
            name: "Brush teeth",
            scheduleMode: .fixedInterval,
            recurrenceRule: .daily(in: timeRange),
            createdAt: makeDate("2026-02-20T00:00:00Z"),
            autoAssumeDailyDone: true
        )
        let currentOccurrenceDay = RoutineAssumedCompletion.currentOccurrenceDay(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(currentOccurrenceDay == makeDate("2026-02-25T00:00:00Z"))
        #expect(RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: currentOccurrenceDay,
            referenceDate: referenceDate,
            calendar: calendar
        ))
    }

    @Test
    func overnightWindowAfterEndBeforeNextStartCurrentOccurrenceUsesPreviousDay() {
        let calendar = makeTestCalendar()
        let referenceDate = makeDate("2026-02-26T12:00:00Z")
        let timeRange = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 21, minute: 0),
            end: RoutineTimeOfDay(hour: 3, minute: 0)
        )
        let task = RoutineTask(
            name: "Brush teeth",
            scheduleMode: .fixedInterval,
            recurrenceRule: .daily(in: timeRange),
            createdAt: makeDate("2026-02-20T00:00:00Z"),
            autoAssumeDailyDone: true
        )
        let currentOccurrenceDay = RoutineAssumedCompletion.currentOccurrenceDay(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(currentOccurrenceDay == makeDate("2026-02-25T00:00:00Z"))
        #expect(RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: currentOccurrenceDay,
            referenceDate: referenceDate,
            calendar: calendar
        ))
    }

    @Test
    func overnightWindowEarlyMorningCompletionSuppressesAssumedDone() {
        let calendar = makeTestCalendar()
        let referenceDate = makeDate("2026-02-26T01:00:00Z")
        let timeRange = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 21, minute: 0),
            end: RoutineTimeOfDay(hour: 3, minute: 0)
        )
        let task = RoutineTask(
            name: "Brush teeth",
            scheduleMode: .fixedInterval,
            recurrenceRule: .daily(in: timeRange),
            createdAt: makeDate("2026-02-20T00:00:00Z"),
            autoAssumeDailyDone: true
        )
        let logs = [
            RoutineLog(
                timestamp: makeDate("2026-02-26T01:30:00Z"),
                taskID: task.id,
                kind: .completed
            )
        ]

        #expect(!RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: RoutineAssumedCompletion.currentOccurrenceDay(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ),
            referenceDate: referenceDate,
            logs: logs,
            calendar: calendar
        ))
    }

    @Test
    func missedLogSuppressesAssumedDone() {
        let calendar = makeTestCalendar()
        let today = makeDate("2026-02-25T00:00:00Z")
        let referenceDate = makeDate("2026-02-25T10:00:00Z")
        let task = RoutineTask(
            name: "Brush teeth",
            scheduleMode: .fixedInterval,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 8, minute: 0)),
            createdAt: makeDate("2026-02-20T00:00:00Z"),
            autoAssumeDailyDone: true
        )
        let logs = [
            RoutineLog(
                timestamp: makeDate("2026-02-25T08:00:00Z"),
                taskID: task.id,
                kind: .missed
            )
        ]

        #expect(!RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: today,
            referenceDate: referenceDate,
            logs: logs,
            calendar: calendar
        ))
    }

    @Test
    func checklistPartialProgressSuppressesAssumedDone() {
        let calendar = makeTestCalendar()
        let today = makeDate("2026-02-25T00:00:00Z")
        let referenceDate = makeDate("2026-02-25T10:00:00Z")
        let firstID = UUID()
        let secondID = UUID()
        let task = RoutineTask(
            name: "Meals",
            checklistItems: [
                RoutineChecklistItem(id: firstID, title: "Breakfast", intervalDays: 1, createdAt: today),
                RoutineChecklistItem(id: secondID, title: "Lunch", intervalDays: 1, createdAt: today)
            ],
            scheduleMode: .fixedIntervalChecklist,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 8, minute: 0)),
            createdAt: makeDate("2026-02-24T00:00:00Z"),
            autoAssumeDailyDone: true
        )

        #expect(RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: today,
            referenceDate: referenceDate,
            calendar: calendar
        ))

        task.completedChecklistItemIDs = [firstID]
        task.completedChecklistProgressStartedAt = referenceDate

        #expect(!RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: today,
            referenceDate: referenceDate,
            calendar: calendar
        ))
    }

    @Test
    func creationDayAfterAvailabilityStartCanBeAssumedDone() {
        let calendar = makeTestCalendar()
        let today = makeDate("2026-02-25T00:00:00Z")
        let referenceDate = makeDate("2026-02-25T10:00:00Z")
        let task = RoutineTask(
            name: "Brush teeth",
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 1),
            createdAt: makeDate("2026-02-25T09:30:00Z"),
            autoAssumeDailyDone: true
        )

        #expect(RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: today,
            referenceDate: referenceDate,
            calendar: calendar
        ))

        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        #expect(!RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: yesterday,
            referenceDate: referenceDate,
            calendar: calendar
        ))
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

    @Test
    func pastAssumedDates_skipCompletedTimeWindowDaysLoggedAtProbableTime() {
        let calendar = makeTestCalendar()
        let referenceDate = makeDate("2026-02-25T08:00:00Z")
        let timeRange = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 21, minute: 0),
            end: RoutineTimeOfDay(hour: 3, minute: 0)
        )
        let task = RoutineTask(
            name: "Brush teeth",
            scheduleMode: .fixedInterval,
            recurrenceRule: .daily(in: timeRange),
            createdAt: makeDate("2026-02-22T00:00:00Z"),
            autoAssumeDailyDone: true,
            autoAssumeDoneTimeOfDay: RoutineTimeOfDay(hour: 12, minute: 0)
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
