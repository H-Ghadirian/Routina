import ComposableArchitecture
import Foundation
import SwiftData

extension HomeFeature {
    func reducePrimaryAction(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .onAppear:
            return lifecycleActionHandler().onAppear(state: &state)

        case .manualRefreshRequested:
            state.isLoading = true
            state.manualRefreshErrorMessage = nil
            return lifecycleActionHandler().manualRefreshRequested()

        case let .manualRefreshFailed(message):
            state.manualRefreshErrorMessage = message
            return .none

        case .manualRefreshErrorDismissed:
            state.manualRefreshErrorMessage = nil
            return .none

        case let .statusComposerSaveRequested(rawText):
            guard let text = RoutineNote.cleanedText(rawText) else { return .none }
            state.statusComposerErrorMessage = nil
            let createdAt = now
            return .run { @MainActor send in
                let context = modelContext()
                let note = RoutineNote(
                    body: text,
                    tags: ["Status"],
                    createdAt: createdAt,
                    updatedAt: createdAt
                )
                context.insert(note)
                do {
                    try context.save()
                    send(.statusComposerSaveSucceeded)
                } catch {
                    context.delete(note)
                    send(.statusComposerSaveFailed)
                }
            }

        case .statusComposerSaveSucceeded:
            state.statusComposerSaveCount += 1
            state.statusComposerErrorMessage = nil
            return .none

        case .statusComposerSaveFailed:
            state.statusComposerErrorMessage = "Status was not saved."
            return .none

        case let .tasksLoadedSuccessfully(tasks, places, goals, logs, doneStats):
            return taskLoadHandler().applyLoadedTasks(
                tasks: tasks,
                places: places,
                goals: goals,
                logs: logs,
                doneStats: doneStats,
                state: &state
            )

        case let .sprintBoardLoaded(sprintBoardData):
            return applySprintBoardLoaded(sprintBoardData, state: &state)

        case let .sprintBoardLoadedFromStorage(sprintBoardData, revision):
            guard revision == state.board.sprintBoardRevision else {
                return .none
            }
            return applySprintBoardLoaded(sprintBoardData, state: &state)

        case .tasksLoadFailed:
            state.isLoading = false
            state.hasLoadedTaskSnapshot = true
            return lifecycleActionHandler().tasksLoadFailed()

        case let .locationSnapshotUpdated(snapshot):
            return .merge(
                lifecycleActionHandler().locationSnapshotUpdated(snapshot, state: &state),
                automaticPlaceCheckInEffect(for: snapshot)
            )

        case let .hideUnavailableRoutinesChanged(isHidden):
            return lifecycleActionHandler().hideUnavailableRoutinesChanged(isHidden, state: &state)

        case let .setSelectedTask(taskID):
            return selectionRouter().setSelectedTask(taskID, state: &state)

        case let .setAddRoutineSheet(isPresented):
            addRoutinePresentationRouter().setSheet(isPresented, state: &state)
            return .none

        case let .openAddTaskSheet(seedName):
            state.navigation.enterAddTask()
            state.macSidebarSelection = nil
            addRoutinePresentationRouter().setSheet(
                true,
                state: &state,
                seedName: seedName
            )
            persistTemporaryViewState(state)
            return .none

        case let .openAddTaskInCustomSection(sectionID):
            state.navigation.enterAddTask()
            state.macSidebarSelection = nil
            addRoutinePresentationRouter().setSheet(
                true,
                state: &state,
                customTaskSectionID: sectionID
            )
            persistTemporaryViewState(state)
            return .none

        case let .openAddTaskInCustomSectionWithName(sectionID, seedName):
            state.navigation.enterAddTask()
            state.macSidebarSelection = nil
            addRoutinePresentationRouter().setSheet(
                true,
                state: &state,
                seedName: seedName,
                customTaskSectionID: sectionID
            )
            persistTemporaryViewState(state)
            return .none

        case .dismissTaskCreationConfirmation:
            state.taskCreationConfirmation = nil
            return .none

        case let .deleteTasksTapped(ids):
            presentationRouter().requestDeleteTasks(ids, state: &state)
            return .none

        case let .setDeleteConfirmation(isPresented):
            presentationRouter().setDeleteConfirmation(isPresented, state: &state)
            return .none

        case let .taskListModeChanged(mode):
            taskListModeRouter().changeMode(mode, state: &state)
            return .none

        case let .taskListModeFilterChanged(mode):
            taskListModeRouter().changeMode(mode, state: &state, closesFilterDetail: false)
            return .none

        case let .setMacFilterDetailPresented(isPresented):
            presentationRouter().setFilterDetailPresented(isPresented, state: &state)
            return .none
        default:
            return .none
        }
    }

    func loadTasksEffect(performingMaintenance: Bool = false) -> Effect<Action> {
        taskLoadEffectFactory().loadTasksEffect(performingMaintenance: performingMaintenance)
    }

    func syncSelectedTaskDetailState(_ state: inout State) {
        selectionRouter().refreshSelectedTaskDetailState(&state)
    }
}
