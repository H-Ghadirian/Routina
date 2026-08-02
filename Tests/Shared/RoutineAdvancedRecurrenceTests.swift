import ComposableArchitecture
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

struct RoutineAdvancedRecurrenceTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        calendar.firstWeekday = 2
        return calendar
    }

    @Test
    func everyOtherTuesdayUsesSelectedStartWeek() {
        let rule = RoutineAdvancedRecurrenceRule(
            frequency: .weekly,
            interval: 2,
            startDate: makeDate("2026-07-21T09:00:00Z"),
            weekdays: [3],
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )

        let occurrences = RoutineAdvancedRecurrenceGenerator.occurrences(
            for: rule,
            after: nil,
            limit: 3,
            calendar: calendar
        )

        #expect(occurrences == [
            makeDate("2026-07-21T09:00:00Z"),
            makeDate("2026-08-04T09:00:00Z"),
            makeDate("2026-08-18T09:00:00Z")
        ])
    }

    @Test
    func everyThreeWeeksOnSaturdayUsesCalendarSelector() {
        let rule = RoutineAdvancedRecurrenceRule(
            frequency: .weekly,
            interval: 3,
            startDate: makeDate("2026-07-21T09:00:00Z"),
            weekdays: [7],
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )

        let occurrences = RoutineAdvancedRecurrenceGenerator.occurrences(
            for: rule,
            after: nil,
            limit: 3,
            calendar: calendar
        )

        #expect(occurrences == [
            makeDate("2026-07-25T09:00:00Z"),
            makeDate("2026-08-15T09:00:00Z"),
            makeDate("2026-09-05T09:00:00Z")
        ])
    }

    @Test
    func everyTwoMonthsOnFirstFridayIsUnambiguous() {
        let rule = RoutineAdvancedRecurrenceRule(
            frequency: .monthly,
            interval: 2,
            startDate: makeDate("2026-07-21T09:00:00Z"),
            monthlyPattern: .ordinalWeekday,
            weekdayOrdinal: .first,
            ordinalWeekday: 6,
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )

        let occurrences = RoutineAdvancedRecurrenceGenerator.occurrences(
            for: rule,
            after: nil,
            limit: 3,
            calendar: calendar
        )

        #expect(occurrences == [
            makeDate("2026-09-04T09:00:00Z"),
            makeDate("2026-11-06T09:00:00Z"),
            makeDate("2027-01-01T09:00:00Z")
        ])
    }

    @Test
    func multipleMonthlyDatesStayDistinctAndAdaptiveFallbacksDoNotDuplicate() {
        let rule = RoutineAdvancedRecurrenceRule(
            frequency: .monthly,
            startDate: makeDate("2026-01-29T09:00:00Z"),
            monthDays: [29, 30, 31],
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )

        let occurrences = RoutineAdvancedRecurrenceGenerator.occurrences(
            for: rule,
            after: nil,
            limit: 5,
            calendar: calendar
        )

        #expect(occurrences == [
            makeDate("2026-01-29T09:00:00Z"),
            makeDate("2026-01-30T09:00:00Z"),
            makeDate("2026-01-31T09:00:00Z"),
            makeDate("2026-02-28T09:00:00Z"),
            makeDate("2026-03-29T09:00:00Z")
        ])
    }

    @Test
    func everySixHoursInDailyWindowResetsEachDay() {
        let rule = RoutineAdvancedRecurrenceRule(
            frequency: .hourly,
            interval: 6,
            startDate: makeDate("2026-07-21T07:00:00Z"),
            hourlyMode: .dailyWindow,
            dailyWindowStart: RoutineTimeOfDay(hour: 7, minute: 0),
            dailyWindowEnd: RoutineTimeOfDay(hour: 22, minute: 0),
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )

        let occurrences = RoutineAdvancedRecurrenceGenerator.occurrences(
            for: rule,
            after: nil,
            limit: 4,
            calendar: calendar
        )

        #expect(occurrences == [
            makeDate("2026-07-21T07:00:00Z"),
            makeDate("2026-07-21T13:00:00Z"),
            makeDate("2026-07-21T19:00:00Z"),
            makeDate("2026-07-22T07:00:00Z")
        ])
    }

    @Test
    func dailyWindowKeepsLegacyStorageValueAndUsesClearDisplayTitle() throws {
        let mode = RoutineAdvancedRecurrenceRule.HourlyMode.dailyWindow

        #expect(mode.rawValue == "During each day")
        #expect(mode.displayTitle == "Daily window")

        let encoded = try JSONEncoder().encode(mode)
        let decoded = try JSONDecoder().decode(
            RoutineAdvancedRecurrenceRule.HourlyMode.self,
            from: encoded
        )
        #expect(decoded == .dailyWindow)
    }

    @Test
    func advancedRuleRoundTripsThroughRoutineTaskStorage() {
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .weekly,
            interval: 2,
            startDate: makeDate("2026-07-21T09:00:00Z"),
            weekdays: [3, 5],
            endMode: .afterCount,
            occurrenceCount: 12,
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )
        let recurrenceRule = RoutineRecurrenceRule.advanced(advanced)
        let task = RoutineTask(
            scheduleMode: .fixedInterval,
            recurrenceRule: recurrenceRule,
            scheduleAnchor: advanced.startDate
        )

        #expect(task.recurrenceRule == recurrenceRule)
        #expect(task.recurrenceRule.advanced == advanced)
        #expect(!task.recurrenceRuleStorage.isEmpty)
    }

    @Test
    func advancedRuleRoundTripsAvailabilityWindowAndRoleThroughRoutineTaskStorage() {
        let window = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 18, minute: 0),
            end: RoutineTimeOfDay(hour: 21, minute: 0)
        )
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .monthly,
            interval: 2,
            startDate: makeDate("2026-07-21T18:00:00Z"),
            monthDays: [1, 15, 31],
            timesOfDay: [window.start],
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )
        let recurrenceRule = RoutineRecurrenceRule.advanced(
            advanced,
            timeRange: window
        )
        let task = RoutineTask(
            scheduleMode: .fixedInterval,
            recurrenceRule: recurrenceRule,
            recurrenceTimeRangeRole: .scheduledBlock,
            scheduleAnchor: advanced.startDate
        )

        #expect(task.recurrenceRule == recurrenceRule)
        #expect(task.recurrenceRule.advanced == advanced)
        #expect(task.recurrenceRule.timeRange == window)
        #expect(task.recurrenceTimeRangeRole == .scheduledBlock)
        #expect(!task.recurrenceRuleStorage.isEmpty)
    }

    @Test
    func hourlyRuleAllowsTwoScheduledCompletionsOnSameDay() {
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .hourly,
            interval: 6,
            startDate: makeDate("2026-07-21T07:00:00Z"),
            hourlyMode: .dailyWindow,
            dailyWindowStart: RoutineTimeOfDay(hour: 7, minute: 0),
            dailyWindowEnd: RoutineTimeOfDay(hour: 22, minute: 0),
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )
        let task = RoutineTask(
            scheduleMode: .fixedInterval,
            recurrenceRule: .advanced(advanced),
            scheduleAnchor: advanced.startDate
        )

        let first = task.advance(
            completedAt: makeDate("2026-07-21T07:00:00Z"),
            calendar: calendar
        )
        let second = task.advance(
            completedAt: makeDate("2026-07-21T13:00:00Z"),
            calendar: calendar
        )

        #expect(first == .completedRoutine)
        #expect(second == .completedRoutine)
        #expect(task.lastDone == makeDate("2026-07-21T13:00:00Z"))
        #expect(RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-07-21T13:01:00Z"),
            calendar: calendar
        ) == makeDate("2026-07-21T19:00:00Z"))
    }

    @MainActor
    @Test
    func earlyMonthlyCompletionRequiresExplicitDetailPermissionAndPreservesFixedSchedule() throws {
        let context = makeInMemoryContext()
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .monthly,
            interval: 1,
            startDate: makeDate("2026-07-27T09:00:00Z"),
            monthDays: [27],
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )
        let task = makeTask(
            in: context,
            name: "Rent",
            interval: 30,
            lastDone: nil,
            emoji: nil,
            scheduleMode: .fixedInterval,
            recurrenceRule: .advanced(advanced),
            scheduleAnchor: advanced.startDate
        )
        let paidAt = makeDate("2026-07-26T10:00:00Z")
        let scheduledOccurrence = makeDate("2026-07-27T09:00:00Z")

        let blocked = try #require(try RoutineLogHistory.advanceTask(
            taskID: task.id,
            completedAt: paidAt,
            context: context,
            calendar: calendar
        ))
        #expect(blocked.result == .ignoredAlreadyCompletedToday)
        #expect(task.lastDone == nil)

        let completed = try #require(try RoutineLogHistory.advanceTask(
            taskID: task.id,
            completedAt: paidAt,
            allowEarlyScheduledCompletion: true,
            context: context,
            calendar: calendar
        ))
        let log = try #require(context.fetch(FetchDescriptor<RoutineLog>()).first)

        #expect(completed.result == .completedRoutine)
        #expect(task.lastDone == paidAt)
        #expect(task.lastSatisfiedScheduledOccurrenceAt == scheduledOccurrence)
        #expect(log.timestamp == paidAt)
        #expect(log.scheduledOccurrenceAt == scheduledOccurrence)
        #expect(RoutineDateMath.dueDate(
            for: task,
            referenceDate: paidAt,
            calendar: calendar
        ) == makeDate("2026-08-27T09:00:00Z"))
    }

    @MainActor
    @Test
    func hourlyCompletionsRemainSeparateAfterLogDeduplication() throws {
        let context = makeInMemoryContext()
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .hourly,
            interval: 6,
            startDate: makeDate("2026-07-21T07:00:00Z"),
            hourlyMode: .dailyWindow,
            dailyWindowStart: RoutineTimeOfDay(hour: 7, minute: 0),
            dailyWindowEnd: RoutineTimeOfDay(hour: 22, minute: 0),
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )
        let task = makeTask(
            in: context,
            name: "Medicine",
            interval: 1,
            lastDone: nil,
            emoji: nil,
            scheduleMode: .fixedInterval,
            recurrenceRule: .advanced(advanced),
            scheduleAnchor: advanced.startDate
        )

        let first = try #require(try RoutineLogHistory.advanceTask(
            taskID: task.id,
            completedAt: makeDate("2026-07-21T07:05:00Z"),
            context: context,
            calendar: calendar
        ))
        let earlyDuplicate = try #require(try RoutineLogHistory.advanceTask(
            taskID: task.id,
            completedAt: makeDate("2026-07-21T08:00:00Z"),
            context: context,
            calendar: calendar
        ))
        let second = try #require(try RoutineLogHistory.advanceTask(
            taskID: task.id,
            completedAt: makeDate("2026-07-21T13:10:00Z"),
            context: context,
            calendar: calendar
        ))

        #expect(first.result == .completedRoutine)
        #expect(earlyDuplicate.result == .ignoredAlreadyCompletedToday)
        #expect(second.result == .completedRoutine)
        #expect(!(try RoutineLogHistory.deduplicateRedundantSameDayLogs(
            in: context,
            calendar: calendar
        )))
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(logs.map(\.timestamp).compactMap { $0 }.sorted() == [
            makeDate("2026-07-21T07:00:00Z"),
            makeDate("2026-07-21T13:00:00Z")
        ])
    }

    @Test
    func multipleDailyWindowOccurrencesKeepTheirScheduledTimestampIdentity() throws {
        let window = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 22, minute: 0)
        )
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .daily,
            interval: 1,
            startDate: makeDate("2026-07-21T08:00:00Z"),
            timesOfDay: [
                RoutineTimeOfDay(hour: 8, minute: 0),
                RoutineTimeOfDay(hour: 20, minute: 0)
            ],
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )
        let task = RoutineTask(
            scheduleMode: .fixedInterval,
            recurrenceRule: .advanced(advanced, timeRange: window),
            scheduleAnchor: advanced.startDate
        )

        #expect(RoutineDateMath.scheduledOccurrences(
            for: task,
            on: makeDate("2026-07-21T12:00:00Z"),
            calendar: calendar
        ) == [
            makeDate("2026-07-21T08:00:00Z"),
            makeDate("2026-07-21T20:00:00Z")
        ])
        #expect(RoutineDateMath.completionTargetDate(
            for: task,
            selectedDay: makeDate("2026-07-21T20:30:00Z"),
            referenceDate: makeDate("2026-07-21T20:30:00Z"),
            calendar: calendar
        ) == makeDate("2026-07-21T08:00:00Z"))

        task.lastDone = makeDate("2026-07-21T08:00:00Z")
        #expect(RoutineDateMath.completionTargetDate(
            for: task,
            selectedDay: makeDate("2026-07-21T20:30:00Z"),
            referenceDate: makeDate("2026-07-21T20:30:00Z"),
            calendar: calendar
        ) == makeDate("2026-07-21T20:00:00Z"))
    }

    @MainActor
    @Test
    func subdailyMissedAndCanceledLogsResolveOnlyTheirOwnOccurrence() throws {
        let context = makeInMemoryContext()
        let window = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 22, minute: 0)
        )
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .daily,
            interval: 1,
            startDate: makeDate("2026-07-21T08:00:00Z"),
            timesOfDay: [
                RoutineTimeOfDay(hour: 8, minute: 0),
                RoutineTimeOfDay(hour: 20, minute: 0)
            ],
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )
        let task = makeTask(
            in: context,
            name: "Medicine",
            interval: 1,
            lastDone: nil,
            emoji: nil,
            scheduleMode: .fixedInterval,
            recurrenceRule: .advanced(advanced, timeRange: window),
            scheduleAnchor: advanced.startDate
        )

        _ = try RoutineLogHistory.markExactTimedOccurrenceMissed(
            taskID: task.id,
            missedAt: makeDate("2026-07-21T08:00:00Z"),
            context: context,
            calendar: calendar
        )
        _ = try RoutineLogHistory.markExactTimedOccurrenceMissed(
            taskID: task.id,
            missedAt: makeDate("2026-07-21T20:00:00Z"),
            context: context,
            calendar: calendar
        )
        _ = try RoutineLogHistory.markExactTimedOccurrenceCanceled(
            taskID: task.id,
            canceledAt: makeDate("2026-07-21T20:00:00Z"),
            context: context,
            calendar: calendar
        )

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(logs.contains {
            $0.kind == .missed && $0.timestamp == makeDate("2026-07-21T08:00:00Z")
        })
        #expect(!logs.contains {
            $0.kind == .missed && $0.timestamp == makeDate("2026-07-21T20:00:00Z")
        })
        #expect(logs.contains {
            $0.kind == .canceled && $0.timestamp == makeDate("2026-07-21T20:00:00Z")
        })
    }

    @Test
    func hourlyTaskBecomesActionableAgainAtNextOccurrence() {
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .hourly,
            interval: 6,
            startDate: makeDate("2026-07-21T07:00:00Z"),
            hourlyMode: .dailyWindow,
            dailyWindowStart: RoutineTimeOfDay(hour: 7, minute: 0),
            dailyWindowEnd: RoutineTimeOfDay(hour: 22, minute: 0),
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )
        let task = RoutineTask(
            scheduleMode: .fixedInterval,
            recurrenceRule: .advanced(advanced),
            lastDone: makeDate("2026-07-21T07:00:00Z")
        )

        #expect(RoutineDateMath.isCompletedForCurrentPeriod(
            true,
            task: task,
            referenceDate: makeDate("2026-07-21T12:59:00Z"),
            calendar: calendar
        ))
        #expect(!RoutineDateMath.isCompletedForCurrentPeriod(
            true,
            task: task,
            referenceDate: makeDate("2026-07-21T13:00:00Z"),
            calendar: calendar
        ))
    }

    @Test
    func simpleAndAdvancedCreateDraftsRemainIndependent() throws {
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .weekly,
            interval: 3,
            startDate: makeDate("2026-07-21T09:00:00Z"),
            weekdays: [7],
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )
        var state = AddRoutineFeature.State(
            basics: AddRoutineBasicsState(routineName: "Training"),
            schedule: AddRoutineScheduleState(
                scheduleMode: .fixedInterval,
                frequency: .week,
                frequencyValue: 2,
                recurrenceEditorMode: .advanced,
                advancedRecurrenceRule: advanced,
                recurrenceKind: .weekly,
                recurrenceHasExplicitTime: true,
                recurrenceTimeOfDay: RoutineTimeOfDay(hour: 18, minute: 0),
                recurrenceWeekday: 3,
                recurrenceWeekdays: [3, 5]
            )
        )

        let advancedRequest = try #require(AddRoutineSaveRequest(state: state, calendar: calendar))
        #expect(advancedRequest.recurrenceRule == .advanced(advanced))

        state.schedule.recurrenceEditorMode = .simple
        let simpleRequest = try #require(AddRoutineSaveRequest(state: state, calendar: calendar))
        #expect(simpleRequest.recurrenceRule == .weekly(
            on: [3, 5],
            at: RoutineTimeOfDay(hour: 18, minute: 0)
        ))
        #expect(state.schedule.advancedRecurrenceRule == advanced)
    }

    @Test
    func existingAdvancedTaskReopensInAdvancedEditor() {
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .monthly,
            interval: 2,
            startDate: makeDate("2026-07-21T09:00:00Z"),
            monthlyPattern: .ordinalWeekday,
            weekdayOrdinal: .first,
            ordinalWeekday: 6,
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )
        let task = RoutineTask(
            name: "Review",
            scheduleMode: .fixedInterval,
            recurrenceRule: .advanced(advanced)
        )
        var state = TaskDetailFeature.State(task: task)

        withDependencies {
            $0.date.now = makeDate("2026-07-21T10:00:00Z")
            $0.calendar = calendar
        } operation: {
            TaskDetailFeature().syncEditFormFromTask(&state)
        }

        #expect(state.editRecurrenceEditorMode == .advanced)
        #expect(state.editAdvancedRecurrenceRule == advanced.normalized(calendar: calendar))
        #expect(!TaskDetailEditChangeDetector.canSave(TaskDetailEditChangeRequest(state: state)))
    }

    @Test
    func advancedCreateDraftRoundTripsWithoutChangingLegacyDraftDecoding() throws {
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .hourly,
            interval: 6,
            startDate: makeDate("2026-07-21T07:00:00Z"),
            hourlyMode: .dailyWindow,
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )
        let state = AddRoutineFeature.State(
            basics: AddRoutineBasicsState(
                routineName: "Medicine",
                thinkingNeeded: .high
            ),
            schedule: AddRoutineScheduleState(
                scheduleMode: .fixedInterval,
                recurrenceEditorMode: .advanced,
                advancedRecurrenceRule: advanced
            )
        )

        let encoded = try JSONEncoder().encode(AddRoutineDraftSnapshot(state: state))
        let decoded = try JSONDecoder().decode(AddRoutineDraftSnapshot.self, from: encoded)
        let restored = decoded.applied(to: AddRoutineFeature.State())

        #expect(restored.schedule.recurrenceEditorMode == .advanced)
        #expect(restored.schedule.advancedRecurrenceRule == advanced.normalized(calendar: .current))
        #expect(restored.basics.thinkingNeeded == .high)

        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "recurrenceEditorMode")
        legacyObject.removeValue(forKey: "advancedRecurrenceRule")
        legacyObject.removeValue(forKey: "thinkingNeeded")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacy = try JSONDecoder().decode(AddRoutineDraftSnapshot.self, from: legacyData)
        #expect(legacy.recurrenceEditorMode == nil)
        #expect(legacy.advancedRecurrenceRule == nil)
        #expect(legacy.thinkingNeeded == nil)
        #expect(legacy.applied(to: AddRoutineFeature.State()).basics.thinkingNeeded == .none)
    }
}
