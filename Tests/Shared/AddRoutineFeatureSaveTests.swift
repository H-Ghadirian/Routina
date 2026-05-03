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

        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Plan trip",
                    routineLink: "example.com/berlin"
                ),
                organization: AddRoutineOrganizationState(existingRoutineNames: [])
            )
        ) {
            AddRoutineFeature(
                onSave: { request in
                    capturedLink.withValue { $0 = request.link }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped)

        #expect(capturedLink.value == "https://example.com/berlin")
    }
}
