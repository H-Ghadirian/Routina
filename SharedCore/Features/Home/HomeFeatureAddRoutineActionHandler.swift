import ComposableArchitecture
import Foundation
import SwiftData

protocol HomeFeatureAddRoutineActionState {
    var routineTasks: [RoutineTask] { get set }
    var presentation: HomePresentationState { get set }
}

struct HomeFeatureAddRoutineActionHandler<State: HomeFeatureAddRoutineActionState, Action> {
    var referenceDate: Date
    var calendar: Calendar
    var dismissSheet: (inout State) -> Void
    var modelContext: @MainActor @Sendable () -> ModelContext
    var scheduleAnchor: @MainActor @Sendable () -> Date
    var currentEntitlement: @Sendable () async -> RoutinaSubscriptionEntitlement
    var scheduleNotification: @Sendable (NotificationPayload) async -> Void
    var savedAction: @Sendable (RoutineTask) -> Action
    var subscriptionRequiredAction: @Sendable (RoutinaTaskLimitSnapshot, AddRoutineSaveRequest) -> Action
    var failedAction: @Sendable () -> Action
    var finishMutation: (Effect<Action>, inout State) -> Effect<Action>
    var loadTasksEffect: () -> Effect<Action>
    var clearDraft: () -> Void

    func cancel(state: inout State) -> Effect<Action> {
        dismissSheet(&state)
        clearDraft()
        return .none
    }

    func save(_ request: AddRoutineSaveRequest) -> Effect<Action> {
        let makeSubscriptionRequiredAction = subscriptionRequiredAction
        return HomeAddRoutineSupport.saveRoutine(
            from: request,
            scheduleAnchor: scheduleAnchor,
            calendar: calendar,
            modelContext: modelContext,
            currentEntitlement: currentEntitlement,
            savedAction: savedAction,
            subscriptionRequiredAction: { snapshot in
                makeSubscriptionRequiredAction(snapshot, request)
            },
            failedAction: failedAction
        )
    }

    func finishSave(_ task: RoutineTask, state: inout State) -> Effect<Action> {
        var routineTasks = state.routineTasks
        var presentation = state.presentation
        let effect: Effect<Action> = HomeAddRoutineSupport.applySavedRoutine(
            task,
            referenceDate: referenceDate,
            calendar: calendar,
            tasks: &routineTasks,
            presentation: &presentation,
            scheduleNotification: scheduleNotification
        )
        state.routineTasks = routineTasks
        state.presentation = presentation
        clearDraft()
        return finishMutation(.merge(effect, loadTasksEffect()), &state)
    }

    func failSave() -> Effect<Action> {
        print("Failed to save routine.")
        return .none
    }
}
