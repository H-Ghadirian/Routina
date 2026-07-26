import Foundation
import Testing
#if SWIFT_PACKAGE
@testable import RoutinaAppSupport
#elseif os(macOS)
@testable import RoutinaMacOSDev
#else
@testable import Routina
#endif

struct RoutineRecurrenceDraftTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        calendar.firstWeekday = 2
        return calendar
    }

    @Test
    func compactRulesRoundTripThroughUnifiedDraft() throws {
        let exactTime = RoutineTimeOfDay(hour: 9, minute: 30)
        let window = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 10, minute: 0)
        )
        let rules: [RoutineRecurrenceRule] = [
            .interval(days: 14, timeRange: window),
            RoutineRecurrenceRule(kind: .dailyTime),
            .weekly(on: [2, 4, 6], at: exactTime),
            .monthly(on: [1, 15, 31], timeRange: window)
        ]

        for rule in rules {
            let draft = RoutineRecurrenceDraft(
                recurrenceRule: rule,
                timeRangeRole: .scheduledBlock,
                calendar: calendar
            )

            #expect(draft.validationIssue == nil)
            #expect(try #require(draft.resolvedRecurrenceRule(calendar: calendar)) == rule)
            #expect(
                draft.timeRangeRole == (rule.timeRange == nil ? .availability : .scheduledBlock)
            )
        }
    }

    @Test
    func structuredRulesRoundTripEverySupportedFrequencyAndPattern() throws {
        let start = makeDate("2026-07-21T09:00:00Z")
        let end = makeDate("2027-07-21T09:00:00Z")
        let rules = [
            RoutineAdvancedRecurrenceRule(
                version: 2,
                frequency: .hourly,
                interval: 6,
                startDate: start,
                hourlyMode: .dailyWindow,
                dailyWindowStart: RoutineTimeOfDay(hour: 7, minute: 0),
                dailyWindowEnd: RoutineTimeOfDay(hour: 22, minute: 0),
                endMode: .afterCount,
                endDate: end,
                occurrenceCount: 40,
                timeZoneIdentifier: "UTC",
                calendar: calendar
            ),
            RoutineAdvancedRecurrenceRule(
                frequency: .daily,
                interval: 3,
                startDate: start,
                timesOfDay: [
                    RoutineTimeOfDay(hour: 8, minute: 0),
                    RoutineTimeOfDay(hour: 20, minute: 30)
                ],
                endMode: .onDate,
                endDate: end,
                timeZoneIdentifier: "UTC",
                calendar: calendar
            ),
            RoutineAdvancedRecurrenceRule(
                frequency: .weekly,
                interval: 2,
                startDate: start,
                weekdays: [2, 4, 6],
                timeZoneIdentifier: "UTC",
                calendar: calendar
            ),
            RoutineAdvancedRecurrenceRule(
                frequency: .monthly,
                interval: 2,
                startDate: start,
                monthDays: [1, 15, 31],
                monthlyPattern: .dayOfMonth,
                timeZoneIdentifier: "UTC",
                calendar: calendar
            ),
            RoutineAdvancedRecurrenceRule(
                frequency: .monthly,
                interval: 3,
                startDate: start,
                monthlyPattern: .ordinalWeekday,
                weekdayOrdinal: .last,
                ordinalWeekday: 6,
                timeZoneIdentifier: "UTC",
                calendar: calendar
            ),
            RoutineAdvancedRecurrenceRule(
                frequency: .yearly,
                interval: 2,
                startDate: start,
                monthDays: [1, 31],
                monthsOfYear: [1, 7, 12],
                timeZoneIdentifier: "UTC",
                calendar: calendar
            )
        ].map(RoutineRecurrenceRule.advanced)

        for rule in rules {
            let draft = RoutineRecurrenceDraft(
                recurrenceRule: rule,
                calendar: calendar
            )

            #expect(draft.cadence == .scheduled)
            #expect(draft.validationIssue == nil)
            #expect(try #require(draft.resolvedRecurrenceRule(calendar: calendar)) == rule)
        }
    }

    @Test
    func structuredWindowRoundTripsRecurrenceAvailabilityAndRole() throws {
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
        let original = RoutineRecurrenceRule.advanced(advanced, timeRange: window)
        let draft = RoutineRecurrenceDraft(
            recurrenceRule: original,
            timeRangeRole: .scheduledBlock,
            calendar: calendar
        )

        #expect(draft.validationIssue == nil)
        #expect(draft.availability == .window(window))
        #expect(draft.timeRangeRole == .scheduledBlock)
        #expect(try #require(draft.resolvedRecurrenceRule(calendar: calendar)) == original)
    }

    @Test
    func cadenceFreeAndItemRunoutDraftsKeepCompatibilityRulesExplicit() throws {
        let compatibilityRule = RoutineRecurrenceRule.interval(days: 21)
        let window = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 10, minute: 0)
        )
        let none = RoutineRecurrenceDraft(
            recurrenceRule: compatibilityRule,
            cadence: RoutineRecurrenceDraft.Cadence.none,
            calendar: calendar
        )
        let noneWithAvailability = RoutineRecurrenceDraft(
            cadence: .none,
            availability: .window(window),
            timeRangeRole: .scheduledBlock
        )
        let runout = RoutineRecurrenceDraft(
            recurrenceRule: compatibilityRule,
            cadence: .itemRunout,
            calendar: calendar
        )

        #expect(try #require(none.resolvedRecurrenceRule(calendar: calendar)) == .interval(days: 1))
        #expect(
            try #require(noneWithAvailability.resolvedRecurrenceRule(calendar: calendar))
                == .interval(days: 1, timeRange: window)
        )
        #expect(try #require(runout.resolvedRecurrenceRule(calendar: calendar)) == compatibilityRule)
    }

    @Test
    func fixedAvailabilityWindowResolvesWithoutLosingStructuredRecurrence() throws {
        let window = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 10, minute: 0)
        )
        var draft = RoutineRecurrenceDraft(
            cadence: .scheduled,
            frequency: .weekly,
            interval: 2,
            weekdays: [2, 4]
        )

        #expect(draft.validationIssue == .fixedStartRequired)
        #expect(draft.resolvedRecurrenceRule(calendar: calendar) == nil)

        draft.startDate = makeDate("2026-07-21T09:00:00Z")
        draft.timeZoneIdentifier = "UTC"
        draft.availability = .window(window)

        let rule = try #require(draft.resolvedRecurrenceRule(calendar: calendar))
        #expect(draft.validationIssue == nil)
        #expect(rule.advanced?.frequency == .weekly)
        #expect(rule.advanced?.interval == 2)
        #expect(rule.advanced?.weekdays == [2, 4])
        #expect(rule.timeRange == window)
    }

    @Test
    func subdailyStructuredSchedulesRejectAmbiguousOuterWindow() {
        let window = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 10, minute: 0)
        )
        let start = makeDate("2026-07-21T09:00:00Z")
        let hourly = RoutineRecurrenceDraft(
            cadence: .scheduled,
            frequency: .hourly,
            interval: 2,
            availability: .window(window),
            startDate: start,
            timeZoneIdentifier: "UTC"
        )
        let multipleTimes = RoutineRecurrenceDraft(
            cadence: .scheduled,
            frequency: .daily,
            availability: .window(window),
            startDate: start,
            occurrenceTimes: [
                RoutineTimeOfDay(hour: 8, minute: 0),
                RoutineTimeOfDay(hour: 20, minute: 0)
            ],
            timeZoneIdentifier: "UTC"
        )

        #expect(hourly.validationIssue == .hourlyAvailabilityWindowUnsupported)
        #expect(hourly.resolvedRecurrenceRule(calendar: calendar) == nil)
        #expect(multipleTimes.validationIssue == .multipleDailyTimesAvailabilityWindowUnsupported)
        #expect(multipleTimes.resolvedRecurrenceRule(calendar: calendar) == nil)
    }

    @Test
    func addFormExposesItsCurrentRuleAsUnifiedDraft() throws {
        let state = AddRoutineFeature.State(
            basics: AddRoutineBasicsState(
                routineName: "Training",
                trackingCadenceEnabled: true
            ),
            schedule: AddRoutineScheduleState(
                scheduleMode: .fixedInterval,
                recurrenceKind: .weekly,
                recurrenceHasTimeRange: true,
                recurrenceTimeRangeRole: .scheduledBlock,
                recurrenceTimeRangeStart: RoutineTimeOfDay(hour: 7, minute: 0),
                recurrenceTimeRangeEnd: RoutineTimeOfDay(hour: 10, minute: 0),
                recurrenceWeekday: 2,
                recurrenceWeekdays: [2, 4, 6]
            )
        )

        let draft = state.candidateRecurrenceDraft

        #expect(draft.cadence == .scheduled)
        #expect(draft.timeRangeRole == .scheduledBlock)
        #expect(
            try #require(draft.resolvedRecurrenceRule(calendar: calendar))
                == state.candidateRecurrenceRule
        )
    }

    @Test
    func addDraftOwnsSaveUntilALegacyControlChanges() throws {
        let exactTime = RoutineTimeOfDay(hour: 18, minute: 30)
        let draft = RoutineRecurrenceDraft(
            cadence: .afterCompletion,
            frequency: .weekly,
            interval: 2,
            availability: .at(exactTime)
        )
        var state = AddRoutineFeature.State(
            basics: AddRoutineBasicsState(routineName: "Training"),
            schedule: AddRoutineScheduleState(scheduleMode: .fixedInterval)
        )
        let handler = AddRoutineScheduleMutationHandler(
            now: { makeDate("2026-07-21T09:00:00Z") },
            calendar: calendar
        )

        handler.setRecurrenceDraft(draft, state: &state)

        #expect(state.schedule.recurrenceDraftIsAuthoritative)
        #expect(
            try #require(AddRoutineSaveRequest(state: state, calendar: calendar)).recurrenceRule
                == .interval(days: 14, at: exactTime)
        )

        handler.setFrequencyValue(3, state: &state)

        #expect(!state.schedule.recurrenceDraftIsAuthoritative)
        #expect(
            try #require(AddRoutineSaveRequest(state: state, calendar: calendar)).recurrenceRule
                == .interval(days: 21, at: exactTime)
        )
    }

    @Test @MainActor
    func editDraftPersistsMultipleMonthlyDatesAndWindowRole() throws {
        let window = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 10, minute: 0)
        )
        let draft = RoutineRecurrenceDraft(
            cadence: .scheduled,
            frequency: .monthly,
            availability: .window(window),
            timeRangeRole: .scheduledBlock,
            monthDays: [1, 15, 31]
        )
        var state = TaskDetailFeature.State(
            task: RoutineTask(
                name: "Review finances",
                scheduleMode: .fixedInterval,
                recurrenceRule: .interval(days: 1)
            ),
            isEditSheetPresented: true,
            editRoutineName: "Review finances",
            editScheduleMode: .fixedInterval
        )
        let handler = TaskDetailRecurrenceEditActionHandler(
            now: { makeDate("2026-07-21T09:00:00Z") },
            calendar: calendar
        )

        _ = handler.editRecurrenceDraftChanged(draft, state: &state)
        let request = try #require(
            TaskDetailEditSaveRequestBuilder(
                now: { makeDate("2026-07-21T09:00:00Z") },
                calendar: calendar,
                matrixPriority: { _, _ in .medium }
            ).build(state: &state)
        )

        #expect(state.editRecurrenceDraftIsAuthoritative)
        #expect(request.recurrenceRule == .monthly(on: [1, 15, 31], timeRange: window))
        #expect(request.recurrenceTimeRangeRole == .scheduledBlock)
    }

    @Test
    func formDraftCombinesStructuredRecurrenceWithAvailabilityWindow() throws {
        let window = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 10, minute: 0)
        )
        let state = AddRoutineFeature.State(
            basics: AddRoutineBasicsState(
                routineName: "Advanced training",
                trackingCadenceEnabled: true
            ),
            schedule: AddRoutineScheduleState(
                scheduleMode: .fixedInterval,
                recurrenceEditorMode: .advanced,
                advancedRecurrenceRule: RoutineAdvancedRecurrenceRule(
                    frequency: .weekly,
                    interval: 2,
                    startDate: makeDate("2026-07-21T09:00:00Z"),
                    weekdays: [2, 4],
                    timeZoneIdentifier: "UTC",
                    calendar: calendar
                ),
                recurrenceHasTimeRange: true,
                recurrenceTimeRangeRole: .availability,
                recurrenceTimeRangeStart: RoutineTimeOfDay(hour: 7, minute: 0),
                recurrenceTimeRangeEnd: RoutineTimeOfDay(hour: 10, minute: 0)
            )
        )

        let draft = state.candidateRecurrenceDraft
        let rule = try #require(draft.resolvedRecurrenceRule(calendar: calendar))
        #expect(draft.validationIssue == nil)
        #expect(rule.advanced?.frequency == .weekly)
        #expect(rule.advanced?.interval == 2)
        #expect(rule.advanced?.weekdays == [2, 4])
        #expect(rule.advanced == state.schedule.advancedRecurrenceRule)
        #expect(rule.timeRange == window)
    }

    @Test
    func everyNComposerTransitionCreatesStableAnchorAndKeepsExactTime() throws {
        let now = makeDate("2026-07-21T09:00:00Z")
        let exactTime = RoutineTimeOfDay(hour: 18, minute: 30)
        let draft = RoutineRecurrenceDraft(
            cadence: .scheduled,
            frequency: .weekly,
            availability: .at(exactTime),
            weekdays: [2, 4]
        )

        let updated = draft.settingInterval(2, now: now, calendar: calendar)
        let rule = try #require(updated.resolvedRecurrenceRule(calendar: calendar))

        #expect(updated.requiresFixedScheduleDetails)
        #expect(updated.startDate == now)
        #expect(updated.timeZoneIdentifier == "GMT")
        #expect(updated.availability == .anyTime)
        #expect(updated.occurrenceTimes == [exactTime])
        #expect(rule.advanced?.frequency == .weekly)
        #expect(rule.advanced?.interval == 2)
        #expect(rule.advanced?.weekdays == [2, 4])
        #expect(rule.advanced?.timesOfDay == [exactTime])
    }

    @Test
    func composerCanSimplifySingleTimeScheduleWithoutLosingTime() throws {
        let now = makeDate("2026-07-21T09:00:00Z")
        let exactTime = RoutineTimeOfDay(hour: 18, minute: 30)
        let fixed = RoutineRecurrenceDraft(
            cadence: .scheduled,
            frequency: .weekly,
            interval: 1,
            availability: .anyTime,
            startDate: now,
            weekdays: [2, 4],
            occurrenceTimes: [exactTime],
            timeZoneIdentifier: "UTC"
        )

        let simplified = fixed.settingFixedScheduleDetailsEnabled(
            false,
            now: now,
            calendar: calendar
        )

        #expect(simplified.canDisableFixedScheduleDetails)
        #expect(!simplified.usesFixedScheduleDetails)
        #expect(simplified.startDate == nil)
        #expect(simplified.timeZoneIdentifier == nil)
        #expect(simplified.occurrenceTimes.isEmpty)
        #expect(simplified.availability == .at(exactTime))
        #expect(
            try #require(simplified.resolvedRecurrenceRule(calendar: calendar))
                == .weekly(on: [2, 4], at: exactTime)
        )
    }

    @Test
    func composerKeepsWindowWhenSwitchingToEveryNFixedSchedule() throws {
        let now = makeDate("2026-07-21T09:00:00Z")
        let window = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 10, minute: 0)
        )
        let draft = RoutineRecurrenceDraft(
            cadence: .scheduled,
            frequency: .weekly,
            availability: .window(window),
            weekdays: [2, 4]
        )

        let updated = draft.settingInterval(2, now: now, calendar: calendar)

        #expect(updated.availability == .window(window))
        #expect(updated.startDate == makeDate("2026-07-21T07:00:00Z"))
        #expect(updated.validationIssue == nil)
        #expect(updated.occurrenceTimes == [window.start])
        let rule = try #require(updated.resolvedRecurrenceRule(calendar: calendar))
        #expect(rule.advanced?.interval == 2)
        #expect(rule.advanced?.weekdays == [2, 4])
        #expect(rule.timeRange == window)
    }

    @Test
    func yearlyComposerSupportsSeveralMonthsAndDates() throws {
        let now = makeDate("2026-07-21T09:00:00Z")
        var draft = RoutineRecurrenceDraft(
            cadence: .scheduled,
            frequency: .daily
        ).selectingFrequency(.yearly, now: now, calendar: calendar)
        draft.monthsOfYear = [1, 7, 12]
        draft.monthDays = [1, 15, 31]
        draft = draft.normalized()

        let rule = try #require(draft.resolvedRecurrenceRule(calendar: calendar))

        #expect(draft.usesFixedScheduleDetails)
        #expect(rule.advanced?.frequency == .yearly)
        #expect(rule.advanced?.monthsOfYear == [1, 7, 12])
        #expect(rule.advanced?.monthDays == [1, 15, 31])
    }

    @Test
    func switchingBetweenFixedAndAfterDoneKeepsExactTimeIntent() throws {
        let now = makeDate("2026-07-21T09:00:00Z")
        let exactTime = RoutineTimeOfDay(hour: 18, minute: 30)
        let fixed = RoutineRecurrenceDraft(
            cadence: .scheduled,
            frequency: .daily,
            startDate: now,
            occurrenceTimes: [exactTime],
            timeZoneIdentifier: "UTC"
        )

        let afterDone = fixed.selectingCadence(
            .afterCompletion,
            now: now,
            calendar: calendar
        )
        let scheduledAgain = afterDone.selectingCadence(
            .scheduled,
            now: now,
            calendar: calendar
        )

        #expect(afterDone.availability == .at(exactTime))
        #expect(
            try #require(afterDone.resolvedRecurrenceRule(calendar: calendar))
                == .interval(days: 1, at: exactTime)
        )
        #expect(scheduledAgain.availability == .anyTime)
        #expect(scheduledAgain.occurrenceTimes == [exactTime])
        #expect(
            try #require(scheduledAgain.resolvedRecurrenceRule(calendar: calendar))
                .advanced?.timesOfDay == [exactTime]
        )
    }

    private func makeDate(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value) ?? Date(timeIntervalSince1970: 0)
    }
}
