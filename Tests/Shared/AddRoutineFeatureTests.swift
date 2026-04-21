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
    private typealias SaveHandler = (
        String,
        Int,
        RoutineRecurrenceRule,
        String,
        String?,
        String?,
        Date?,
        RoutineTaskPriority,
        RoutineTaskImportance,
        RoutineTaskUrgency,
        Data?,
        UUID?,
        [String],
        [RoutineTaskRelationship],
        [RoutineStep],
        RoutineScheduleMode,
        [RoutineChecklistItem],
        [AttachmentItem],
        RoutineTaskColor,
        Bool,
        Int?,
        Int?
    ) -> Effect<AddRoutineFeature.Action>

    private func makeState(
        basics: AddRoutineBasicsState = AddRoutineBasicsState(),
        organization: AddRoutineOrganizationState = AddRoutineOrganizationState(),
        schedule: AddRoutineScheduleState = AddRoutineScheduleState(),
        checklist: AddRoutineChecklistState = AddRoutineChecklistState()
    ) -> AddRoutineFeature.State {
        AddRoutineFeature.State(
            basics: basics,
            organization: organization,
            schedule: schedule,
            checklist: checklist
        )
    }

    private func makeFeature(
        onSave: @escaping SaveHandler = { _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in .none },
        onCancel: @escaping () -> Effect<AddRoutineFeature.Action> = { .none }
    ) -> AddRoutineFeature {
        AddRoutineFeature(onSave: onSave, onCancel: onCancel)
    }

    private func makeDelegateEchoFeature() -> AddRoutineFeature {
        makeFeature(
            onSave: { name, frequencyInDays, recurrenceRule, emoji, notes, link, deadline, priority, importance, urgency, imageData, placeID, tags, relationships, steps, scheduleMode, checklistItems, attachments, color, autoAssumeDailyDone, estimatedDurationMinutes, storyPoints in
                .send(.delegate(.didSave(name, frequencyInDays, recurrenceRule, emoji, notes, link, deadline, priority, importance, urgency, imageData, placeID, tags, relationships, steps, scheduleMode, checklistItems, attachments, color, autoAssumeDailyDone, estimatedDurationMinutes, storyPoints)))
            }
        )
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
        await store.receive(.delegate(.didSave("Read", 21, .interval(days: 21), "📚", nil, nil, nil, .medium, .level2, .level2, nil, nil, [], [], [], .fixedInterval, [], [], .none, false, nil, nil)))
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
        await store.receive(.delegate(.didSave("Laundry", 1, .interval(days: 1), "✨", nil, nil, nil, .medium, .level2, .level2, nil, placeID, [], [], [], .fixedInterval, [], [], .none, false, nil, nil)))
    }

    @Test
    func saveTapped_includesEstimationValuesWhenPresent() async {
        let store = TestStore(
            initialState: makeState(
                basics: AddRoutineBasicsState(
                    routineName: "Implement Apple Sign In",
                    estimatedDurationMinutes: 180,
                    storyPoints: 5
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
        await store.receive(.delegate(.didSave("Implement Apple Sign In", 1, .interval(days: 1), "✨", nil, nil, nil, .medium, .level2, .level2, nil, nil, [], [], [], .oneOff, [], [], .none, false, 180, 5)))
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
                onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in
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
                onSave: { name, frequencyInDays, recurrenceRule, emoji, _, _, _, priority, importance, urgency, _, placeID, tags, relationships, steps, scheduleMode, checklistItems, attachments, color, autoAssumeDailyDone, estimatedDurationMinutes, storyPoints in
                    .send(.delegate(.didSave(name, frequencyInDays, recurrenceRule, emoji, nil, nil, nil, priority, importance, urgency, nil, placeID, tags, relationships, steps, scheduleMode, checklistItems, attachments, color, autoAssumeDailyDone, estimatedDurationMinutes, storyPoints)))
                }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped)
        await store.receive(.delegate(.didSave("Read", 5, .interval(days: 5), "📚", nil, nil, nil, .medium, .level2, .level2, nil, nil, [], [], [], .fixedInterval, [], [], .none, false, nil, nil)))
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
                onSave: { _, frequencyInDays, recurrenceRule, _, _, _, _, _, _, _, _, _, _, _, steps, scheduleMode, checklistItems, _, _, _, _, _ in
                    capturedFrequencyInDays.withValue { $0 = frequencyInDays }
                    capturedRecurrenceRules.withValue { $0 = [recurrenceRule] }
                    capturedScheduleModes.withValue { $0 = [scheduleMode] }
                    capturedStepTitles.withValue { $0 = steps.map(\.title) }
                    capturedChecklistTitles.withValue { $0 = checklistItems.map(\.title) }
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
        await store.receive(.delegate(.didSave("Read", 1, .interval(days: 1), "📚", nil, nil, nil, .medium, .level2, .level2, nil, nil, ["Mindset", "night", "focus"], [], [], .fixedInterval, [], [], .none, false, nil, nil)))
    }

    @Test
    func cancelTapped_sendsCancelDelegate() async {
        let store = TestStore(initialState: makeState()) {
            makeFeature(onCancel: { .send(.delegate(.didCancel)) })
        }

        await store.send(.cancelTapped)
        await store.receive(.delegate(.didCancel))
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
                onSave: { name, frequencyInDays, _, emoji, _, _, _, _, _, _, _, placeID, tags, _, steps, _, checklistItems, _, _, _, _, _ in
                    capturedNames.withValue { $0 = [name, "\(frequencyInDays)", emoji] + tags }
                    #expect(placeID == nil)
                    capturedSteps.withValue { $0 = steps }
                    capturedStepTitles.withValue { $0 = steps.map(\.title) }
                    #expect(checklistItems.isEmpty)
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
                onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, steps, scheduleMode, checklistItems, _, _, _, _, _ in
                    #expect(steps.isEmpty)
                    capturedScheduleModes.withValue { $0 = [scheduleMode] }
                    capturedChecklistTitles.withValue { $0 = checklistItems.map(\.title) }
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
                onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, steps, scheduleMode, checklistItems, _, _, _, _, _ in
                    #expect(steps.isEmpty)
                    capturedScheduleModes.withValue { $0 = [scheduleMode] }
                    capturedChecklistTitles.withValue { $0 = checklistItems.map(\.title) }
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
                onSave: { _, _, recurrenceRule, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in
                    capturedRecurrenceRules.withValue { $0 = [recurrenceRule] }
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
                onSave: { _, _, recurrenceRule, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in
                    capturedRecurrenceRules.withValue { $0.append(recurrenceRule) }
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
                onSave: { _, _, recurrenceRule, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in
                    capturedRecurrenceRules.withValue { $0.append(recurrenceRule) }
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
                onSave: { _, _, recurrenceRule, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in
                    capturedRecurrenceRules.withValue { $0.append(recurrenceRule) }
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
                onSave: { _, _, recurrenceRule, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in
                    capturedRecurrenceRules.withValue { $0.append(recurrenceRule) }
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
                onSave: { _, _, _, _, notes, _, savedDeadline, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in
                    capturedNotes.withValue { $0 = notes }
                    capturedDeadline.withValue { $0 = savedDeadline }
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
                onSave: { _, _, _, _, _, link, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in
                    capturedLink.withValue { $0 = link }
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
