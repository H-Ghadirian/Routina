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
    func eligibility_allowsEligibleRepeatingTasksWithOptIn() {
        let checklistItem = RoutineChecklistItem(title: "Breakfast", intervalDays: 1)
        let dueRoutine = RoutineTask(
            name: "Brush teeth",
            scheduleMode: .fixedInterval,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 21, minute: 0)),
            autoAssumeDailyDone: true
        )
        let gentleRoutine = RoutineTask(
            name: "Brush teeth",
            scheduleMode: .softInterval,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 21, minute: 0)),
            autoAssumeDailyDone: true
        )
        let gentleChecklistRoutine = RoutineTask(
            name: "Meals",
            checklistItems: [checklistItem],
            scheduleMode: .softIntervalChecklist,
            recurrenceRule: .interval(days: 1),
            autoAssumeDailyDone: true
        )
        let standard = RoutineTask(
            name: "Brush teeth",
            scheduleMode: .record,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 21, minute: 0)),
            autoAssumeDailyDone: true
        )
        let interval = RoutineTask(
            name: "Journal",
            scheduleMode: .record,
            recurrenceRule: .interval(days: 1),
            autoAssumeDailyDone: true
        )
        let noCadence = RoutineTask(
            name: "Random log",
            scheduleMode: .record,
            recurrenceRule: .interval(days: 1),
            autoAssumeDailyDone: true,
            trackingCadenceEnabled: false
        )
        let weekly = RoutineTask(
            name: "Review",
            scheduleMode: .record,
            recurrenceRule: .weekly(on: 2, at: nil),
            autoAssumeDailyDone: true
        )
        let checklist = RoutineTask(
            name: "Meals",
            checklistItems: [checklistItem],
            scheduleMode: .recordChecklist,
            recurrenceRule: .interval(days: 1),
            autoAssumeDailyDone: true
        )
        let exactTimeChecklist = RoutineTask(
            name: "Study blocks",
            checklistItems: [checklistItem],
            scheduleMode: .recordChecklist,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 9, minute: 0)),
            autoAssumeDailyDone: true
        )
        let optionalChecklist = RoutineTask(
            name: "Read",
            checklistItems: [checklistItem],
            scheduleMode: .record,
            recurrenceRule: .interval(days: 1),
            autoAssumeDailyDone: true
        )
        let runout = RoutineTask(
            name: "Groceries",
            checklistItems: [checklistItem],
            scheduleMode: .recordDerivedFromChecklist,
            recurrenceRule: .interval(days: 1),
            autoAssumeDailyDone: true
        )
        let withSteps = RoutineTask(
            name: "Morning tracking",
            steps: [RoutineStep(title: "Stretch")],
            scheduleMode: .record,
            recurrenceRule: .interval(days: 1),
            autoAssumeDailyDone: true
        )

        #expect(RoutineAssumedCompletion.isEligible(dueRoutine))
        #expect(RoutineAssumedCompletion.isEligible(gentleRoutine))
        #expect(RoutineAssumedCompletion.isEligible(gentleChecklistRoutine))
        #expect(RoutineAssumedCompletion.isEligible(standard))
        #expect(RoutineAssumedCompletion.isEligible(interval))
        #expect(RoutineAssumedCompletion.isEligible(checklist))
        #expect(RoutineAssumedCompletion.isEligible(exactTimeChecklist))
        #expect(!RoutineAssumedCompletion.isEligible(noCadence))
        #expect(RoutineAssumedCompletion.isEligible(weekly))
        #expect(!RoutineAssumedCompletion.isEligible(optionalChecklist))
        #expect(!RoutineAssumedCompletion.isEligible(runout))
        #expect(!RoutineAssumedCompletion.isEligible(withSteps))
    }

    @Test
    func weeklyScheduledTaskIsAssumedOnlyOnScheduledWeekdaysAfterItsTime() {
        let calendar = makeTestCalendar()
        let mondayMorning = makeDate("2026-02-23T09:30:00Z")
        let mondayAfternoon = makeDate("2026-02-23T10:30:00Z")
        let tuesday = makeDate("2026-02-24T12:00:00Z")
        let task = RoutineTask(
            name: "Team check-in",
            scheduleMode: .fixedInterval,
            recurrenceRule: .weekly(on: 2, at: RoutineTimeOfDay(hour: 10, minute: 0)),
            createdAt: makeDate("2026-02-16T00:00:00Z"),
            autoAssumeDailyDone: true
        )

        #expect(!RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: mondayMorning,
            referenceDate: mondayMorning,
            calendar: calendar
        ))
        #expect(RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: mondayAfternoon,
            referenceDate: mondayAfternoon,
            calendar: calendar
        ))
        #expect(!RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: tuesday,
            referenceDate: tuesday,
            calendar: calendar
        ))
    }

    @Test
    func oneOffScheduledTimeBlockIsAssumedOnlyOnItsDateAfterItStarts() {
        let calendar = makeTestCalendar()
        let scheduledDay = makeDate("2026-02-25T00:00:00Z")
        let beforeStart = makeDate("2026-02-25T11:59:00Z")
        let afterStart = makeDate("2026-02-25T12:00:00Z")
        let followingDay = makeDate("2026-02-26T12:00:00Z")
        let timeBlock = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 12, minute: 0),
            end: RoutineTimeOfDay(hour: 15, minute: 0)
        )
        let task = RoutineTask(
            name: "Visit museum",
            availabilityStartDate: scheduledDay,
            scheduleMode: .oneOff,
            recurrenceRule: .interval(days: 1, timeRange: timeBlock),
            recurrenceTimeRangeRole: .scheduledBlock,
            createdAt: makeDate("2026-02-20T00:00:00Z"),
            autoAssumeDailyDone: true
        )

        #expect(RoutineAssumedCompletion.isEligible(task))
        #expect(!RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: scheduledDay,
            referenceDate: beforeStart,
            calendar: calendar
        ))
        #expect(RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: scheduledDay,
            referenceDate: afterStart,
            calendar: calendar
        ))
        #expect(!RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: followingDay,
            referenceDate: followingDay,
            calendar: calendar
        ))
        #expect(RoutineAssumedCompletion.assumedDates(
            for: task,
            through: followingDay,
            calendar: calendar
        ) == [scheduledDay])
    }

    @Test
    func oneOffScheduledTimeBlockConfirmationUsesTheBlockEndAndDuration() throws {
        let calendar = makeTestCalendar()
        let scheduledDay = makeDate("2026-02-25T00:00:00Z")
        let task = RoutineTask(
            name: "Visit museum",
            availabilityStartDate: scheduledDay,
            scheduleMode: .oneOff,
            recurrenceRule: .interval(
                days: 1,
                timeRange: RoutineTimeRange(
                    start: RoutineTimeOfDay(hour: 12, minute: 0),
                    end: RoutineTimeOfDay(hour: 15, minute: 0)
                )
            ),
            recurrenceTimeRangeRole: .scheduledBlock,
            createdAt: makeDate("2026-02-20T00:00:00Z"),
            autoAssumeDailyDone: true
        )

        let timing = try #require(
            RoutineAssumedCompletion.scheduledBlockCompletionTiming(
                for: task,
                on: scheduledDay,
                calendar: calendar
            )
        )

        #expect(timing.completedAt == makeDate("2026-02-25T15:00:00Z"))
        #expect(timing.actualDurationMinutes == 180)
    }

    @Test
    func oneOffFlexibleAvailabilityAndChecklistTimeBlocksCannotAutoAssume() {
        let timeBlock = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 12, minute: 0),
            end: RoutineTimeOfDay(hour: 15, minute: 0)
        )
        let exactDate = makeDate("2026-02-25T00:00:00Z")
        let flexibleTask = RoutineTask(
            name: "Flexible errand",
            availabilityStartDate: exactDate,
            scheduleMode: .oneOff,
            recurrenceRule: .interval(days: 1, timeRange: timeBlock),
            recurrenceTimeRangeRole: .availability,
            autoAssumeDailyDone: true
        )
        let dateWindowTask = RoutineTask(
            name: "Trip",
            availabilityStartDate: exactDate,
            availabilityEndDate: makeDate("2026-02-27T00:00:00Z"),
            scheduleMode: .oneOff,
            recurrenceRule: .interval(days: 1, timeRange: timeBlock),
            recurrenceTimeRangeRole: .scheduledBlock,
            autoAssumeDailyDone: true
        )
        let allDayTask = RoutineTask(
            name: "All-day errand",
            isAllDay: true,
            availabilityStartDate: exactDate,
            scheduleMode: .oneOff,
            recurrenceRule: .interval(days: 1, timeRange: timeBlock),
            recurrenceTimeRangeRole: .scheduledBlock,
            autoAssumeDailyDone: true
        )
        let checklistTask = RoutineTask(
            name: "Pack",
            availabilityStartDate: exactDate,
            checklistItems: [RoutineChecklistItem(title: "Passport", intervalDays: 1)],
            scheduleMode: .oneOff,
            recurrenceRule: .interval(days: 1, timeRange: timeBlock),
            recurrenceTimeRangeRole: .scheduledBlock,
            autoAssumeDailyDone: true
        )

        #expect(!RoutineAssumedCompletion.isEligible(flexibleTask))
        #expect(!RoutineAssumedCompletion.isEligible(dateWindowTask))
        #expect(!RoutineAssumedCompletion.isEligible(allDayTask))
        #expect(!RoutineAssumedCompletion.isEligible(checklistTask))
    }

    @Test
    func today_waitsUntilDailyTime() {
        let calendar = makeTestCalendar()
        let today = makeDate("2026-02-25T00:00:00Z")
        let morning = makeDate("2026-02-25T08:00:00Z")
        let evening = makeDate("2026-02-25T22:00:00Z")
        let task = RoutineTask(
            name: "Brush teeth",
            scheduleMode: .record,
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
            scheduleMode: .record,
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
            scheduleMode: .record,
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
            scheduleMode: .record,
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
            scheduleMode: .record,
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
            scheduleMode: .recordChecklist,
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
            scheduleMode: .record,
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
            scheduleMode: .record,
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
            scheduleMode: .record,
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

    @Test
    func afterCompletionAssumptionsContinueUntilAnIndividualConfirmationResetsTheAnchor() {
        let calendar = makeTestCalendar()
        let day3 = makeDate("2026-02-03T12:00:00Z")
        let day4 = makeDate("2026-02-04T12:00:00Z")
        let day5 = makeDate("2026-02-05T12:00:00Z")
        let day6 = makeDate("2026-02-06T12:00:00Z")
        let day7 = makeDate("2026-02-07T12:00:00Z")
        let day8 = makeDate("2026-02-08T12:00:00Z")
        let task = RoutineTask(
            name: "Journal",
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 2),
            lastDone: day3,
            scheduleAnchor: day3,
            createdAt: makeDate("2026-02-01T12:00:00Z"),
            autoAssumeDailyDone: true
        )

        #expect(RoutineAssumedCompletion.isEligible(task))
        #expect(RoutineAssumedCompletion.requiresIndividualAssumedCompletionConfirmation(for: task))
        #expect(!RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: day4,
            referenceDate: day4,
            calendar: calendar
        ))
        #expect(RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: day5,
            referenceDate: day5,
            calendar: calendar
        ))
        #expect(RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: day6,
            referenceDate: day6,
            calendar: calendar
        ))
        #expect(RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: day7,
            referenceDate: day7,
            calendar: calendar
        ))

        _ = task.advance(completedAt: day4, calendar: calendar)

        #expect(!RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: day5,
            referenceDate: day5,
            calendar: calendar
        ))
        #expect(RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: day6,
            referenceDate: day6,
            calendar: calendar
        ))
        #expect(RoutineAssumedCompletion.assumedDates(
            for: task,
            through: day8,
            calendar: calendar
        ) == [
            calendar.startOfDay(for: day6),
            calendar.startOfDay(for: day7),
            calendar.startOfDay(for: day8),
        ])
    }
}
