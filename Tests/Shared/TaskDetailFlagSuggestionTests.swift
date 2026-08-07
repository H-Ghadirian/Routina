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
struct TaskDetailFlagSuggestionTests {
    @Test
    func definedFlagsLoadIntoEditStateAndCanBeSelected() async {
        let task = RoutineTask(name: "Review", emoji: "✅")
        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        }

        await store.send(.availableFlagsLoaded([" Tracking ", "Private", "tracking"])) {
            $0.availableFlags = ["Tracking", "Private"]
        }

        await store.send(.editToggleFlagSelection("Tracking")) {
            $0.editRoutineFlags = ["Tracking"]
        }
    }

    @Test
    func autoAssumeFlagRemainsVisibleButIsRejectedForAnIneligibleTask() async {
        let task = RoutineTask(name: "Review", emoji: "✅")
        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        }
        let rule = RoutineFlagRule(flag: "Tracking", kind: .autoAssumeDone)

        await store.send(.availableFlagsLoaded(["Tracking"])) {
            $0.availableFlags = ["Tracking"]
        }
        await store.send(.flagRulesLoaded([rule])) {
            $0.flagRules = [rule]
        }
        await store.send(.editToggleFlagSelection("Tracking")) {
            $0.editFlagSelectionValidationMessage = "Tracking was not added. Only eligible multi-day After done Standard routines can use it. \(RoutineAssumedCompletion.flagRuleAvailabilitySummary)"
        }
    }
}
