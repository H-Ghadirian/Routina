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
    func unsupportedCombinationsAreRejectedInsteadOfLosingData() {
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
        draft.availability = .window(
            RoutineTimeRange(
                start: RoutineTimeOfDay(hour: 7, minute: 0),
                end: RoutineTimeOfDay(hour: 10, minute: 0)
            )
        )

        #expect(draft.validationIssue == .structuredAvailabilityUnsupported)
        #expect(draft.resolvedRecurrenceRule(calendar: calendar) == nil)
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
    func formDraftSurfacesUnsupportedStructuredAvailabilityInsteadOfDroppingIt() {
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

        #expect(state.candidateRecurrenceDraft.validationIssue == .structuredAvailabilityUnsupported)
        #expect(state.candidateRecurrenceDraft.resolvedRecurrenceRule(calendar: calendar) == nil)
    }

    private func makeDate(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value) ?? Date(timeIntervalSince1970: 0)
    }
}
