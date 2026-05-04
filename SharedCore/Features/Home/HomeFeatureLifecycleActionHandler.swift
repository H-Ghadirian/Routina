import ComposableArchitecture
import Foundation

protocol HomeFeatureLifecycleState {
    var hideUnavailableRoutines: Bool { get set }
    var locationSnapshot: LocationSnapshot { get set }
    var tagColors: [String: String] { get set }
}

struct HomeFeatureLifecycleActionHandler<State: HomeFeatureLifecycleState, Action> {
    var temporaryViewState: () -> TemporaryViewState?
    var applyTemporaryViewState: (TemporaryViewState?, inout State) -> Void
    var tagColors: () -> [String: String]
    var refreshDisplays: (inout State) -> Void
    var setHideUnavailableRoutines: (Bool) -> Void
    var persistTemporaryViewState: (State) -> Void
    var loadOnAppearEffect: () -> Effect<Action>
    var manualRefreshEffect: () -> Effect<Action>
    var loadFailureLogger: (String) -> Void = { print($0) }

    func onAppear(state: inout State) -> Effect<Action> {
        applyTemporaryViewState(temporaryViewState(), &state)
        state.tagColors = tagColors()
        return loadOnAppearEffect()
    }

    func manualRefreshRequested() -> Effect<Action> {
        manualRefreshEffect()
    }

    func tasksLoadFailed() -> Effect<Action> {
        HomeFeatureLoadFailureSupport.logFailure(using: loadFailureLogger)
        return .none
    }

    func locationSnapshotUpdated(_ snapshot: LocationSnapshot, state: inout State) -> Effect<Action> {
        state.locationSnapshot = snapshot
        refreshDisplays(&state)
        return .none
    }

    func hideUnavailableRoutinesChanged(_ isHidden: Bool, state: inout State) -> Effect<Action> {
        state.hideUnavailableRoutines = isHidden
        setHideUnavailableRoutines(isHidden)
        persistTemporaryViewState(state)
        return .none
    }
}
