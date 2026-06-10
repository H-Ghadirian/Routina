import ComposableArchitecture
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
struct AddRoutineFeatureSaveTests {
    @Test
    func saveTapped_includesVoiceNoteInRequest() async {
        let createdAt = makeDate("2026-03-20T10:00:00Z")
        let voiceNote = RoutineVoiceNote(
            data: Data([0x01, 0x02, 0x03]),
            durationSeconds: 6.5,
            createdAt: createdAt
        )
        let capturedVoiceNote = LockIsolated<RoutineVoiceNote?>(nil)
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Call supplier",
                    voiceNote: voiceNote
                ),
                organization: AddRoutineOrganizationState(existingRoutineNames: [])
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    capturedVoiceNote.withValue { $0 = request.voiceNote }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped)

        #expect(capturedVoiceNote.value == voiceNote)
    }

    @Test
    func makeRoutine_persistsVoiceNoteFromSaveRequest() {
        let createdAt = makeDate("2026-03-20T10:00:00Z")
        let voiceNote = RoutineVoiceNote(
            data: Data([0x04, 0x05]),
            durationSeconds: 4.25,
            createdAt: createdAt
        )
        let request = makeSaveRequest(
            name: "Call supplier",
            frequencyInDays: 1,
            recurrenceRule: .interval(days: 1),
            emoji: "☎️",
            voiceNote: voiceNote
        )

        let task = HomeAddRoutineSupport.makeRoutine(
            from: request,
            name: request.name,
            goalIDs: [],
            scheduleAnchor: createdAt
        )

        #expect(task.voiceNote == voiceNote)
        #expect(task.hasVoiceNote)
    }

    @Test
    func saveTapped_includesLinkedEventIDsInRequest() async {
        let eventID = UUID()
        let capturedEventIDs = LockIsolated<[UUID]>([])
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Prepare notes"),
                organization: AddRoutineOrganizationState(
                    eventIDs: [eventID],
                    existingRoutineNames: []
                )
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    capturedEventIDs.withValue { $0 = request.eventIDs }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped)

        #expect(capturedEventIDs.value == [eventID])
    }

    @Test
    func makeRoutine_persistsLinkedEventIDsFromSaveRequest() {
        let createdAt = makeDate("2026-03-20T10:00:00Z")
        let eventID = UUID()
        let request = makeSaveRequest(
            name: "Prepare notes",
            frequencyInDays: 1,
            recurrenceRule: .interval(days: 1),
            emoji: "📝",
            eventIDs: [eventID]
        )

        let task = HomeAddRoutineSupport.makeRoutine(
            from: request,
            name: request.name,
            goalIDs: [],
            scheduleAnchor: createdAt
        )

        #expect(task.eventIDs == [eventID])
    }

    @Test
    func saveTapped_includesAllDayFlagForDatedTodos() async {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let deadline = makeDate("2026-03-22T16:45:00Z")
        let capturedRequest = LockIsolated<AddRoutineSaveRequest?>(nil)
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Conference",
                    deadline: deadline,
                    isAllDay: true
                ),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(scheduleMode: .oneOff)
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
            setTestDateDependencies(&$0, now: now, calendar: calendar)
        }

        await store.send(.deadlineDateChanged(deadline)) {
            $0.basics.deadline = calendar.startOfDay(for: deadline)
        }
        await store.send(.saveTapped)

        #expect(capturedRequest.value?.deadline == calendar.startOfDay(for: deadline))
        #expect(capturedRequest.value?.isAllDay == true)
    }

    @Test
    func saveTapped_includesExactAvailabilityForTodosWithoutDeadline() async {
        let exactTime = RoutineTimeOfDay(hour: 20, minute: 0)
        let capturedRequest = LockIsolated<AddRoutineSaveRequest?>(nil)
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Call landlord"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .oneOff,
                    recurrenceHasExplicitTime: true,
                    recurrenceTimeOfDay: exactTime
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

        await store.send(.saveTapped)

        #expect(capturedRequest.value?.scheduleMode == .oneOff)
        #expect(capturedRequest.value?.deadline == nil)
        #expect(capturedRequest.value?.recurrenceRule == .interval(days: 1, at: exactTime))
    }

    @Test
    func saveTapped_includesRoutineDurationIndependentOfAllDay() async {
        let capturedRequest = LockIsolated<AddRoutineSaveRequest?>(nil)
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Studio day",
                    isAllDay: false,
                    routineDurationMode: .multiDay
                ),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(scheduleMode: .fixedInterval)
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

        await store.send(.saveTapped)

        #expect(capturedRequest.value?.scheduleMode == .fixedInterval)
        #expect(capturedRequest.value?.deadline == nil)
        #expect(capturedRequest.value?.isAllDay == false)
        #expect(capturedRequest.value?.routineDurationMode == .multiDay)
    }

    @Test
    func saveTapped_resetsRoutineDurationForTodos() async {
        let capturedRequest = LockIsolated<AddRoutineSaveRequest?>(nil)
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Conference",
                    isAllDay: true,
                    routineDurationMode: .multiDay
                ),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(scheduleMode: .oneOff)
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

        await store.send(.saveTapped)

        #expect(capturedRequest.value?.scheduleMode == .oneOff)
        #expect(capturedRequest.value?.isAllDay == true)
        #expect(capturedRequest.value?.routineDurationMode == .oneDay)
    }

    @Test
    func saveTapped_omitsExactDateReminderForRoutines() async {
        let reminderAt = makeDate("2026-04-25T14:30:00Z")
        let capturedRequest = LockIsolated<AddRoutineSaveRequest?>(nil)
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Water plants",
                    reminderAt: reminderAt
                ),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(scheduleMode: .fixedInterval)
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

        await store.send(.saveTapped)

        #expect(capturedRequest.value?.scheduleMode == .fixedInterval)
        #expect(capturedRequest.value?.reminderAt == nil)
    }

    @Test
    func makeRoutine_persistsAllDayFlagFromSaveRequest() {
        let deadline = makeDate("2026-03-22T00:00:00Z")
        let request = makeSaveRequest(
            name: "Conference",
            frequencyInDays: 1,
            recurrenceRule: .interval(days: 1),
            emoji: "🎟️",
            deadline: deadline,
            isAllDay: true,
            scheduleMode: .oneOff
        )

        let task = HomeAddRoutineSupport.makeRoutine(
            from: request,
            name: request.name,
            goalIDs: [],
            scheduleAnchor: deadline
        )

        #expect(task.deadline == deadline)
        #expect(task.isAllDay)
    }

    @Test
    func makeRoutine_persistsWindowAvailabilityFromTodoSaveRequest() {
        let window = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 10, minute: 0)
        )
        let request = makeSaveRequest(
            name: "Call landlord",
            frequencyInDays: 1,
            recurrenceRule: .interval(days: 1, timeRange: window),
            emoji: "📞",
            scheduleMode: .oneOff
        )

        let task = HomeAddRoutineSupport.makeRoutine(
            from: request,
            name: request.name,
            goalIDs: [],
            scheduleAnchor: makeDate("2026-03-22T00:00:00Z")
        )

        #expect(task.scheduleMode == .oneOff)
        #expect(task.recurrenceRule == .interval(days: 1, timeRange: window))
        #expect(task.interval == 1)
    }

    @Test
    func makeRoutine_persistsAllDayFlagFromRoutineSaveRequest() {
        let anchor = makeDate("2026-03-22T00:00:00Z")
        let request = makeSaveRequest(
            name: "Studio day",
            frequencyInDays: 1,
            recurrenceRule: .interval(days: 1),
            emoji: "🎨",
            isAllDay: true,
            routineDurationMode: .multiDay,
            scheduleMode: .fixedInterval
        )

        let task = HomeAddRoutineSupport.makeRoutine(
            from: request,
            name: request.name,
            goalIDs: [],
            scheduleAnchor: anchor
        )

        #expect(task.scheduleMode == .fixedInterval)
        #expect(task.deadline == nil)
        #expect(task.isAllDay)
        #expect(task.routineDurationMode == .multiDay)
    }

    @Test
    func saveTapped_commitsPendingStepsBeforeDelegating() async {
        let washID = UUID()
        let capturedNames = LockIsolated<[String]>([])
        let capturedStepTitles = LockIsolated<[String]>([])
        let capturedSteps = LockIsolated<[RoutineStep]>([])
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Laundry"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                checklist: AddRoutineChecklistState(
                    routineSteps: [RoutineStep(id: washID, title: "Wash clothes")],
                    stepDraft: "Hang on the line"
                )
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    capturedNames.withValue {
                        $0 = [request.name, "\(request.frequencyInDays)", request.emoji] + request.tags
                    }
                    #expect(request.selectedPlaceID == nil)
                    capturedSteps.withValue { $0 = request.steps }
                    capturedStepTitles.withValue { $0 = request.steps.map(\.title) }
                    #expect(request.checklistItems.isEmpty)
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped) {
            $0.checklist.routineSteps = capturedSteps.value
            $0.checklist.stepDraft = ""
        }
        #expect(capturedNames.value == ["Laundry", "1", "✨"])
        #expect(capturedStepTitles.value == ["Wash clothes", "Hang on the line"])
    }

    @Test
    func saveTapped_standardTaskSendsChecklistItems() async {
        let capturedChecklistTitles = LockIsolated<[String]>([])
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Plan workshop"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(scheduleMode: .fixedInterval),
                checklist: AddRoutineChecklistState(
                    routineChecklistItems: [RoutineChecklistItem(title: "Book room", intervalDays: 1)],
                    checklistItemDraftTitle: "Send invite"
                )
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    #expect(request.scheduleMode == .fixedInterval)
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
                $0.checklist.checklistItemDraftTitle = ""
            }
        }

        #expect(capturedChecklistTitles.value == ["Book room", "Send invite"])
    }

    @Test
    func saveTapped_todoSendsChecklistItems() async {
        let capturedChecklistTitles = LockIsolated<[String]>([])
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Buy ingredients"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(scheduleMode: .oneOff),
                checklist: AddRoutineChecklistState(
                    routineChecklistItems: [RoutineChecklistItem(title: "Flour", intervalDays: 1)],
                    checklistItemDraftTitle: "Yeast"
                )
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    #expect(request.scheduleMode == .oneOff)
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
                $0.checklist.checklistItemDraftTitle = ""
            }
        }

        #expect(capturedChecklistTitles.value == ["Flour", "Yeast"])
    }

    @Test
    func saveTapped_inChecklistMode_sendsChecklistItemsAndMode() async {
        let now = makeDate("2026-03-20T10:00:00Z")
        let capturedChecklistTitles = LockIsolated<[String]>([])
        let capturedScheduleModes = LockIsolated<[RoutineScheduleMode]>([])
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Do groceries"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(scheduleMode: .derivedFromChecklist),
                checklist: AddRoutineChecklistState(
                    routineChecklistItems: [RoutineChecklistItem(title: "Bread", intervalDays: 3, createdAt: now)],
                    checklistItemDraftTitle: "Milk",
                    checklistItemDraftInterval: 5
                )
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    #expect(request.steps.isEmpty)
                    capturedScheduleModes.withValue { $0 = [request.scheduleMode] }
                    capturedChecklistTitles.withValue { $0 = request.checklistItems.map(\.title) }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0, now: now)
            $0.date.now = now
        }

        _ = await store.withExhaustivity(.off) {
            await store.send(.saveTapped) {
                $0.checklist.checklistItemDraftTitle = ""
                $0.checklist.checklistItemDraftInterval = 3
            }
        }

        #expect(capturedScheduleModes.value == [.derivedFromChecklist])
        #expect(capturedChecklistTitles.value == ["Bread", "Milk"])
        #expect(store.state.checklist.routineChecklistItems.map(\.title) == ["Bread", "Milk"])
        #expect(store.state.checklist.routineChecklistItems.map(\.intervalDays) == [3, 5])
        #expect(store.state.checklist.routineChecklistItems.allSatisfy { $0.createdAt == now })
    }

    @Test
    func saveTapped_inCompletionChecklistMode_sendsChecklistItemsAndMode() async {
        let now = makeDate("2026-03-20T10:00:00Z")
        let capturedChecklistTitles = LockIsolated<[String]>([])
        let capturedScheduleModes = LockIsolated<[RoutineScheduleMode]>([])
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Pack gym bag"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(scheduleMode: .fixedIntervalChecklist),
                checklist: AddRoutineChecklistState(
                    routineChecklistItems: [RoutineChecklistItem(title: "Shoes", intervalDays: 3, createdAt: now)],
                    checklistItemDraftTitle: "Towel"
                )
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    #expect(request.steps.isEmpty)
                    capturedScheduleModes.withValue { $0 = [request.scheduleMode] }
                    capturedChecklistTitles.withValue { $0 = request.checklistItems.map(\.title) }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0, now: now)
            $0.date.now = now
        }

        _ = await store.withExhaustivity(.off) {
            await store.send(.saveTapped) {
                $0.checklist.checklistItemDraftTitle = ""
                $0.checklist.checklistItemDraftInterval = 3
            }
        }

        #expect(capturedScheduleModes.value == [.fixedIntervalChecklist])
        #expect(capturedChecklistTitles.value == ["Shoes", "Towel"])
    }

    @Test
    func saveTapped_dailyTimeSchedule_sendsDailyRecurrenceRule() async {
        let capturedRecurrenceRules = LockIsolated<[RoutineRecurrenceRule]>([])
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Stretch"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .fixedInterval,
                    recurrenceKind: .dailyTime,
                    recurrenceHasExplicitTime: true,
                    recurrenceTimeOfDay: RoutineTimeOfDay(hour: 21, minute: 15)
                )
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    capturedRecurrenceRules.withValue { $0 = [request.recurrenceRule] }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped)

        #expect(capturedRecurrenceRules.value == [.daily(at: RoutineTimeOfDay(hour: 21, minute: 15))])
    }

    @Test
    func saveTapped_dailyTimeSchedule_withTimeRange_sendsDailyRangeRecurrenceRule() async {
        let capturedRecurrenceRules = LockIsolated<[RoutineRecurrenceRule]>([])
        let timeRange = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 10, minute: 0)
        )
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Breakfast"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .fixedInterval,
                    recurrenceKind: .dailyTime,
                    recurrenceHasExplicitTime: false,
                    recurrenceHasTimeRange: true,
                    recurrenceTimeRangeStart: timeRange.start,
                    recurrenceTimeRangeEnd: timeRange.end
                )
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    capturedRecurrenceRules.withValue { $0 = [request.recurrenceRule] }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped)

        #expect(capturedRecurrenceRules.value == [.daily(in: timeRange)])
    }

    @Test
    func saveTapped_intervalSchedule_withAvailability_sendsTimedIntervalRecurrenceRule() async {
        let capturedRecurrenceRules = LockIsolated<[RoutineRecurrenceRule]>([])
        let exactTime = RoutineTimeOfDay(hour: 20, minute: 0)
        let timeRange = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 10, minute: 0)
        )
        let exactStore = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Water plants"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .fixedInterval,
                    frequency: .week,
                    frequencyValue: 1,
                    recurrenceKind: .intervalDays,
                    recurrenceHasExplicitTime: true,
                    recurrenceTimeOfDay: exactTime
                )
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    capturedRecurrenceRules.withValue { $0.append(request.recurrenceRule) }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }
        let rangeStore = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Buy bread"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .fixedInterval,
                    frequency: .day,
                    frequencyValue: 3,
                    recurrenceKind: .intervalDays,
                    recurrenceHasExplicitTime: false,
                    recurrenceHasTimeRange: true,
                    recurrenceTimeRangeStart: timeRange.start,
                    recurrenceTimeRangeEnd: timeRange.end
                )
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    capturedRecurrenceRules.withValue { $0.append(request.recurrenceRule) }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await exactStore.send(.saveTapped)
        await rangeStore.send(.saveTapped)

        #expect(capturedRecurrenceRules.value == [
            .interval(days: 7, at: exactTime),
            .interval(days: 3, timeRange: timeRange)
        ])
    }

    @Test
    func saveTapped_allDayIntervalSchedule_ignoresStaleAvailabilityTiming() async {
        let capturedRecurrenceRules = LockIsolated<[RoutineRecurrenceRule]>([])
        let capturedAllDayFlags = LockIsolated<[Bool]>([])
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Water plants",
                    isAllDay: true
                ),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .fixedInterval,
                    frequency: .week,
                    frequencyValue: 1,
                    recurrenceKind: .intervalDays,
                    recurrenceHasExplicitTime: true,
                    recurrenceHasTimeRange: true,
                    recurrenceTimeOfDay: RoutineTimeOfDay(hour: 20, minute: 0),
                    recurrenceTimeRangeStart: RoutineTimeOfDay(hour: 19, minute: 0),
                    recurrenceTimeRangeEnd: RoutineTimeOfDay(hour: 21, minute: 0)
                )
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    capturedRecurrenceRules.withValue { $0 = [request.recurrenceRule] }
                    capturedAllDayFlags.withValue { $0 = [request.isAllDay] }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped)

        #expect(capturedRecurrenceRules.value == [.interval(days: 7)])
        #expect(capturedAllDayFlags.value == [true])
    }

    @Test
    func saveTapped_weeklyAndMonthlySchedules_sendCalendarRecurrenceRules() async {
        let capturedRecurrenceRules = LockIsolated<[RoutineRecurrenceRule]>([])
        let weeklyStore = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Review Week"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .fixedInterval,
                    recurrenceKind: .weekly,
                    recurrenceWeekday: 6
                )
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    capturedRecurrenceRules.withValue { $0.append(request.recurrenceRule) }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        let monthlyStore = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Pay Bills"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .fixedInterval,
                    recurrenceKind: .monthlyDay,
                    recurrenceDayOfMonth: 21
                )
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    capturedRecurrenceRules.withValue { $0.append(request.recurrenceRule) }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await weeklyStore.send(.saveTapped)
        await monthlyStore.send(.saveTapped)

        #expect(capturedRecurrenceRules.value == [.weekly(on: 6), .monthly(on: 21)])
    }

    @Test
    func saveTapped_weeklyAndMonthlySchedules_withExactTime_sendTimedCalendarRecurrenceRules() async {
        let capturedRecurrenceRules = LockIsolated<[RoutineRecurrenceRule]>([])
        let exactTime = RoutineTimeOfDay(hour: 18, minute: 45)

        let weeklyStore = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Review Week"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .fixedInterval,
                    recurrenceKind: .weekly,
                    recurrenceHasExplicitTime: true,
                    recurrenceTimeOfDay: exactTime,
                    recurrenceWeekday: 6
                )
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    capturedRecurrenceRules.withValue { $0.append(request.recurrenceRule) }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        let monthlyStore = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(routineName: "Pay Bills"),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(
                    scheduleMode: .fixedInterval,
                    recurrenceKind: .monthlyDay,
                    recurrenceHasExplicitTime: true,
                    recurrenceTimeOfDay: exactTime,
                    recurrenceDayOfMonth: 21
                )
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    capturedRecurrenceRules.withValue { $0.append(request.recurrenceRule) }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await weeklyStore.send(.saveTapped)
        await monthlyStore.send(.saveTapped)

        #expect(
            capturedRecurrenceRules.value == [
                .weekly(on: 6, at: exactTime),
                .monthly(on: 21, at: exactTime)
            ]
        )
    }

    @Test
    func saveTapped_forTodoIncludesNotesAndDeadline() async {
        let deadline = makeDate("2026-03-21T09:00:00Z")
        let capturedNotes = LockIsolated<String?>(nil)
        let capturedDeadline = LockIsolated<Date?>(nil)

        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Buy milk",
                    routineNotes: "  get lactose free  ",
                    deadline: deadline
                ),
                organization: AddRoutineOrganizationState(existingRoutineNames: []),
                schedule: AddRoutineScheduleState(scheduleMode: .oneOff)
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    capturedNotes.withValue { $0 = request.notes }
                    capturedDeadline.withValue { $0 = request.deadline }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped)

        #expect(capturedNotes.value == "get lactose free")
        #expect(capturedDeadline.value == deadline)
    }

    @Test
    func saveTapped_normalizesLinkBeforeDelegating() async {
        let capturedLink = LockIsolated<String?>(nil)
        let capturedLinks = LockIsolated<[String]>([])

        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Plan trip",
                    routineLink: "example.com/berlin\nhttps://example.com/hotel"
                ),
                organization: AddRoutineOrganizationState(existingRoutineNames: [])
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    capturedLink.withValue { $0 = request.link }
                    capturedLinks.withValue { $0 = request.links }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped)

        #expect(capturedLink.value == "https://example.com/berlin")
        #expect(capturedLinks.value == ["https://example.com/berlin", "https://example.com/hotel"])
    }
}
