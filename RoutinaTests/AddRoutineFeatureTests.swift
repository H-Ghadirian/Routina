import ComposableArchitecture
import Foundation
import SwiftData
import Testing
@testable @preconcurrency import Routina

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
    func emojiSanitization_keepsOnlyFirstCharacter() async {
        let store = TestStore(initialState: AddRoutineFeature.State()) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
        }

        await store.send(.routineEmojiChanged("  🔥🎯  ")) {
            $0.routineEmoji = "🔥"
        }
    }

    @Test
    func emojiSanitization_usesFallbackWhenEmptyInput() async {
        let initialState = AddRoutineFeature.State(routineName: "", routineEmoji: "✅", frequency: .day, frequencyValue: 1)
        let store = TestStore(initialState: initialState) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
        }

        await store.send(.routineEmojiChanged("   \n  "))
        #expect(store.state.routineEmoji == "✅")
    }

    @Test
    func saveTapped_sendsDelegateWithFrequencyInDays() async {
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineName: "Read",
                routineEmoji: "📚",
                frequency: .week,
                frequencyValue: 3,
                existingRoutineNames: []
            )
        ) {
            AddRoutineFeature(
                onSave: { name, frequencyInDays, emoji, placeID, tags, steps, scheduleMode, checklistItems in
                    .send(.delegate(.didSave(name, frequencyInDays, emoji, placeID, tags, steps, scheduleMode, checklistItems)))
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped)
        await store.receive(.delegate(.didSave("Read", 21, "📚", nil, [], [], .fixedInterval, [])))
    }

    @Test
    func saveTapped_includesSelectedPlaceID() async {
        let placeID = UUID()
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineName: "Laundry",
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
                onSave: { name, frequencyInDays, emoji, selectedPlaceID, tags, steps, scheduleMode, checklistItems in
                    .send(.delegate(.didSave(name, frequencyInDays, emoji, selectedPlaceID, tags, steps, scheduleMode, checklistItems)))
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped)
        await store.receive(.delegate(.didSave("Laundry", 1, "✨", placeID, [], [], .fixedInterval, [])))
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
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
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
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
        }

        await store.send(.routineNameChanged("  read  ")) {
            $0.routineName = "  read  "
            $0.nameValidationMessage = "A routine with this name already exists."
        }
    }

    @Test
    func existingRoutineNamesChanged_clearsValidationWhenDuplicateDisappears() async {
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineName: "Read",
                existingRoutineNames: ["Read"],
                nameValidationMessage: "A routine with this name already exists."
            )
        ) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
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
                nameValidationMessage: "A routine with this name already exists."
            )
        ) {
            AddRoutineFeature(
                onSave: { _, _, _, _, _, _, _, _ in
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
    func saveTapped_trimsNameBeforeDelegating() async {
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineName: "  Read  ",
                routineEmoji: "📚",
                frequency: .day,
                frequencyValue: 5,
                existingRoutineNames: []
            )
        ) {
            AddRoutineFeature(
                onSave: { name, frequencyInDays, emoji, placeID, tags, steps, scheduleMode, checklistItems in
                    .send(.delegate(.didSave(name, frequencyInDays, emoji, placeID, tags, steps, scheduleMode, checklistItems)))
                },
                onCancel: { .none }
            )
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.saveTapped)
        await store.receive(.delegate(.didSave("Read", 5, "📚", nil, [], [], .fixedInterval, [])))
    }

    @Test
    func addTagTapped_parsesMultipleTagsAndDeduplicates() async {
        let store = TestStore(initialState: AddRoutineFeature.State()) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _, _, _ in .none }, onCancel: { .none })
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
    func saveTapped_commitsPendingTagsBeforeDelegating() async {
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineName: "Read",
                routineEmoji: "📚",
                routineTags: ["Mindset"],
                tagDraft: "night, focus",
                frequency: .day,
                frequencyValue: 1,
                existingRoutineNames: []
            )
        ) {
            AddRoutineFeature(
                onSave: { name, frequencyInDays, emoji, placeID, tags, steps, scheduleMode, checklistItems in
                    .send(.delegate(.didSave(name, frequencyInDays, emoji, placeID, tags, steps, scheduleMode, checklistItems)))
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
        await store.receive(.delegate(.didSave("Read", 1, "📚", nil, ["Mindset", "night", "focus"], [], .fixedInterval, [])))
    }

    @Test
    func cancelTapped_sendsCancelDelegate() async {
        let store = TestStore(initialState: AddRoutineFeature.State()) {
            AddRoutineFeature(
                onSave: { _, _, _, _, _, _, _, _ in .none },
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
                onSave: { name, frequencyInDays, emoji, placeID, tags, steps, _, checklistItems in
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
                onSave: { _, _, _, _, _, steps, scheduleMode, checklistItems in
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

        await store.withExhaustivity(.off) {
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
                onSave: { _, _, _, _, _, steps, scheduleMode, checklistItems in
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

        await store.withExhaustivity(.off) {
            await store.send(.saveTapped) {
                $0.checklistItemDraftTitle = ""
                $0.checklistItemDraftInterval = 3
            }
        }

        #expect(capturedScheduleModes.value == [.fixedIntervalChecklist])
        #expect(capturedChecklistTitles.value == ["Shoes", "Towel"])
    }
}
