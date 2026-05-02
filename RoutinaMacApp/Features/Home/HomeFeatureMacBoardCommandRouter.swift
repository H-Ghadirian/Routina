import ComposableArchitecture
import Foundation

struct HomeFeatureMacBoardCommandRouter {
    var moveTodoToState: (UUID, TodoState, inout HomeFeature.State) -> Effect<HomeFeature.Action>
    var moveTodoOnBoard: (UUID, TodoState, [UUID], inout HomeFeature.State) -> Effect<HomeFeature.Action>
    var createBacklog: (String, inout HomeFeature.State) -> Effect<HomeFeature.Action>
    var createSprint: (String, inout HomeFeature.State) -> Effect<HomeFeature.Action>
    var startSprint: (UUID, inout HomeFeature.State) -> Effect<HomeFeature.Action>
    var finishSprint: (UUID, inout HomeFeature.State) -> Effect<HomeFeature.Action>
    var assignTodoToBacklog: (UUID, UUID?, inout HomeFeature.State) -> Effect<HomeFeature.Action>
    var assignTodosToBacklog: ([UUID], UUID?, inout HomeFeature.State) -> Effect<HomeFeature.Action>
    var assignTodoToSprint: (UUID, UUID?, inout HomeFeature.State) -> Effect<HomeFeature.Action>
    var assignTodosToSprint: ([UUID], UUID?, inout HomeFeature.State) -> Effect<HomeFeature.Action>
    var renameSprint: (UUID, String, inout HomeFeature.State) -> Effect<HomeFeature.Action>
    var deleteSprint: (UUID, inout HomeFeature.State) -> Effect<HomeFeature.Action>

    func selectedBoardScopeChanged(
        _ scope: HomeFeature.BoardScope,
        state: inout HomeFeature.State
    ) -> Effect<HomeFeature.Action> {
        state.selectedBoardScope = scope
        state.selectedTaskID = nil
        state.taskDetailState = nil
        state.macSidebarSelection = nil
        return .none
    }

    func createBacklogTapped(state: inout HomeFeature.State) -> Effect<HomeFeature.Action> {
        state.creatingBacklogTitle = ""
        return .none
    }

    func createBacklogTitleChanged(
        _ title: String,
        state: inout HomeFeature.State
    ) -> Effect<HomeFeature.Action> {
        state.creatingBacklogTitle = title
        return .none
    }

    func createBacklogConfirmed(state: inout HomeFeature.State) -> Effect<HomeFeature.Action> {
        createBacklog(state.creatingBacklogTitle ?? "", &state)
    }

    func createBacklogCanceled(state: inout HomeFeature.State) -> Effect<HomeFeature.Action> {
        state.creatingBacklogTitle = nil
        return .none
    }

    func createSprintTapped(state: inout HomeFeature.State) -> Effect<HomeFeature.Action> {
        state.creatingSprintTitle = ""
        return .none
    }

    func createSprintTitleChanged(
        _ title: String,
        state: inout HomeFeature.State
    ) -> Effect<HomeFeature.Action> {
        state.creatingSprintTitle = title
        return .none
    }

    func createSprintConfirmed(state: inout HomeFeature.State) -> Effect<HomeFeature.Action> {
        createSprint(state.creatingSprintTitle ?? "", &state)
    }

    func createSprintCanceled(state: inout HomeFeature.State) -> Effect<HomeFeature.Action> {
        state.creatingSprintTitle = nil
        return .none
    }

    func renameSprintTapped(
        _ id: UUID,
        state: inout HomeFeature.State
    ) -> Effect<HomeFeature.Action> {
        state.renamingSprintID = id
        state.renamingSprintTitle = state.sprintBoardData.sprints.first(where: { $0.id == id })?.title ?? ""
        return .none
    }

    func renamingSprintTitleChanged(
        _ title: String,
        state: inout HomeFeature.State
    ) -> Effect<HomeFeature.Action> {
        state.renamingSprintTitle = title
        return .none
    }

    func renameSprintConfirmed(state: inout HomeFeature.State) -> Effect<HomeFeature.Action> {
        guard let id = state.renamingSprintID else { return .none }
        return renameSprint(id, state.renamingSprintTitle, &state)
    }

    func renameSprintCanceled(state: inout HomeFeature.State) -> Effect<HomeFeature.Action> {
        state.renamingSprintID = nil
        state.renamingSprintTitle = ""
        return .none
    }

    func deleteSprintTapped(
        _ id: UUID,
        state: inout HomeFeature.State
    ) -> Effect<HomeFeature.Action> {
        state.deletingSprintID = id
        return .none
    }

    func deleteSprintCanceled(state: inout HomeFeature.State) -> Effect<HomeFeature.Action> {
        state.deletingSprintID = nil
        return .none
    }
}
