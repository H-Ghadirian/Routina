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

        await store.send(.availableFlagsLoaded([" Reference ", "Private", "reference"])) {
            $0.availableFlags = ["Reference", "Private"]
        }

        await store.send(.editToggleFlagSelection("Reference")) {
            $0.editRoutineFlags = ["Reference"]
        }
    }

    @Test
    func autoAssumeFlagRemainsVisibleButIsRejectedForAnIneligibleTask() async {
        let task = RoutineTask(
            name: "Review",
            emoji: "✅",
            steps: [RoutineStep(title: "Review notes")]
        )
        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                editRoutineSteps: [RoutineStep(title: "Review notes")]
            )
        ) {
            TaskDetailFeature()
        }
        let rule = RoutineFlagRule(flag: "Reference", kind: .autoAssumeDone)

        await store.send(.availableFlagsLoaded(["Reference"])) {
            $0.availableFlags = ["Reference"]
        }
        await store.send(.flagRulesLoaded([rule])) {
            $0.flagRules = [rule]
        }
        await store.send(.editToggleFlagSelection("Reference")) {
            $0.editFlagSelectionValidationMessage = "Reference was not added. It is not available for tasks with steps. \(RoutineAssumedCompletion.flagRuleAvailabilitySummary)"
        }
    }

    @Test
    func autoAssumeFlagCanBeSelectedForFixedEveryTwoWeeksTuesdaySchedule() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let recurrenceRule = RoutineRecurrenceRule.advanced(
            RoutineAdvancedRecurrenceRule(
                frequency: .weekly,
                interval: 2,
                startDate: makeDate("2026-07-21T11:15:00Z"),
                weekdays: [3],
                timesOfDay: [RoutineTimeOfDay(hour: 11, minute: 15)],
                timeZoneIdentifier: "UTC",
                calendar: calendar
            )
        )
        let task = RoutineTask(
            name: "Biweekly review",
            emoji: "✅",
            scheduleMode: .fixedInterval,
            recurrenceRule: recurrenceRule
        )
        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        }
        let rule = RoutineFlagRule(flag: "Reference", kind: .autoAssumeDone)

        await store.send(.flagRulesLoaded([rule])) {
            $0.flagRules = [rule]
        }
        await store.send(.editToggleFlagSelection("Reference")) {
            $0.editRoutineFlags = ["Reference"]
        }
    }
}
