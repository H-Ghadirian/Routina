import ComposableArchitecture
import Foundation
import SwiftData
import Testing
@testable @preconcurrency import RoutinaMacOSDev

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
        let store = TestStore(initialState: AddRoutineFeature.State()) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
        }

        await store.send(.routineEmojiChanged("  🔥🎯  ")) {
            $0.routineEmoji = "🔥"
        }
    }

    @Test
    func emojiSanitization_usesFallbackWhenEmptyInput() async {
        let initialState = AddRoutineFeature.State(routineName: "", routineEmoji: "✅", frequency: .day, frequencyValue: 1)
        let store = TestStore(initialState: initialState) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
        }

        await store.send(.routineEmojiChanged("   \n  "))
        #expect(store.state.routineEmoji == "✅")
    }

    @Test
    func importanceAndUrgencyChanges_updateDerivedPriority() async {
        let store = TestStore(initialState: AddRoutineFeature.State()) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
        }

        await store.send(.importanceChanged(.level4)) {
            $0.importance = .level4
            $0.priority = .high
        }

        await store.send(.urgencyChanged(.level4)) {
            $0.urgency = .level4
            $0.priority = .urgent
        }
    }

    @Test
    func deadlineEnabledChanged_usesInjectedNowAndCanClearDeadline() async {
        let now = makeDate("2026-04-10T08:30:00Z")
        let store = TestStore(initialState: AddRoutineFeature.State()) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
        } withDependencies: {
            $0.date.now = now
        }

        await store.send(.deadlineEnabledChanged(true)) {
            $0.deadline = now
        }

        await store.send(.deadlineEnabledChanged(false)) {
            $0.deadline = nil
        }
    }

    @Test
    func availableRelationshipTasksChanged_prunesMissingRelationships() async {
        let keptID = UUID()
        let removedID = UUID()
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                relationships: [
                    RoutineTaskRelationship(targetTaskID: keptID, kind: .blockedBy),
                    RoutineTaskRelationship(targetTaskID: removedID, kind: .blocks)
                ]
            )
        ) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
        }

        let keptCandidate = RoutineTaskRelationshipCandidate(
            id: keptID,
            name: "Read",
            emoji: "📚",
            relationships: []
        )

        await store.send(.availableRelationshipTasksChanged([keptCandidate])) {
            $0.availableRelationshipTasks = [keptCandidate]
            $0.relationships = [RoutineTaskRelationship(targetTaskID: keptID, kind: .blockedBy)]
        }
    }

    @Test
    func saveTapped_sendsDelegateWithFrequencyInDays() async {
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineName: "Read",
                routineEmoji: "📚",
                scheduleMode: .fixedInterval,
                frequency: .week,
                frequencyValue: 3,
                existingRoutineNames: []
            )
        ) {
            AddRoutineFeature(
                onSave: { name, frequencyInDays, recurrenceRule, emoji, notes, link, deadline, priority, importance, urgency, imageData, placeID, tags, relationships, steps, scheduleMode, checklistItems, attachments in
                    .send(.delegate(.didSave(name, frequencyInDays, recurrenceRule, emoji, notes, link, deadline, priority, importance, urgency, imageData, placeID, tags, relationships, steps, scheduleMode, checklistItems, attachments)))
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped)
        await store.receive(.delegate(.didSave("Read", 21, .interval(days: 21), "📚", nil, nil, nil, .medium, .level2, .level2, nil, nil, [], [], [], .fixedInterval, [], [])))
    }

    @Test
    func saveTapped_includesSelectedPlaceID() async {
        let placeID = UUID()
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineName: "Laundry",
                scheduleMode: .fixedInterval,
                availablePlaces: [
                    RoutinePlaceSummary(
                        id: placeID,
                        name: "Home",
                        radiusMeters: 150,
                        linkedRoutineCount: 0
                    )
                ],
                selectedPlaceID: placeID
            )
        ) {
            AddRoutineFeature(
                onSave: { name, frequencyInDays, recurrenceRule, emoji, notes, link, deadline, priority, importance, urgency, imageData, selectedPlaceID, tags, relationships, steps, scheduleMode, checklistItems, attachments in
                    .send(.delegate(.didSave(name, frequencyInDays, recurrenceRule, emoji, notes, link, deadline, priority, importance, urgency, imageData, selectedPlaceID, tags, relationships, steps, scheduleMode, checklistItems, attachments)))
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped)
        await store.receive(.delegate(.didSave("Laundry", 1, .interval(days: 1), "✨", nil, nil, nil, .medium, .level2, .level2, nil, placeID, [], [], [], .fixedInterval, [], [])))
    }

    @Test
    func availablePlacesChanged_clearsSelectedPlaceWhenPlaceDisappears() async {
        let keptPlaceID = UUID()
        let removedPlaceID = UUID()
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                availablePlaces: [
                    RoutinePlaceSummary(id: keptPlaceID, name: "Office", radiusMeters: 150, linkedRoutineCount: 0),
                    RoutinePlaceSummary(id: removedPlaceID, name: "Home", radiusMeters: 150, linkedRoutineCount: 1)
                ],
                selectedPlaceID: removedPlaceID
            )
        ) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
        }

        await store.send(
            .availablePlacesChanged([
                RoutinePlaceSummary(id: keptPlaceID, name: "Office", radiusMeters: 150, linkedRoutineCount: 0)
            ])
        ) {
            $0.availablePlaces = [
                RoutinePlaceSummary(id: keptPlaceID, name: "Office", radiusMeters: 150, linkedRoutineCount: 0)
            ]
            $0.selectedPlaceID = nil
        }
    }

    @Test
    func routineNameChanged_setsDuplicateValidationMessage() async {
        let store = TestStore(
            initialState: AddRoutineFeature.State(existingRoutineNames: ["Read"])
        ) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
        }

        await store.send(.routineNameChanged("  read  ")) {
            $0.routineName = "  read  "
            $0.nameValidationMessage = "A task with this name already exists."
        }
    }

    @Test
    func existingRoutineNamesChanged_clearsValidationWhenDuplicateDisappears() async {
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineName: "Read",
                existingRoutineNames: ["Read"],
                nameValidationMessage: "A task with this name already exists."
            )
        ) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
        }

        await store.send(.existingRoutineNamesChanged(["Walk"])) {
            $0.existingRoutineNames = ["Walk"]
            $0.nameValidationMessage = nil
        }
    }

    @Test
    func saveTapped_doesNothingWhenDuplicateNameExists() async {
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineName: "Read",
                routineEmoji: "📚",
                frequency: .day,
                frequencyValue: 1,
                existingRoutineNames: ["read"],
                nameValidationMessage: "A task with this name already exists."
            )
        ) {
            AddRoutineFeature(
                onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in
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
            initialState: AddRoutineFeature.State(scheduleMode: .fixedIntervalChecklist)
        ) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
        }

        await store.send(.taskTypeChanged(.todo)) {
            $0.scheduleMode = .oneOff
        }

        await store.send(.taskTypeChanged(.routine)) {
            $0.scheduleMode = .fixedInterval
        }
    }

    @Test
    func saveTapped_trimsNameBeforeDelegating() async {
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineName: "  Read  ",
                routineEmoji: "📚",
                scheduleMode: .fixedInterval,
                frequency: .day,
                frequencyValue: 5,
                existingRoutineNames: []
            )
        ) {
            AddRoutineFeature(
                onSave: { name, frequencyInDays, recurrenceRule, emoji, _, _, _, priority, importance, urgency, _, placeID, tags, relationships, steps, scheduleMode, checklistItems, attachments in
                    .send(.delegate(.didSave(name, frequencyInDays, recurrenceRule, emoji, nil, nil, nil, priority, importance, urgency, nil, placeID, tags, relationships, steps, scheduleMode, checklistItems, attachments)))
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped)
        await store.receive(.delegate(.didSave("Read", 5, .interval(days: 5), "📚", nil, nil, nil, .medium, .level2, .level2, nil, nil, [], [], [], .fixedInterval, [], [])))
    }

    @Test
    func saveTapped_forTodoUsesOneOffModeAndKeepsSteps() async {
        let capturedFrequencyInDays = LockIsolated<Int?>(nil)
        let capturedRecurrenceRules = LockIsolated<[RoutineRecurrenceRule]>([])
        let capturedScheduleModes = LockIsolated<[RoutineScheduleMode]>([])
        let capturedStepTitles = LockIsolated<[String]>([])
        let capturedChecklistTitles = LockIsolated<[String]>([])

        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineName: "Buy milk",
                routineEmoji: "🥛",
                scheduleMode: .oneOff,
                routineSteps: [RoutineStep(title: "Open the fridge")],
                stepDraft: "Add it to the cart",
                frequency: .month,
                frequencyValue: 2,
                existingRoutineNames: []
            )
        ) {
            AddRoutineFeature(
                onSave: { _, frequencyInDays, recurrenceRule, _, _, _, _, _, _, _, _, _, _, _, steps, scheduleMode, checklistItems, _ in
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
                $0.stepDraft = ""
            }
        }

        #expect(capturedFrequencyInDays.value == 1)
        #expect(capturedRecurrenceRules.value == [.interval(days: 1)])
        #expect(capturedScheduleModes.value == [.oneOff])
        #expect(capturedStepTitles.value == ["Open the fridge", "Add it to the cart"])
        #expect(capturedChecklistTitles.value.isEmpty)
        #expect(store.state.routineSteps.map(\.title) == ["Open the fridge", "Add it to the cart"])
    }

    @Test
    func addTagTapped_parsesMultipleTagsAndDeduplicates() async {
        let store = TestStore(initialState: AddRoutineFeature.State()) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
        }

        await store.send(.tagDraftChanged(" Health, focus ,health ")) {
            $0.tagDraft = " Health, focus ,health "
        }

        await store.send(.addTagTapped) {
            $0.routineTags = ["Health", "focus"]
            $0.tagDraft = ""
        }
    }

    @Test
    func availableTagsChanged_deduplicatesAndSortsChoices() async {
        let store = TestStore(initialState: AddRoutineFeature.State()) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
        }

        await store.send(.availableTagsChanged([" health ", "Focus", "focus", "Morning"])) {
            $0.availableTags = ["Focus", "health", "Morning"]
        }
    }

    @Test
    func toggleTagSelection_addsAndRemovesChosenTag() async {
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineTags: ["Focus"],
                availableTags: ["Focus", "Morning"]
            )
        ) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
        }

        await store.send(.toggleTagSelection("Morning")) {
            $0.routineTags = ["Focus", "Morning"]
        }

        await store.send(.toggleTagSelection("focus")) {
            $0.routineTags = ["Morning"]
        }
    }

    @Test
    func tagRenamed_doesNotAddReplacementToUnrelatedSelectedTags() async {
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineTags: ["Morning"],
                availableTags: ["Focus", "Morning"]
            )
        ) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
        }

        await store.send(.tagRenamed(oldName: "focus", newName: "Deep Work")) {
            $0.availableTags = ["Deep Work", "Morning"]
        }
    }

    @Test
    func tagDeleted_removesTagFromAvailableAndSelectedTags() async {
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineTags: ["Morning", "Deep Work"],
                availableTags: ["Deep Work", "Morning"]
            )
        ) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
        }

        await store.send(.tagDeleted("morning")) {
            $0.routineTags = ["Deep Work"]
            $0.availableTags = ["Deep Work"]
        }
    }

    @Test
    func saveTapped_commitsPendingTagsBeforeDelegating() async {
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineName: "Read",
                routineEmoji: "📚",
                routineTags: ["Mindset"],
                tagDraft: "night, focus",
                scheduleMode: .fixedInterval,
                frequency: .day,
                frequencyValue: 1,
                existingRoutineNames: []
            )
        ) {
            AddRoutineFeature(
                onSave: { name, frequencyInDays, recurrenceRule, emoji, notes, link, deadline, priority, importance, urgency, imageData, placeID, tags, relationships, steps, scheduleMode, checklistItems, attachments in
                    .send(.delegate(.didSave(name, frequencyInDays, recurrenceRule, emoji, notes, link, deadline, priority, importance, urgency, imageData, placeID, tags, relationships, steps, scheduleMode, checklistItems, attachments)))
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped) {
            $0.routineTags = ["Mindset", "night", "focus"]
            $0.tagDraft = ""
        }
        await store.receive(.delegate(.didSave("Read", 1, .interval(days: 1), "📚", nil, nil, nil, .medium, .level2, .level2, nil, nil, ["Mindset", "night", "focus"], [], [], .fixedInterval, [], [])))
    }

    @Test
    func cancelTapped_sendsCancelDelegate() async {
        let store = TestStore(initialState: AddRoutineFeature.State()) {
            AddRoutineFeature(
                onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in .none },
                onCancel: { .send(.delegate(.didCancel)) }
            )
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
            initialState: AddRoutineFeature.State(
                routineName: "Laundry",
                routineSteps: [RoutineStep(id: washID, title: "Wash clothes")],
                stepDraft: "Hang on the line",
                existingRoutineNames: []
            )
        ) {
            AddRoutineFeature(
                onSave: { name, frequencyInDays, _, emoji, _, _, _, _, _, _, _, placeID, tags, _, steps, _, checklistItems, _ in
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
            $0.routineSteps = capturedSteps.value
            $0.stepDraft = ""
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
            initialState: AddRoutineFeature.State(
                routineName: "Do groceries",
                scheduleMode: .derivedFromChecklist,
                routineChecklistItems: [RoutineChecklistItem(title: "Bread", intervalDays: 3, createdAt: now)],
                checklistItemDraftTitle: "Milk",
                checklistItemDraftInterval: 5,
                existingRoutineNames: []
            )
        ) {
            AddRoutineFeature(
                onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, steps, scheduleMode, checklistItems, _ in
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
                $0.checklistItemDraftTitle = ""
                $0.checklistItemDraftInterval = 3
            }
        }

        #expect(capturedScheduleModes.value == [.derivedFromChecklist])
        #expect(capturedChecklistTitles.value == ["Bread", "Milk"])
        #expect(store.state.routineChecklistItems.map(\.title) == ["Bread", "Milk"])
        #expect(store.state.routineChecklistItems.map(\.intervalDays) == [3, 5])
        #expect(store.state.routineChecklistItems.allSatisfy { $0.createdAt == now })
    }

    @Test
    func saveTapped_inCompletionChecklistMode_sendsChecklistItemsAndMode() async {
        let now = makeDate("2026-03-20T10:00:00Z")
        let capturedChecklistTitles = LockIsolated<[String]>([])
        let capturedScheduleModes = LockIsolated<[RoutineScheduleMode]>([])
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineName: "Pack gym bag",
                scheduleMode: .fixedIntervalChecklist,
                routineChecklistItems: [RoutineChecklistItem(title: "Shoes", intervalDays: 3, createdAt: now)],
                checklistItemDraftTitle: "Towel",
                existingRoutineNames: []
            )
        ) {
            AddRoutineFeature(
                onSave: { _, _, _, _, _, _, _, _, _, _, _, _, _, _, steps, scheduleMode, checklistItems, _ in
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
                $0.checklistItemDraftTitle = ""
                $0.checklistItemDraftInterval = 3
            }
        }

        #expect(capturedScheduleModes.value == [.fixedIntervalChecklist])
        #expect(capturedChecklistTitles.value == ["Shoes", "Towel"])
    }

    @Test
    func saveTapped_dailyTimeSchedule_sendsDailyRecurrenceRule() async {
        let capturedRecurrenceRules = LockIsolated<[RoutineRecurrenceRule]>([])
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineName: "Stretch",
                scheduleMode: .fixedInterval,
                recurrenceKind: .dailyTime,
                recurrenceTimeOfDay: RoutineTimeOfDay(hour: 21, minute: 15),
                existingRoutineNames: []
            )
        ) {
            AddRoutineFeature(
                onSave: { _, _, recurrenceRule, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in
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
            initialState: AddRoutineFeature.State(
                routineName: "Review Week",
                scheduleMode: .fixedInterval,
                recurrenceKind: .weekly,
                recurrenceWeekday: 6,
                existingRoutineNames: []
            )
        ) {
            AddRoutineFeature(
                onSave: { _, _, recurrenceRule, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in
                    capturedRecurrenceRules.withValue { $0.append(recurrenceRule) }
                    return .none
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        let monthlyStore = TestStore(
            initialState: AddRoutineFeature.State(
                routineName: "Pay Bills",
                scheduleMode: .fixedInterval,
                recurrenceKind: .monthlyDay,
                recurrenceDayOfMonth: 21,
                existingRoutineNames: []
            )
        ) {
            AddRoutineFeature(
                onSave: { _, _, recurrenceRule, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ in
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
    func saveTapped_forTodoIncludesNotesAndDeadline() async {
        let deadline = makeDate("2026-03-21T09:00:00Z")
        let capturedNotes = LockIsolated<String?>(nil)
        let capturedDeadline = LockIsolated<Date?>(nil)

        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineName: "Buy milk",
                routineNotes: "  get lactose free  ",
                deadline: deadline,
                scheduleMode: .oneOff,
                existingRoutineNames: []
            )
        ) {
            AddRoutineFeature(
                onSave: { _, _, _, _, notes, _, savedDeadline, _, _, _, _, _, _, _, _, _, _, _ in
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
            initialState: AddRoutineFeature.State(
                routineName: "Plan trip",
                routineLink: "example.com/berlin",
                existingRoutineNames: []
            )
        ) {
            AddRoutineFeature(
                onSave: { _, _, _, _, _, link, _, _, _, _, _, _, _, _, _, _, _, _ in
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
