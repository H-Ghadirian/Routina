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

@MainActor
struct AddRoutineFeatureTests {
    @Test
    func stateInitializationUsesInjectedDateForRecurrenceDefaults() {
        let referenceDate = makeDate("2026-03-20T10:00:00Z")
        let calendar = makeTestCalendar()

        let state = AddRoutineFeature.State(
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(state.schedule.advancedRecurrenceRule.startDate == referenceDate)
        #expect(state.schedule.recurrenceWeekday == 6)
        #expect(state.schedule.recurrenceDayOfMonth == 20)
    }

    @Test
    func frequencyMetadata_isConsistent() {
        #expect(AddRoutineFeature.Frequency.day.daysMultiplier == 1)
        #expect(AddRoutineFeature.Frequency.week.daysMultiplier == 7)
        #expect(AddRoutineFeature.Frequency.month.daysMultiplier == 30)

        #expect(AddRoutineFeature.Frequency.day.singularLabel == "day")
        #expect(AddRoutineFeature.Frequency.week.singularLabel == "week")
        #expect(AddRoutineFeature.Frequency.month.singularLabel == "month")
    }

    @Test
    func recurrenceRuleMetadata_describesNewScheduleTypes() {
        #expect(RoutineRecurrenceRule.Kind.intervalDays.pickerTitle == "Interval")
        #expect(RoutineRecurrenceRule.Kind.dailyTime.pickerTitle == "Daily")
        #expect(RoutineRecurrenceRule.Kind.weekly.pickerTitle == "Weekday")
        #expect(RoutineRecurrenceRule.Kind.monthlyDay.pickerTitle == "Month day")
        #expect(RoutineRecurrenceRule.Kind.calendarCases == [.weekly, .monthlyDay])
        #expect(RoutineRecurrenceRule.Kind.intervalDays.repeatBasis == .interval)
        #expect(RoutineRecurrenceRule.Kind.weekly.repeatBasis == .calendar)
        #expect(RoutineRecurrenceRule.Kind.intervalDays.replacingRepeatBasis(.calendar) == .weekly)
        #expect(RoutineRecurrenceRule.Kind.dailyTime.replacingRepeatBasis(.calendar) == .weekly)
        #expect(RoutineRecurrenceRule.Kind.weekly.replacingRepeatBasis(.interval) == .intervalDays)
        #expect(RoutineRecurrenceRule.Kind.monthlyDay.replacingRepeatBasis(.calendar) == .monthlyDay)
    }

    @Test
    func routineDurationModeChanged_toMultiDayClampsDailyInterval() async {
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineDurationMode: .oneDay),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .fixedInterval,
                    frequency: .day,
                    frequencyValue: 1,
                    recurrenceKind: .intervalDays
                )
            )
        ) {
            makeFeature()
        }

        await store.send(.routineDurationModeChanged(.multiDay)) {
            $0.basics.routineDurationMode = .multiDay
            $0.schedule.frequencyValue = 2
        }

        #expect(store.state.candidateRecurrenceRule == .interval(days: 2))
    }

    @Test
    func routineDurationModeChanged_toMultiDayConvertsDailyCalendarToInterval() async {
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineDurationMode: .oneDay),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .fixedInterval,
                    frequency: .day,
                    frequencyValue: 1,
                    recurrenceKind: .dailyTime
                )
            )
        ) {
            makeFeature()
        }

        await store.send(.routineDurationModeChanged(.multiDay)) {
            $0.basics.routineDurationMode = .multiDay
            $0.schedule.frequencyValue = 2
            $0.schedule.recurrenceKind = .intervalDays
        }
    }

    @Test
    func frequencyChangesKeepMultiDayDailyIntervalAboveOneDay() async {
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineDurationMode: .multiDay),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .fixedInterval,
                    frequency: .week,
                    frequencyValue: 1,
                    recurrenceKind: .intervalDays
                )
            )
        ) {
            makeFeature()
        }

        await store.send(.frequencyChanged(.day)) {
            $0.schedule.frequency = .day
            $0.schedule.frequencyValue = 2
        }

        await store.send(.frequencyValueChanged(1))
    }

    @Test
    func recurrenceKindChanged_preservesAvailabilitySelection() async {
        let store = TestStore(
            initialState: makeState(
                schedule: AddRoutineScheduleState(
                    scheduleMode: .fixedInterval,
                    recurrenceKind: .weekly,
                    recurrenceHasExplicitTime: true
                )
            )
        ) {
            makeFeature()
        }

        await store.send(.recurrenceKindChanged(.intervalDays)) {
            $0.schedule.recurrenceKind = .intervalDays
        }

        #expect(store.state.schedule.recurrenceHasExplicitTime)
        #expect(!store.state.schedule.recurrenceHasTimeRange)
    }

    @Test
    func scheduleModeChanged_toGentlePreservesCalendarRepeatAndAvailabilitySelection() async {
        let store = TestStore(
            initialState: makeState(
                schedule: AddRoutineScheduleState(
                    scheduleMode: .fixedInterval,
                    recurrenceKind: .weekly,
                    recurrenceHasExplicitTime: true
                )
            )
        ) {
            makeFeature()
        }

        await store.send(.scheduleModeChanged(.softInterval)) {
            $0.schedule.scheduleMode = .softInterval
        }

        #expect(store.state.schedule.recurrenceKind == .weekly)
        #expect(store.state.schedule.recurrenceHasExplicitTime)
        #expect(!store.state.schedule.recurrenceHasTimeRange)
    }

    @Test
    func allDayChanged_forRoutineClearsAvailabilityTiming() async {
        let store = TestStore(
            initialState: makeState(
                schedule: AddRoutineScheduleState(
                    scheduleMode: .fixedInterval,
                    recurrenceKind: .intervalDays,
                    recurrenceHasExplicitTime: true,
                    recurrenceHasTimeRange: true
                )
            )
        ) {
            makeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.allDayChanged(true)) {
            $0.basics.isAllDay = true
            $0.schedule.recurrenceHasExplicitTime = false
            $0.schedule.recurrenceHasTimeRange = false
        }
    }

    @Test
    func allDayChanged_forTodoDoesNotCreateDeadline() async {
        let store = TestStore(
            initialState: makeState(
                schedule: AddRoutineScheduleState(
                    scheduleMode: .oneOff,
                    recurrenceHasExplicitTime: true,
                    recurrenceHasTimeRange: true
                )
            )
        ) {
            makeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.allDayChanged(true)) {
            $0.basics.isAllDay = true
            $0.schedule.recurrenceHasExplicitTime = false
            $0.schedule.recurrenceHasTimeRange = false
        }

        #expect(store.state.basics.deadline == nil)
    }

    @Test
    func saveTapped_preservesSeparateTodoDateAndTimeAvailabilityWindows() async {
        let start = makeDate("2026-04-10T09:00:00Z")
        let end = makeDate("2026-04-12T11:30:00Z")
        let expectedStartDate = makeDate("2026-04-10T00:00:00Z")
        let expectedEndDate = makeDate("2026-04-12T00:00:00Z")
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Call accountant",
                    routineEmoji: "📞",
                    availabilityStartDate: start,
                    availabilityEndDate: end
                ),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .oneOff,
                    recurrenceHasTimeRange: true,
                    recurrenceTimeRangeStart: RoutineTimeOfDay(hour: 9, minute: 0),
                    recurrenceTimeRangeEnd: RoutineTimeOfDay(hour: 11, minute: 30)
                )
            )
        ) {
            makeDelegateEchoFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(
            .delegate(
                .didSave(
                    makeSaveRequest(
                        name: "Call accountant",
                        frequencyInDays: 1,
                        recurrenceRule: .interval(
                            days: 1,
                            timeRange: RoutineTimeRange(
                                start: RoutineTimeOfDay(hour: 9, minute: 0),
                                end: RoutineTimeOfDay(hour: 11, minute: 30)
                            )
                        ),
                        emoji: "📞",
                        availabilityStartDate: expectedStartDate,
                        availabilityEndDate: expectedEndDate,
                        calendar: makeTestCalendar(),
                        scheduleMode: .oneOff
                    ))))
    }

    @Test
    func exactTodoAvailabilityActivatesPlanningOnSameDate() async {
        let calendar = makeTestCalendar()
        let availabilityDate = makeDate("2026-07-19T11:30:00Z")
        let otherPlanDate = makeDate("2026-07-22T09:00:00Z")
        let expectedDate = makeDate("2026-07-19T00:00:00Z")
        let store = TestStore(
            initialState: makeState(schedule: AddRoutineScheduleState(scheduleMode: .oneOff))
        ) {
            makeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, calendar: calendar)
        }

        await store.send(.availabilityStartDateChanged(availabilityDate)) {
            $0.basics.availabilityStartDate = expectedDate
            $0.basics.plannedDate = expectedDate
        }
        await store.send(.plannedDateChanged(otherPlanDate))

        #expect(store.state.basics.plannedDate == expectedDate)
    }

    @Test
    func saveTapped_exactTodoAvailabilityPlansSameDate() async {
        let availabilityDate = makeDate("2026-07-19T11:30:00Z")
        let expectedDate = makeDate("2026-07-19T00:00:00Z")
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Visit pharmacy",
                    availabilityStartDate: availabilityDate
                ),
                schedule: AddRoutineScheduleState(scheduleMode: .oneOff)
            )
        ) {
            makeDelegateEchoFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(
            .delegate(
                .didSave(
                    makeSaveRequest(
                        name: "Visit pharmacy",
                        frequencyInDays: 1,
                        recurrenceRule: .interval(days: 1),
                        emoji: "✨",
                        availabilityStartDate: expectedDate,
                        plannedDate: expectedDate,
                        calendar: makeTestCalendar(),
                        scheduleMode: .oneOff
                    ))))
    }

    @Test
    func saveTapped_preservesTimeBlockRole() async {
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Group session",
                    routineEmoji: "✨"
                ),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .fixedInterval,
                    recurrenceKind: .weekly,
                    recurrenceHasTimeRange: true,
                    recurrenceTimeRangeRole: .scheduledBlock,
                    recurrenceTimeRangeStart: RoutineTimeOfDay(hour: 18, minute: 30),
                    recurrenceTimeRangeEnd: RoutineTimeOfDay(hour: 20, minute: 0),
                    recurrenceWeekday: 5,
                    recurrenceWeekdays: [5]
                )
            )
        ) {
            makeDelegateEchoFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(
            .delegate(
                .didSave(
                    makeSaveRequest(
                        name: "Group session",
                        frequencyInDays: 1,
                        recurrenceRule: .weekly(
                            on: [5],
                            timeRange: RoutineTimeRange(
                                start: RoutineTimeOfDay(hour: 18, minute: 30),
                                end: RoutineTimeOfDay(hour: 20, minute: 0)
                            )
                        ),
                        emoji: "✨",
                        recurrenceTimeRangeRole: .scheduledBlock
                    ))))
    }

    @Test
    func taskTypeChanged_toRoutineClearsTodoAvailabilityDateBounds() async {
        let start = makeDate("2026-04-10T09:00:00Z")
        let end = makeDate("2026-04-10T11:30:00Z")
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    availabilityStartDate: start,
                    availabilityEndDate: end,
                    reminderAt: start
                ),
                schedule: AddRoutineScheduleState(scheduleMode: .oneOff)
            )
        ) {
            makeFeature()
        }

        await store.send(.taskTypeChanged(.routine)) {
            $0.basics.availabilityStartDate = nil
            $0.basics.availabilityEndDate = nil
            $0.basics.reminderAt = nil
            $0.schedule.scheduleMode = .fixedInterval
        }
    }

    @Test
    func taskLadderGroupCanBeEnabledForRepeatingTaskAndClearsForTodo() async {
        let store = TestStore(
            initialState: makeState(
                schedule: AddRoutineScheduleState(scheduleMode: .fixedInterval)
            )
        ) {
            makeFeature()
        }

        await store.send(.taskLadderGroupEnabledChanged(true)) {
            $0.basics.taskLadderGroupEnabled = true
        }
        await store.send(.taskTypeChanged(.todo)) {
            $0.basics.taskLadderGroupEnabled = false
            $0.basics.routineDurationMode = .oneDay
            $0.schedule.scheduleMode = .oneOff
        }
        await store.send(.taskLadderGroupEnabledChanged(true))
    }

    @Test
    func saveRequestCarriesRepeatingTaskLadderGroupActivation() throws {
        let state = makeState(
            basics: AddRoutineBasicsState(
                routineName: "Exercise",
                taskLadderGroupEnabled: true
            ),
            schedule: AddRoutineScheduleState(scheduleMode: .fixedInterval)
        )

        let request = try #require(AddRoutineSaveRequest(state: state))

        #expect(request.taskLadderGroupEnabled)
    }

    @Test
    func saveRequestSanitizesTaskLadderEntryWindowForItsSchedule() throws {
        let repeatingState = makeState(
            basics: AddRoutineBasicsState(
                routineName: "Rent",
                taskLadderEntryWindow: .beforeDue(days: 45)
            ),
            schedule: AddRoutineScheduleState(
                scheduleMode: .fixedInterval,
                frequency: .day,
                frequencyValue: 30,
                recurrenceKind: .intervalDays
            )
        )
        let repeatingRequest = try #require(AddRoutineSaveRequest(state: repeatingState))
        #expect(repeatingRequest.taskLadderEntryWindow == .beforeDue(days: 30))

        let deadline = makeDate("2026-10-31T18:00:00Z")
        let deadlineState = makeState(
            basics: AddRoutineBasicsState(
                routineName: "Submit application",
                deadline: deadline,
                taskLadderEntryWindow: .beforeDue(days: 45)
            ),
            schedule: AddRoutineScheduleState(scheduleMode: .oneOff)
        )
        let deadlineRequest = try #require(AddRoutineSaveRequest(state: deadlineState))
        #expect(deadlineRequest.deadline == deadline)
        #expect(deadlineRequest.taskLadderEntryWindow == .beforeDue(days: 45))

        let undatedState = makeState(
            basics: AddRoutineBasicsState(
                routineName: "Read someday",
                taskLadderEntryWindow: .onDueDate
            ),
            schedule: AddRoutineScheduleState(scheduleMode: .oneOff)
        )
        let undatedRequest = try #require(AddRoutineSaveRequest(state: undatedState))
        #expect(undatedRequest.taskLadderEntryWindow == .throughoutCycle)

        let gentleState = makeState(
            basics: AddRoutineBasicsState(
                routineName: "Reflect",
                taskLadderEntryWindow: .onDueDate
            ),
            schedule: AddRoutineScheduleState(scheduleMode: .softInterval)
        )
        let gentleRequest = try #require(AddRoutineSaveRequest(state: gentleState))
        #expect(gentleRequest.taskLadderEntryWindow == .throughoutCycle)
    }

    @Test
    func removingOneTimeDeadlineClearsTaskLadderEntryWindow() async {
        let deadline = makeDate("2026-10-31T18:00:00Z")
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Submit application",
                    deadline: deadline,
                    taskLadderEntryWindow: .onDueDate
                ),
                schedule: AddRoutineScheduleState(scheduleMode: .oneOff)
            )
        ) {
            makeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.deadlineEnabledChanged(false)) {
            $0.basics.deadline = nil
            $0.basics.taskLadderEntryWindow = .throughoutCycle
        }
    }

    @Test
    func creationDraftPreservesTaskLadderEntryWindow() {
        let state = makeState(
            basics: AddRoutineBasicsState(
                routineName: "Tax declaration",
                taskLadderEntryWindow: .beforeDue(days: 14)
            ),
            schedule: AddRoutineScheduleState(
                scheduleMode: .fixedInterval,
                frequency: .day,
                frequencyValue: 30,
                recurrenceKind: .intervalDays
            )
        )
        let snapshot = AddRoutineDraftSnapshot(state: state)
        var restored = makeState(
            schedule: AddRoutineScheduleState(
                scheduleMode: .fixedInterval,
                frequency: .day,
                frequencyValue: 30,
                recurrenceKind: .intervalDays
            )
        )

        snapshot.apply(to: &restored)

        #expect(restored.basics.taskLadderEntryWindow == .beforeDue(days: 14))
    }

    @Test
    func deadlineDisabled_preservesTodoAllDayFlag() async {
        let deadline = makeDate("2026-04-10T08:30:00Z")
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    deadline: deadline,
                    isAllDay: true
                ),
                schedule: AddRoutineScheduleState(scheduleMode: .oneOff)
            )
        ) {
            makeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.deadlineEnabledChanged(false)) {
            $0.basics.deadline = nil
        }

        #expect(store.state.basics.isAllDay)
    }

    @Test
    func emojiSanitization_keepsOnlyFirstCharacter() async {
        let store = TestStore(initialState: makeState()) {
            makeFeature()
        }

        await store.send(.routineEmojiChanged("  🔥🎯  ")) {
            $0.basics.routineEmoji = "🔥"
        }
    }

    @Test
    func emojiSanitization_usesFallbackWhenEmptyInput() async {
        let initialState = makeState(
            basics: AddRoutineBasicsState(routineEmoji: "✅")
        )
        let store = TestStore(initialState: initialState) {
            makeFeature()
        }

        await store.send(.routineEmojiChanged("   \n  "))
        #expect(store.state.basics.routineEmoji == "✅")
    }

    @Test
    func importanceAndUrgencyChanges_updateDerivedPriority() async {
        let store = TestStore(initialState: makeState()) {
            makeFeature()
        }

        await store.send(.importanceChanged(.level4)) {
            $0.basics.importance = .level4
            $0.basics.priority = .high
        }

        await store.send(.urgencyChanged(.level4)) {
            $0.basics.urgency = .level4
            $0.basics.priority = .urgent
        }
    }

    @Test
    func deadlineEnabledChanged_usesInjectedNowAndCanClearDeadline() async {
        let now = makeDate("2026-04-10T08:30:00Z")
        let store = TestStore(initialState: makeState()) {
            makeFeature()
        } withDependencies: {
            $0.date.now = now
        }

        await store.send(.deadlineEnabledChanged(true)) {
            $0.basics.deadline = now
        }

        await store.send(.deadlineEnabledChanged(false)) {
            $0.basics.deadline = nil
        }
    }

    @Test
    func reminderEnabledChanged_usesInjectedNowAndCanClearReminder() async {
        let now = makeDate("2026-04-10T08:30:00Z")
        let store = TestStore(initialState: makeState()) {
            makeFeature()
        } withDependencies: {
            $0.date.now = now
        }

        await store.send(.reminderEnabledChanged(true)) {
            $0.basics.reminderAt = now
        }

        await store.send(.reminderEnabledChanged(false)) {
            $0.basics.reminderAt = nil
        }
    }

    @Test
    func reminderChoicesUseExactTodoAvailabilityAsTheEventTime() async {
        let eventDay = makeDate("2026-08-25T00:00:00Z")
        let eventTime = makeDate("2026-08-25T15:00:00Z")
        let oneHourBefore = makeDate("2026-08-25T14:00:00Z")
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(availabilityStartDate: eventDay),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .oneOff,
                    recurrenceHasExplicitTime: true,
                    recurrenceTimeOfDay: RoutineTimeOfDay(hour: 15, minute: 0)
                )
            )
        ) {
            makeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: makeDate("2026-08-20T10:00:00Z"))
        }

        await store.send(.reminderEnabledChanged(true)) {
            $0.basics.reminderAt = eventTime
        }
        await store.send(.reminderLeadMinutesChanged(60)) {
            $0.basics.reminderAt = oneHourBefore
        }
    }

    @Test
    func availableRelationshipTasksChanged_prunesMissingRelationships() async {
        let keptID = UUID()
        let removedID = UUID()
        let store = TestStore(
            initialState: makeState(
                organization: AddRoutineOrganizationState(
                    relationships: [
                        RoutineTaskRelationship(targetTaskID: keptID, kind: .related),
                        RoutineTaskRelationship(targetTaskID: removedID, kind: .blocks),
                    ]
                )
            )
        ) {
            makeFeature()
        }

        let keptCandidate = RoutineTaskRelationshipCandidate(
            id: keptID,
            name: "Read",
            emoji: "📚",
            relationships: []
        )

        await store.send(.availableRelationshipTasksChanged([keptCandidate])) {
            $0.organization.availableRelationshipTasks = [keptCandidate]
            $0.organization.relationships = [RoutineTaskRelationship(targetTaskID: keptID, kind: .related)]
        }
    }

    @Test
    func availableEventsChanged_prunesMissingEventsAndToggleSelection() async {
        let keptID = UUID()
        let removedID = UUID()
        let store = TestStore(
            initialState: makeState(
                organization: AddRoutineOrganizationState(eventIDs: [keptID, removedID])
            )
        ) {
            makeFeature()
        }

        let keptEvent = RoutineEventLinkCandidate(
            id: keptID,
            title: "Appointment",
            emoji: "🗓️",
            isAllDay: false,
            startedAt: makeDate("2026-03-20T10:00:00Z"),
            endedAt: nil
        )

        await store.send(.availableEventsChanged([keptEvent])) {
            $0.organization.availableEvents = [keptEvent]
            $0.organization.eventIDs = [keptID]
        }

        await store.send(.toggleEventSelection(keptID)) {
            $0.organization.eventIDs = []
        }

        await store.send(.toggleEventSelection(keptID)) {
            $0.organization.eventIDs = [keptID]
        }
    }

    @Test
    func availableTagSummariesChanged_sortsByCombinedCounterDescending() async {
        let store = TestStore(initialState: makeState()) {
            makeFeature()
        }

        let summaries = [
            RoutineTagSummary(name: "Calm", linkedRoutineCount: 1, doneCount: 1),
            RoutineTagSummary(name: "Focus", linkedRoutineCount: 2, doneCount: 7),
            RoutineTagSummary(name: "Health", linkedRoutineCount: 4, doneCount: 4),
            RoutineTagSummary(name: "Brain", linkedRoutineCount: 3, doneCount: 5),
        ]

        await store.send(.availableTagSummariesChanged(summaries)) {
            $0.organization.availableTagSummaries = [
                RoutineTagSummary(name: "Focus", linkedRoutineCount: 2, doneCount: 7),
                RoutineTagSummary(name: "Brain", linkedRoutineCount: 3, doneCount: 5),
                RoutineTagSummary(name: "Health", linkedRoutineCount: 4, doneCount: 4),
                RoutineTagSummary(name: "Calm", linkedRoutineCount: 1, doneCount: 1),
            ]
            $0.organization.availableTags = ["Focus", "Brain", "Health", "Calm"]
        }
    }

    @Test
    func makeAddRoutineState_ordersAvailableTagsByUsageSummaries() {
        let frequentTask = RoutineTask(name: "Frequent", emoji: "✨", tags: ["Focus"], scheduleMode: .fixedInterval)
        let linkedTask = RoutineTask(name: "Linked", emoji: "✨", tags: ["Health"], scheduleMode: .fixedInterval)
        let doneHeavyTask = RoutineTask(name: "Done Heavy", emoji: "✨", tags: ["Finance"], scheduleMode: .fixedInterval)
        let alphabeticalTieTask = RoutineTask(name: "Alphabetical Tie", emoji: "✨", tags: ["Admin"], scheduleMode: .fixedInterval)

        let state = HomeAddRoutineSupport.makeAddRoutineState(
            tasks: [linkedTask, frequentTask, doneHeavyTask, alphabeticalTieTask],
            places: [],
            goals: [],
            doneStats: HomeDoneStats(
                countsByTaskID: [
                    frequentTask.id: 7,
                    doneHeavyTask.id: 3,
                ]
            ),
            tagCounterDisplayMode: .combinedTotal,
            relatedTagRules: [],
            initialDate: AddRoutineInitialDate(
                referenceDate: Date(timeIntervalSinceReferenceDate: 0),
                calendar: makeTestCalendar()
            )
        )

        #expect(state.organization.availableTags == ["Focus", "Finance", "Admin", "Health"])
        #expect(
            state.organization.availableTagSummaries == [
                RoutineTagSummary(name: "Focus", linkedRoutineCount: 1, doneCount: 7),
                RoutineTagSummary(name: "Finance", linkedRoutineCount: 1, doneCount: 3),
                RoutineTagSummary(name: "Admin", linkedRoutineCount: 1, doneCount: 0),
                RoutineTagSummary(name: "Health", linkedRoutineCount: 1, doneCount: 0),
            ])
    }

    @Test
    func saveTapped_sendsDelegateWithFrequencyInDays() async {
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Read", routineEmoji: "📚"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(scheduleMode: .fixedInterval, frequency: .week, frequencyValue: 3)
            )
        ) {
            makeDelegateEchoFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(
            .delegate(
                .didSave(
                    makeSaveRequest(
                        name: "Read",
                        frequencyInDays: 21,
                        recurrenceRule: .interval(days: 21),
                        emoji: "📚"
                    ))))
    }

    @Test
    func saveTapped_includesSelectedPlaceID() async {
        let placeID = UUID()
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Laundry", selectedPlaceID: placeID),
                organization: AddRoutineOrganizationState(
                    availablePlaces: [
                        RoutinePlaceSummary(
                            id: placeID,
                            name: "Home",
                            radiusMeters: 150,
                            linkedRoutineCount: 0
                        )
                    ]
                ),
                schedule: AddRoutineScheduleState(scheduleMode: .fixedInterval)
            )
        ) {
            makeDelegateEchoFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(
            .delegate(
                .didSave(
                    makeSaveRequest(
                        name: "Laundry",
                        frequencyInDays: 1,
                        recurrenceRule: .interval(days: 1),
                        emoji: "✨",
                        selectedPlaceID: placeID
                    ))))
    }

    @Test
    func saveTapped_includesMultipleSelectedPlaceIDs() async {
        let homeID = UUID()
        let gymID = UUID()
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Stretch",
                    selectedPlaceIDs: [homeID, gymID]
                ),
                organization: AddRoutineOrganizationState(
                    availablePlaces: [
                        RoutinePlaceSummary(id: homeID, name: "Home", radiusMeters: 150, linkedRoutineCount: 0),
                        RoutinePlaceSummary(id: gymID, name: "Gym", radiusMeters: 150, linkedRoutineCount: 0),
                    ]
                ),
                schedule: AddRoutineScheduleState(scheduleMode: .fixedInterval)
            )
        ) {
            makeDelegateEchoFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(
            .delegate(
                .didSave(
                    makeSaveRequest(
                        name: "Stretch",
                        frequencyInDays: 1,
                        recurrenceRule: .interval(days: 1),
                        emoji: "✨",
                        selectedPlaceID: homeID,
                        selectedPlaceIDs: [homeID, gymID]
                    ))))
    }

    @Test
    func saveTapped_includesEstimationValuesWhenPresent() async {
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Implement Apple Sign In",
                    estimatedDurationMinutes: 180,
                    storyPoints: 5,
                    focusModeEnabled: true
                ),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(scheduleMode: .oneOff)
            )
        ) {
            makeDelegateEchoFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(
            .delegate(
                .didSave(
                    makeSaveRequest(
                        name: "Implement Apple Sign In",
                        frequencyInDays: 1,
                        recurrenceRule: .interval(days: 1),
                        emoji: "✨",
                        scheduleMode: .oneOff,
                        estimatedDurationMinutes: 180,
                        storyPoints: 5,
                        focusModeEnabled: true
                    ))))
    }

    @Test
    func saveTapped_gentleRoutineKeepsRoutineFields() async {
        let date = makeDate("2026-04-10T09:00:00Z")
        let step = RoutineStep(title: "Classify support themes")
        let checklistItem = RoutineChecklistItem(title: "Summarize time sinks", intervalDays: 4)
        let exactTime = RoutineTimeOfDay(hour: 14, minute: 30)
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Analyzed support queue",
                    deadline: date,
                    routineDurationMode: .multiDay,
                    plannedDate: date,
                    reminderAt: date,
                    estimatedDurationMinutes: 120,
                    actualDurationMinutes: 95,
                    cadenceEnabled: true,
                    nudgesEnabled: false
                ),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .softInterval,
                    frequency: .week,
                    frequencyValue: 3,
                    recurrenceKind: .weekly,
                    recurrenceHasExplicitTime: true,
                    recurrenceTimeOfDay: exactTime,
                    recurrenceWeekdays: [3, 5]
                ),
                checklist: AddRoutineChecklistState(
                    routineSteps: [step],
                    routineChecklistItems: [checklistItem]
                )
            )
        ) {
            makeDelegateEchoFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped) {
            $0.isSaving = true
            $0.checklist.routineChecklistItems = RoutineChecklistItem.sanitized(
                [checklistItem],
                for: .softInterval
            )
        }
        await store.receive(
            .delegate(
                .didSave(
                    makeSaveRequest(
                        name: "Analyzed support queue",
                        frequencyInDays: 21,
                        recurrenceRule: .weekly(on: [3, 5], at: exactTime),
                        emoji: "✨",
                        routineDurationMode: .multiDay,
                        plannedDate: date,
                        calendar: makeTestCalendar(),
                        steps: [step],
                        scheduleMode: .softInterval,
                        checklistItems: RoutineChecklistItem.sanitized([checklistItem], for: .softInterval),
                        estimatedDurationMinutes: 120,
                        actualDurationMinutes: 95,
                        cadenceEnabled: true,
                        nudgesEnabled: false
                    ))))
    }

    @Test
    func saveTapped_gentleRoutinePersistsQuietCadenceAndAutoAssume() async {
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Morning check-in",
                    cadenceEnabled: true,
                    nudgesEnabled: false
                ),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .softInterval,
                    frequency: .day,
                    frequencyValue: 1,
                    recurrenceKind: .intervalDays,
                    autoAssumeDailyDone: true
                )
            )
        ) {
            makeDelegateEchoFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(
            .delegate(
                .didSave(
                    makeSaveRequest(
                        name: "Morning check-in",
                        frequencyInDays: 1,
                        recurrenceRule: .interval(days: 1),
                        emoji: "✨",
                        scheduleMode: .softInterval,
                        autoAssumeDailyDone: true,
                        autoAssumeDoneTimeOfDay: RoutineAssumedCompletion.defaultDoneTimeOfDay,
                        cadenceEnabled: true,
                        nudgesEnabled: false
                    ))))
    }

    @Test
    func saveTapped_afterCompletionIntervalPersistsAutoAssume() async {
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Journal"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .fixedInterval,
                    frequency: .day,
                    frequencyValue: 2,
                    recurrenceKind: .intervalDays,
                    autoAssumeDailyDone: true
                )
            )
        ) {
            makeDelegateEchoFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        #expect(store.state.canAutoAssumeDailyDone)
        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(
            .delegate(
                .didSave(
                    makeSaveRequest(
                        name: "Journal",
                        frequencyInDays: 2,
                        recurrenceRule: .interval(days: 2),
                        emoji: "✨",
                        scheduleMode: .fixedInterval,
                        autoAssumeDailyDone: true,
                        autoAssumeDoneTimeOfDay: RoutineAssumedCompletion.defaultDoneTimeOfDay
                    ))))
    }

    @Test
    func saveTapped_oneOffScheduledTimeBlockPersistsAutoAssume() async {
        let scheduledDate = makeDate("2026-05-01T00:00:00Z")
        let timeBlock = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 12, minute: 0),
            end: RoutineTimeOfDay(hour: 15, minute: 0)
        )
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Museum visit",
                    availabilityStartDate: scheduledDate
                ),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .oneOff,
                    recurrenceHasTimeRange: true,
                    recurrenceTimeRangeRole: .scheduledBlock,
                    recurrenceTimeRangeStart: timeBlock.start,
                    recurrenceTimeRangeEnd: timeBlock.end,
                    autoAssumeDailyDone: true
                )
            )
        ) {
            makeDelegateEchoFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        #expect(store.state.canAutoAssumeDailyDone)
        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(
            .delegate(
                .didSave(
                    makeSaveRequest(
                        name: "Museum visit",
                        frequencyInDays: 1,
                        recurrenceRule: .interval(days: 1, timeRange: timeBlock),
                        emoji: "✨",
                        availabilityStartDate: scheduledDate,
                        calendar: makeTestCalendar(),
                        scheduleMode: .oneOff,
                        recurrenceTimeRangeRole: .scheduledBlock,
                        autoAssumeDailyDone: true,
                        autoAssumeDoneTimeOfDay: RoutineAssumedCompletion.defaultDoneTimeOfDay
                    ))))
    }

    @Test
    func saveTapped_cadenceFreeRoutineUsesNeutralRecurrenceDefaults() async {
        let plannedDate = makeDate("2026-05-01T09:00:00Z")
        let exactTime = RoutineTimeOfDay(hour: 14, minute: 30)
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Ad hoc symptom log",
                    plannedDate: plannedDate,
                    cadenceEnabled: false
                ),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .softInterval,
                    frequency: .week,
                    frequencyValue: 3,
                    recurrenceKind: .weekly,
                    recurrenceHasExplicitTime: true,
                    recurrenceTimeOfDay: exactTime,
                    recurrenceWeekdays: [3, 5]
                )
            )
        ) {
            makeDelegateEchoFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(
            .delegate(
                .didSave(
                    makeSaveRequest(
                        name: "Ad hoc symptom log",
                        frequencyInDays: 1,
                        recurrenceRule: .interval(days: 1),
                        emoji: "✨",
                        plannedDate: plannedDate,
                        calendar: makeTestCalendar(),
                        scheduleMode: .softInterval,
                        cadenceEnabled: false,
                        nudgesEnabled: false
                    ))))
    }

    @Test
    func saveTapped_gentleChecklistRoutineKeepsChecklistCompletion() async {
        let checklistItem = RoutineChecklistItem(title: "Capture outcome", intervalDays: 5)
        let exactTime = RoutineTimeOfDay(hour: 15, minute: 0)
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Retrospective notes",
                    cadenceEnabled: true
                ),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .softIntervalChecklist,
                    frequency: .month,
                    frequencyValue: 2,
                    recurrenceKind: .monthlyDay,
                    recurrenceHasExplicitTime: true,
                    recurrenceTimeOfDay: exactTime,
                    recurrenceDaysOfMonth: [5, 20]
                ),
                checklist: AddRoutineChecklistState(
                    routineChecklistItems: [checklistItem]
                )
            )
        ) {
            makeDelegateEchoFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped) {
            $0.isSaving = true
            $0.checklist.routineChecklistItems = RoutineChecklistItem.sanitized(
                [checklistItem],
                for: .softIntervalChecklist
            )
        }
        await store.receive(
            .delegate(
                .didSave(
                    makeSaveRequest(
                        name: "Retrospective notes",
                        frequencyInDays: 60,
                        recurrenceRule: .monthly(on: [5, 20], at: exactTime),
                        emoji: "✨",
                        scheduleMode: .softIntervalChecklist,
                        checklistItems: RoutineChecklistItem.sanitized([checklistItem], for: .softIntervalChecklist),
                        cadenceEnabled: true
                    ))))
    }

    @Test
    func availablePlacesChanged_clearsSelectedPlaceWhenPlaceDisappears() async {
        let keptPlaceID = UUID()
        let removedPlaceID = UUID()
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(selectedPlaceID: removedPlaceID),
                organization: AddRoutineOrganizationState(
                    existingRoutineNames: [],
                    availablePlaces: [
                        RoutinePlaceSummary(id: keptPlaceID, name: "Office", radiusMeters: 150, linkedRoutineCount: 0),
                        RoutinePlaceSummary(id: removedPlaceID, name: "Home", radiusMeters: 150, linkedRoutineCount: 1),
                    ]
                )
            )
        ) {
            makeFeature()
        }

        await store.send(
            .availablePlacesChanged([
                RoutinePlaceSummary(id: keptPlaceID, name: "Office", radiusMeters: 150, linkedRoutineCount: 0)
            ])
        ) {
            $0.organization.availablePlaces = [
                RoutinePlaceSummary(id: keptPlaceID, name: "Office", radiusMeters: 150, linkedRoutineCount: 0)
            ]
            $0.basics.selectedPlaceID = nil
        }
    }

    @Test
    func routineNameChanged_setsDuplicateValidationMessage() async {
        let store = TestStore(
            initialState: makeState(
                organization: AddRoutineOrganizationState(existingRoutineNames: ["Read"])
            )
        ) {
            makeFeature()
        }

        await store.send(.routineNameChanged("  read  ")) {
            $0.basics.routineName = "  read  "
            $0.organization.nameValidationMessage = "A task with this name already exists."
        }
    }

    @Test
    func applyQuickAddDraftFromName_populatesFormFields() async {
        let placesKey = UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue
        let previousPlacesValue = SharedDefaults.app.object(forKey: placesKey)
        defer {
            if let previousPlacesValue {
                SharedDefaults.app.set(previousPlacesValue, forKey: placesKey)
            } else {
                SharedDefaults.app.removeObject(forKey: placesKey)
            }
        }
        SharedDefaults.app[.appSettingPlacesEnabled] = true

        let placeID = UUID()
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Water plants every Saturday at 9 #home @Balcony !high 25m"),
                organization: AddRoutineOrganizationState(
                    availablePlaces: [
                        RoutinePlaceSummary(
                            id: placeID,
                            name: "Balcony",
                            radiusMeters: 80,
                            linkedRoutineCount: 0
                        )
                    ]
                )
            )
        ) {
            makeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: makeDate("2026-04-23T10:00:00Z"))
        }

        await store.send(.applyQuickAddDraftFromName) {
            $0.basics.routineName = "Water plants"
            $0.basics.priority = .high
            $0.basics.importance = .level3
            $0.basics.urgency = .level3
            $0.basics.selectedPlaceID = placeID
            $0.basics.selectedPlaceIDs = [placeID]
            $0.basics.estimatedDurationMinutes = 25
            $0.basics.focusModeEnabled = true
            $0.organization.routineTags = ["home"]
            $0.schedule.scheduleMode = .fixedInterval
            $0.schedule.frequency = .week
            $0.schedule.frequencyValue = 1
            $0.schedule.recurrenceKind = .weekly
            $0.schedule.recurrenceHasExplicitTime = true
            $0.schedule.recurrenceWeekday = 7
            $0.schedule.recurrenceWeekdays = [7]
            $0.schedule.recurrenceTimeOfDay = RoutineTimeOfDay(hour: 9, minute: 0)
        }
    }

    @Test
    func applyQuickAddDraftFromName_deduplicatesTagsIgnoringCase() async {
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Water plants #home"),
                organization: AddRoutineOrganizationState(
                    routineTags: ["Home"],
                    availableTags: ["Home"]
                )
            )
        ) {
            makeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: makeDate("2026-04-23T10:00:00Z"))
        }

        await store.send(.applyQuickAddDraftFromName) {
            $0.basics.routineName = "Water plants"
            $0.organization.routineTags = ["Home"]
        }
    }

    @Test
    func applyQuickAddDraftFromLink_populatesEditableTitleAndLink() async {
        let rawURL = "https://www.youtube.com/watch?v=abc123"
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: rawURL)
            )
        ) {
            makeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: makeDate("2026-08-20T10:00:00Z"))
        }

        await store.send(.applyQuickAddDraftFromName) {
            $0.basics.routineName = "Watch YouTube video"
            $0.basics.routineLink = rawURL
        }
    }

    @Test
    func saveTapped_appliesQuickAddDraftFromNameBeforeDelegating() async {
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Pay rent tomorrow at 8pm #finance")
            )
        ) {
            makeDelegateEchoFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: makeDate("2026-04-23T10:00:00Z"))
        }

        let calendar = makeTestCalendar()
        let expectedAvailability = calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: 2026,
                month: 4,
                day: 24
            ))

        await store.send(.saveTapped) {
            $0.isSaving = true
            $0.basics.routineName = "Pay rent"
            $0.basics.availabilityStartDate = expectedAvailability
            $0.basics.plannedDate = expectedAvailability
            $0.organization.routineTags = ["finance"]
            $0.schedule.recurrenceHasExplicitTime = true
            $0.schedule.recurrenceTimeOfDay = RoutineTimeOfDay(hour: 20, minute: 0)
        }
        await store.receive(
            .delegate(
                .didSave(
                    makeSaveRequest(
                        name: "Pay rent",
                        frequencyInDays: 1,
                        recurrenceRule: .interval(days: 1, at: RoutineTimeOfDay(hour: 20, minute: 0)),
                        emoji: "✨",
                        availabilityStartDate: expectedAvailability,
                        plannedDate: expectedAvailability,
                        calendar: calendar,
                        tags: ["finance"],
                        scheduleMode: .oneOff
                    ))))
    }

    @Test
    func existingRoutineNamesChanged_clearsValidationWhenDuplicateDisappears() async {
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Read"),
                organization: AddRoutineOrganizationState(
                    existingRoutineNames: ["Read"],
                    nameValidationMessage: "A task with this name already exists."
                )
            )
        ) {
            makeFeature()
        }

        await store.send(.existingRoutineNamesChanged(["Walk"])) {
            $0.organization.existingRoutineNames = ["Walk"]
            $0.organization.nameValidationMessage = nil
        }
    }

    @Test
    func saveTapped_doesNothingWhenDuplicateNameExists() async {
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Read", routineEmoji: "📚"),
                organization: AddRoutineOrganizationState(
                    existingRoutineNames: ["read"],
                    nameValidationMessage: "A task with this name already exists."
                )
            )
        ) {
            AddRoutineFeature(
                onSave: { _ in
                    Issue.record("Save effect should not run for duplicate routine names")
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped)
    }

    @Test
    func taskTypeChanged_togglesBetweenRoutineAndTodoModes() async {
        let reminderAt = makeDate("2026-04-25T14:30:00Z")
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(reminderAt: reminderAt),
                schedule: AddRoutineScheduleState(scheduleMode: .fixedIntervalChecklist)
            )
        ) {
            makeFeature()
        }

        await store.send(.taskTypeChanged(.todo)) {
            $0.schedule.scheduleMode = .oneOff
        }

        await store.send(.taskTypeChanged(.routine)) {
            $0.schedule.scheduleMode = .fixedInterval
            $0.basics.reminderAt = nil
        }
    }

    @Test
    func saveTapped_trimsNameBeforeDelegating() async {
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "  Read  ", routineEmoji: "📚"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(scheduleMode: .fixedInterval, frequencyValue: 5)
            )
        ) {
            makeFeature(
                onSave: { request in
                    .send(.delegate(.didSave(request)))
                }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(
            .delegate(
                .didSave(
                    makeSaveRequest(
                        name: "Read",
                        frequencyInDays: 5,
                        recurrenceRule: .interval(days: 5),
                        emoji: "📚"
                    ))))
    }

    @Test
    func saveTapped_forTodoUsesOneOffModeAndKeepsSteps() async {
        let capturedFrequencyInDays = LockIsolated<Int?>(nil)
        let capturedRecurrenceRules = LockIsolated<[RoutineRecurrenceRule]>([])
        let capturedScheduleModes = LockIsolated<[RoutineScheduleMode]>([])
        let capturedStepTitles = LockIsolated<[String]>([])
        let capturedChecklistTitles = LockIsolated<[String]>([])

        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Buy milk", routineEmoji: "🥛"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(scheduleMode: .oneOff, frequency: .month, frequencyValue: 2),
                checklist: AddRoutineChecklistState(
                    routineSteps: [RoutineStep(title: "Open the fridge")],
                    stepDraft: "Add it to the cart"
                )
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    capturedFrequencyInDays.withValue { $0 = request.frequencyInDays }
                    capturedRecurrenceRules.withValue { $0 = [request.recurrenceRule] }
                    capturedScheduleModes.withValue { $0 = [request.scheduleMode] }
                    capturedStepTitles.withValue { $0 = request.steps.map(\.title) }
                    capturedChecklistTitles.withValue { $0 = request.checklistItems.map(\.title) }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        _ = await store.withExhaustivity(.off) {
            await store.send(.saveTapped) {
                $0.isSaving = true
                $0.checklist.stepDraft = ""
            }
        }

        #expect(capturedFrequencyInDays.value == 1)
        #expect(capturedRecurrenceRules.value == [.interval(days: 1)])
        #expect(capturedScheduleModes.value == [.oneOff])
        #expect(capturedStepTitles.value == ["Open the fridge", "Add it to the cart"])
        #expect(capturedChecklistTitles.value.isEmpty)
        #expect(store.state.checklist.routineSteps.map(\.title) == ["Open the fridge", "Add it to the cart"])
    }

    @Test
    func saveTapped_forSoftChecklistPreservesChecklistItemsAndUsesSoftSchedule() async {
        let capturedRequest = LockIsolated<AddRoutineSaveRequest?>(nil)
        let checklistItems = [
            RoutineChecklistItem(title: "Whites", intervalDays: 3),
            RoutineChecklistItem(title: "Colors", intervalDays: 5),
        ]
        let exactTime = RoutineTimeOfDay(hour: 18, minute: 30)

        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Laundry", routineEmoji: "🧺"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .softIntervalChecklist,
                    frequency: .day,
                    frequencyValue: 4,
                    recurrenceHasExplicitTime: true,
                    recurrenceTimeOfDay: exactTime
                ),
                checklist: AddRoutineChecklistState(
                    routineSteps: [RoutineStep(title: "Sort clothes")],
                    routineChecklistItems: checklistItems
                )
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    capturedRequest.withValue { $0 = request }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped) {
            $0.isSaving = true
            $0.checklist.routineChecklistItems[0].intervalDays = 1
            $0.checklist.routineChecklistItems[1].intervalDays = 1
        }

        #expect(capturedRequest.value?.scheduleMode == .softIntervalChecklist)
        #expect(capturedRequest.value?.recurrenceRule == .interval(days: 4, at: exactTime))
        #expect(capturedRequest.value?.steps.isEmpty == true)
        #expect(capturedRequest.value?.checklistItems.map(\.title) == ["Whites", "Colors"])
        #expect(capturedRequest.value?.checklistItems.map(\.intervalDays) == [1, 1])
    }

    @Test
    func saveTapped_forGentleCalendarPreservesWeeklyRepeat() async {
        let capturedRequest = LockIsolated<AddRoutineSaveRequest?>(nil)
        let exactTime = RoutineTimeOfDay(hour: 18, minute: 30)

        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Review plants", routineEmoji: "🪴"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .softInterval,
                    recurrenceKind: .weekly,
                    recurrenceHasExplicitTime: true,
                    recurrenceTimeOfDay: exactTime,
                    recurrenceWeekday: 2
                )
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    capturedRequest.withValue { $0 = request }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped) { $0.isSaving = true }

        #expect(capturedRequest.value?.scheduleMode == .softInterval)
        #expect(capturedRequest.value?.recurrenceRule == .weekly(on: 2, at: exactTime))
    }

    @Test
    func addTagTapped_parsesMultipleTagsAndDeduplicates() async {
        let store = TestStore(initialState: makeState()) {
            makeFeature()
        }

        await store.send(.tagDraftChanged(" Health, focus ,health ")) {
            $0.organization.tagDraft = " Health, focus ,health "
        }

        await store.send(.addTagTapped) {
            $0.organization.routineTags = ["Health", "focus"]
            $0.organization.tagDraft = ""
        }
    }

    @Test
    func availableTagsChanged_deduplicatesAndSortsChoices() async {
        let store = TestStore(initialState: makeState()) {
            makeFeature()
        }

        await store.send(.availableTagsChanged([" health ", "Focus", "focus", "Morning"])) {
            $0.organization.availableTags = ["Focus", "health", "Morning"]
            $0.organization.availableTagSummaries = [
                RoutineTagSummary(name: "Focus", linkedRoutineCount: 0),
                RoutineTagSummary(name: "health", linkedRoutineCount: 0),
                RoutineTagSummary(name: "Morning", linkedRoutineCount: 0),
            ]
        }
    }

    @Test
    func availableTagSummariesChanged_preservesCountsAndSortsChoices() async {
        let store = TestStore(initialState: makeState()) {
            makeFeature()
        }

        let summaries = [
            RoutineTagSummary(name: "Morning", linkedRoutineCount: 2),
            RoutineTagSummary(name: "focus", linkedRoutineCount: 5),
            RoutineTagSummary(name: "Health", linkedRoutineCount: 1),
        ]

        await store.send(.availableTagSummariesChanged(summaries)) {
            $0.organization.availableTagSummaries = [
                RoutineTagSummary(name: "focus", linkedRoutineCount: 5),
                RoutineTagSummary(name: "Morning", linkedRoutineCount: 2),
                RoutineTagSummary(name: "Health", linkedRoutineCount: 1),
            ]
            $0.organization.availableTags = ["focus", "Morning", "Health"]
        }
    }

    @Test
    func toggleTagSelection_addsAndRemovesChosenTag() async {
        let store = TestStore(
            initialState: makeState(
                organization: AddRoutineOrganizationState(
                    routineTags: ["Focus"],
                    availableTags: ["Focus", "Morning"]
                )
            )
        ) {
            makeFeature()
        }

        await store.send(.toggleTagSelection("Morning")) {
            $0.organization.routineTags = ["Focus", "Morning"]
        }

        await store.send(.toggleTagSelection("focus")) {
            $0.organization.routineTags = ["Morning"]
        }
    }

    @Test
    func addTagTapped_prefersAvailableTagCase() async {
        let store = TestStore(
            initialState: makeState(
                organization: AddRoutineOrganizationState(
                    availableTags: ["Home"],
                    tagDraft: "home"
                )
            )
        ) {
            makeFeature()
        }

        await store.send(.addTagTapped) {
            $0.organization.routineTags = ["Home"]
            $0.organization.tagDraft = ""
        }
    }

    @Test
    func tagRenamed_doesNotAddReplacementToUnrelatedSelectedTags() async {
        let store = TestStore(
            initialState: makeState(
                organization: AddRoutineOrganizationState(
                    routineTags: ["Morning"],
                    availableTags: ["Focus", "Morning"],
                    availableTagSummaries: [
                        RoutineTagSummary(name: "Focus", linkedRoutineCount: 3),
                        RoutineTagSummary(name: "Morning", linkedRoutineCount: 1),
                    ]
                )
            )
        ) {
            makeFeature()
        }

        await store.send(.tagRenamed(oldName: "focus", newName: "Deep Work")) {
            $0.organization.availableTags = ["Deep Work", "Morning"]
            $0.organization.availableTagSummaries = [
                RoutineTagSummary(name: "Deep Work", linkedRoutineCount: 3),
                RoutineTagSummary(name: "Morning", linkedRoutineCount: 1),
            ]
        }
    }

    @Test
    func tagDeleted_removesTagFromAvailableAndSelectedTags() async {
        let store = TestStore(
            initialState: makeState(
                organization: AddRoutineOrganizationState(
                    routineTags: ["Morning", "Deep Work"],
                    availableTags: ["Deep Work", "Morning"],
                    availableTagSummaries: [
                        RoutineTagSummary(name: "Deep Work", linkedRoutineCount: 4),
                        RoutineTagSummary(name: "Morning", linkedRoutineCount: 2),
                    ]
                )
            )
        ) {
            makeFeature()
        }

        await store.send(.tagDeleted("morning")) {
            $0.organization.routineTags = ["Deep Work"]
            $0.organization.availableTags = ["Deep Work"]
            $0.organization.availableTagSummaries = [
                RoutineTagSummary(name: "Deep Work", linkedRoutineCount: 4)
            ]
        }
    }

    @Test
    func saveTapped_commitsPendingTagsBeforeDelegating() async {
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Read", routineEmoji: "📚"),
                organization: AddRoutineOrganizationState(
                    routineTags: ["Mindset"],
                    tagDraft: "night, focus",
                    existingRoutineNames: []
                ),
                schedule: AddRoutineScheduleState(scheduleMode: .fixedInterval)
            )
        ) {
            makeDelegateEchoFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped) {
            $0.isSaving = true
            $0.organization.routineTags = ["Mindset", "night", "focus"]
            $0.organization.tagDraft = ""
        }
        await store.receive(
            .delegate(
                .didSave(
                    makeSaveRequest(
                        name: "Read",
                        frequencyInDays: 1,
                        recurrenceRule: .interval(days: 1),
                        emoji: "📚",
                        tags: ["Mindset", "night", "focus"]
                    ))))
    }

    @Test
    func recurrenceChangesScheduleDraftAutosaveThroughTheFeature() async throws {
        let scheduledWrites = LockIsolated<[CreationDraftScheduledWrite]>([])
        var creationDraftClient = CreationDraftClient.noop
        creationDraftClient.scheduleSave = { kind, makeWrite in
            guard kind == .task else { return }
            scheduledWrites.withValue { $0.append(makeWrite()) }
        }
        let store = TestStore(
            initialState: makeState(
                schedule: AddRoutineScheduleState(scheduleMode: .fixedInterval)
            )
        ) {
            makeFeature()
        } withDependencies: {
            $0.creationDraftClient = creationDraftClient
            setTestDateDependencies(&$0)
        }
        store.exhaustivity = .off

        await store.send(
            .recurrenceDraftChanged(
                RoutineRecurrenceDraft(
                    cadence: .scheduled,
                    frequency: .weekly,
                    weekdays: [2, 5]
                )
            )
        )

        let write = try #require(scheduledWrites.value.last)
        guard case let .save(rawValue) = write else {
            Issue.record("Expected the changed recurrence to schedule a saved task draft.")
            return
        }
        let data = try #require(rawValue.data(using: .utf8))
        let snapshot = try JSONDecoder().decode(AddRoutineDraftSnapshot.self, from: data)
        #expect(snapshot.scheduleMode == .fixedInterval)
        #expect(snapshot.recurrenceKind == .weekly)
        #expect(snapshot.recurrenceWeekdays == [2, 5])
    }

    @Test
    func cancelingAddTaskCancelsPendingDraftAutosave() async {
        let canceledKinds = LockIsolated<[CreationDraftKind]>([])
        var creationDraftClient = CreationDraftClient.noop
        creationDraftClient.cancelScheduledSave = { kind in
            canceledKinds.withValue { $0.append(kind) }
        }
        let store = TestStore(initialState: makeState()) {
            makeFeature()
        } withDependencies: {
            $0.creationDraftClient = creationDraftClient
        }

        await store.send(.cancelTapped)

        #expect(canceledKinds.value == [.task])
    }

    @Test
    func addTaskInteractionWorkStaysOutOfTheSwiftUIRenderPath() throws {
        let addTaskViewPaths = [
            "iOS/Screens/AddRoutine/AddRoutineTCAView.swift",
            "RoutinaMacApp/Screens/AddRoutine/AddRoutineTCAView.swift",
        ]

        for path in addTaskViewPaths {
            let source = try SourceInspectionSupport.readProjectFile(path)
            #expect(!source.contains("AddRoutineDraftSnapshot(state: store.state)"))
            #expect(!source.contains("@Query(sort: \\RoutineEvent.startedAt"))
            #expect(!source.contains("availableEventCandidates"))
            #expect(source.contains("AddRoutineEventCatalogSyncView("))
            #expect(source.contains(".equatable()"))
        }

        let addTaskModelFactorySource = try SourceInspectionSupport.readProjectFile(
            "SharedCore/Screens/Shared/AddRoutineTaskFormModelFactory.swift"
        )
        #expect(
            addTaskModelFactorySource.contains(
                "struct AddRoutineEventCatalogSyncView: View, Equatable"
            )
        )
        #expect(
            addTaskModelFactorySource.contains(
                "let candidates = RoutineEventLinkCandidate.candidates(from: events)"
            )
        )

        let segmentedControlSource = try SourceInspectionSupport.readProjectFile(
            "SharedCore/Views/RoutinaLiquidGlass.swift"
        )
        #expect(
            !segmentedControlSource.contains(
                "withAnimation(.easeInOut(duration: 0.18)) {\n                onSelect(option)"
            )
        )
        #expect(
            segmentedControlSource.contains(
                ".animation(.easeInOut(duration: 0.18), value: selection)"
            )
        )

        let recurrenceEditorSource = try SourceInspectionSupport.readProjectFile(
            "SharedCore/Views/AdvancedRecurrenceEditor.swift"
        )
        #expect(recurrenceEditorSource.contains("static let options: [Option]"))
        #expect(recurrenceEditorSource.contains("List(options)"))
    }

    @Test
    func cancelTapped_sendsCancelDelegate() async {
        let store = TestStore(initialState: makeState()) {
            makeFeature(onCancel: { .send(.delegate(.didCancel)) })
        }

        await store.send(.cancelTapped)
        await store.receive(.delegate(.didCancel))
    }
}
