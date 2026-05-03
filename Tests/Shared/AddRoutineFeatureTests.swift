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
        #expect(RoutineRecurrenceRule.Kind.dailyTime.pickerTitle == "Time")
        #expect(RoutineRecurrenceRule.Kind.weekly.pickerTitle == "Week")
        #expect(RoutineRecurrenceRule.Kind.monthlyDay.pickerTitle == "Month")
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
    func availableRelationshipTasksChanged_prunesMissingRelationships() async {
        let keptID = UUID()
        let removedID = UUID()
        let store = TestStore(
            initialState: makeState(
                organization: AddRoutineOrganizationState(
                    relationships: [
                    RoutineTaskRelationship(targetTaskID: keptID, kind: .related),
                    RoutineTaskRelationship(targetTaskID: removedID, kind: .blocks)
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
    func availableTagSummariesChanged_sortsByCombinedCounterDescending() async {
        let store = TestStore(initialState: makeState()) {
            makeFeature()
        }

        let summaries = [
            RoutineTagSummary(name: "Calm", linkedRoutineCount: 1, doneCount: 1),
            RoutineTagSummary(name: "Focus", linkedRoutineCount: 2, doneCount: 7),
            RoutineTagSummary(name: "Health", linkedRoutineCount: 4, doneCount: 4),
            RoutineTagSummary(name: "Brain", linkedRoutineCount: 3, doneCount: 5)
        ]

        await store.send(.availableTagSummariesChanged(summaries)) {
            $0.organization.availableTagSummaries = [
                RoutineTagSummary(name: "Focus", linkedRoutineCount: 2, doneCount: 7),
                RoutineTagSummary(name: "Brain", linkedRoutineCount: 3, doneCount: 5),
                RoutineTagSummary(name: "Health", linkedRoutineCount: 4, doneCount: 4),
                RoutineTagSummary(name: "Calm", linkedRoutineCount: 1, doneCount: 1)
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
                    doneHeavyTask.id: 3
                ]
            ),
            tagCounterDisplayMode: .combinedTotal,
            relatedTagRules: []
        )

        #expect(state.organization.availableTags == ["Focus", "Finance", "Admin", "Health"])
        #expect(state.organization.availableTagSummaries == [
            RoutineTagSummary(name: "Focus", linkedRoutineCount: 1, doneCount: 7),
            RoutineTagSummary(name: "Finance", linkedRoutineCount: 1, doneCount: 3),
            RoutineTagSummary(name: "Admin", linkedRoutineCount: 1, doneCount: 0),
            RoutineTagSummary(name: "Health", linkedRoutineCount: 1, doneCount: 0)
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

        await store.send(.saveTapped)
        await store.receive(.delegate(.didSave(makeSaveRequest(
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

        await store.send(.saveTapped)
        await store.receive(.delegate(.didSave(makeSaveRequest(
            name: "Laundry",
            frequencyInDays: 1,
            recurrenceRule: .interval(days: 1),
            emoji: "✨",
            selectedPlaceID: placeID
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

        await store.send(.saveTapped)
        await store.receive(.delegate(.didSave(makeSaveRequest(
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
                    RoutinePlaceSummary(id: removedPlaceID, name: "Home", radiusMeters: 150, linkedRoutineCount: 1)
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
        let store = TestStore(
            initialState: makeState(
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

        await store.send(.saveTapped)
        await store.receive(.delegate(.didSave(makeSaveRequest(
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
                RoutineTagSummary(name: "Morning", linkedRoutineCount: 0)
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
            RoutineTagSummary(name: "Health", linkedRoutineCount: 1)
        ]

        await store.send(.availableTagSummariesChanged(summaries)) {
            $0.organization.availableTagSummaries = [
                RoutineTagSummary(name: "focus", linkedRoutineCount: 5),
                RoutineTagSummary(name: "Morning", linkedRoutineCount: 2),
                RoutineTagSummary(name: "Health", linkedRoutineCount: 1)
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
    func tagRenamed_doesNotAddReplacementToUnrelatedSelectedTags() async {
        let store = TestStore(
            initialState: makeState(
                organization: AddRoutineOrganizationState(
                    routineTags: ["Morning"],
                    availableTags: ["Focus", "Morning"],
                    availableTagSummaries: [
                    RoutineTagSummary(name: "Focus", linkedRoutineCount: 3),
                    RoutineTagSummary(name: "Morning", linkedRoutineCount: 1)
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
                RoutineTagSummary(name: "Morning", linkedRoutineCount: 1)
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
                    RoutineTagSummary(name: "Morning", linkedRoutineCount: 2)
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
            $0.organization.routineTags = ["Mindset", "night", "focus"]
            $0.organization.tagDraft = ""
        }
        await store.receive(.delegate(.didSave(makeSaveRequest(
            name: "Read",
            frequencyInDays: 1,
            recurrenceRule: .interval(days: 1),
            emoji: "📚",
            tags: ["Mindset", "night", "focus"]
        ))))
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
