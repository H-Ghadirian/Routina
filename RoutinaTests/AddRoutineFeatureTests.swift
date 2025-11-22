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
            AddRoutineFeature(onSave: { _, _, _ in .none }, onCancel: { .none })
        }

        await store.send(.routineEmojiChanged("  🔥🎯  ")) {
            $0.routineEmoji = "🔥"
        }
    }

    @Test
    func emojiSanitization_usesFallbackWhenEmptyInput() async {
        let initialState = AddRoutineFeature.State(routineName: "", routineEmoji: "✅", frequency: .day, frequencyValue: 1)
        let store = TestStore(initialState: initialState) {
            AddRoutineFeature(onSave: { _, _, _ in .none }, onCancel: { .none })
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
                frequencyValue: 3
            )
        ) {
            AddRoutineFeature(
                onSave: { name, frequencyInDays, emoji in
                    .send(.delegate(.didSave(name, frequencyInDays, emoji)))
                },
                onCancel: { .none }
            )
        }

        await store.send(.saveTapped)
        await store.receive(.delegate(.didSave("Read", 21, "📚")))
    }

    @Test
    func cancelTapped_sendsCancelDelegate() async {
        let store = TestStore(initialState: AddRoutineFeature.State()) {
            AddRoutineFeature(
                onSave: { _, _, _ in .none },
                onCancel: { .send(.delegate(.didCancel)) }
            )
        }

        await store.send(.cancelTapped)
        await store.receive(.delegate(.didCancel))
    }
}
