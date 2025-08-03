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
            AddRoutineFeature(onSave: { _, _, _, _, _, _ in .none }, onCancel: { .none })
        }

        await store.send(.routineEmojiChanged("  🔥🎯  ")) {
            $0.routineEmoji = "🔥"
        }
    }

    @Test
    func emojiSanitization_usesFallbackWhenEmptyInput() async {
        let initialState = AddRoutineFeature.State(routineName: "", routineEmoji: "✅", frequency: .day, frequencyValue: 1)
        let store = TestStore(initialState: initialState) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _ in .none }, onCancel: { .none })
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
                onSave: { name, frequencyInDays, emoji, placeID, tags, steps in
                    .send(.delegate(.didSave(name, frequencyInDays, emoji, placeID, tags, steps)))
                },
                onCancel: { .none }
            )
        }

        await store.send(.saveTapped)
        await store.receive(.delegate(.didSave("Read", 21, "📚", nil, [], [])))
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
                onSave: { name, frequencyInDays, emoji, selectedPlaceID, tags, steps in
                    .send(.delegate(.didSave(name, frequencyInDays, emoji, selectedPlaceID, tags, steps)))
                },
                onCancel: { .none }
            )
        }

        await store.send(.saveTapped)
        await store.receive(.delegate(.didSave("Laundry", 1, "✨", placeID, [], [])))
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
            AddRoutineFeature(onSave: { _, _, _, _, _, _ in .none }, onCancel: { .none })
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
            AddRoutineFeature(onSave: { _, _, _, _, _, _ in .none }, onCancel: { .none })
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
            AddRoutineFeature(onSave: { _, _, _, _, _, _ in .none }, onCancel: { .none })
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
                onSave: { _, _, _, _, _, _ in
                    Issue.record("Save effect should not run for duplicate routine names")
                    return .none
                },
                onCancel: { .none }
            )
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
                onSave: { name, frequencyInDays, emoji, placeID, tags, steps in
                    .send(.delegate(.didSave(name, frequencyInDays, emoji, placeID, tags, steps)))
                },
                onCancel: { .none }
            )
        }

        await store.send(.saveTapped)
        await store.receive(.delegate(.didSave("Read", 5, "📚", nil, [], [])))
    }

    @Test
    func addTagTapped_parsesMultipleTagsAndDeduplicates() async {
        let store = TestStore(initialState: AddRoutineFeature.State()) {
            AddRoutineFeature(onSave: { _, _, _, _, _, _ in .none }, onCancel: { .none })
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
                onSave: { name, frequencyInDays, emoji, placeID, tags, steps in
                    .send(.delegate(.didSave(name, frequencyInDays, emoji, placeID, tags, steps)))
                },
                onCancel: { .none }
            )
        }

        await store.send(.saveTapped) {
            $0.routineTags = ["Mindset", "night", "focus"]
            $0.tagDraft = ""
        }
        await store.receive(.delegate(.didSave("Read", 1, "📚", nil, ["Mindset", "night", "focus"], [])))
    }

    @Test
    func cancelTapped_sendsCancelDelegate() async {
        let store = TestStore(initialState: AddRoutineFeature.State()) {
            AddRoutineFeature(
                onSave: { _, _, _, _, _, _ in .none },
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
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineName: "Laundry",
                routineSteps: [RoutineStep(id: washID, title: "Wash clothes")],
                stepDraft: "Hang on the line",
                existingRoutineNames: []
            )
        ) {
            AddRoutineFeature(
                onSave: { name, frequencyInDays, emoji, placeID, tags, steps in
                    capturedNames.withValue { $0 = [name, "\(frequencyInDays)", emoji] + tags }
                    #expect(placeID == nil)
                    capturedStepTitles.withValue { $0 = steps.map(\.title) }
                    return .none
                },
                onCancel: { .none }
            )
        }

        await store.send(.saveTapped)
        #expect(store.state.stepDraft.isEmpty)
        #expect(store.state.routineSteps.map(\.title) == ["Wash clothes", "Hang on the line"])
        #expect(capturedNames.value == ["Laundry", "1", "✨"])
        #expect(capturedStepTitles.value == ["Wash clothes", "Hang on the line"])
    }
}
