import ComposableArchitecture
import Foundation

extension HomeFeature {
    func makeSelectedTaskReloadGuard(for task: RoutineTask) -> SelectedTaskReloadGuard {
        SelectedTaskReloadGuard(
            taskID: task.id,
            completedChecklistItemIDsStorage: task.completedChecklistItemIDsStorage,
            lastDone: task.lastDone,
            scheduleAnchor: task.scheduleAnchor
        )
    }

    func matchesSelectedTaskReloadGuard(
        _ task: RoutineTask,
        guard reloadGuard: SelectedTaskReloadGuard
    ) -> Bool {
        task.id == reloadGuard.taskID
            && task.completedChecklistItemIDsStorage == reloadGuard.completedChecklistItemIDsStorage
            && task.lastDone == reloadGuard.lastDone
            && task.scheduleAnchor == reloadGuard.scheduleAnchor
    }

    func shouldPreserveSelectedDetailTask(
        _ current: RoutineTask,
        over incoming: RoutineTask,
        guardedBy reloadGuard: SelectedTaskReloadGuard
    ) -> Bool {
        guard current.id == incoming.id,
              current.id == reloadGuard.taskID,
              current.isChecklistCompletionRoutine,
              incoming.isChecklistCompletionRoutine else {
            return false
        }

        return current.name == incoming.name
            && current.emoji == incoming.emoji
            && current.placeID == incoming.placeID
            && current.tags == incoming.tags
            && current.steps == incoming.steps
            && current.checklistItems == incoming.checklistItems
            && current.scheduleMode == incoming.scheduleMode
            && current.recurrenceRule == incoming.recurrenceRule
            && current.interval == incoming.interval
            && current.pausedAt == incoming.pausedAt
            && current.completedStepCount == incoming.completedStepCount
            && current.sequenceStartedAt == incoming.sequenceStartedAt
    }

    func trackSelectedChecklistReloadGuardIfNeeded(
        for itemID: UUID,
        in state: inout State
    ) {
        guard let selectedTaskID = state.selectedTaskID,
              let detailState = state.taskDetailState,
              detailState.task.id == selectedTaskID,
              detailState.task.isChecklistCompletionRoutine,
              !detailState.task.isArchived(),
              detailState.task.checklistItems.contains(where: { $0.id == itemID }),
              calendar.isDate(detailState.selectedDate ?? now, inSameDayAs: now) else {
            state.pendingSelectedChecklistReloadGuardTaskID = nil
            return
        }

        let task = detailState.task
        if task.isChecklistItemCompleted(itemID) {
            state.pendingSelectedChecklistReloadGuardTaskID = task.isChecklistInProgress ? task.id : nil
            return
        }

        let alreadyCompletedToday = task.completedChecklistItemIDs.isEmpty
            && task.lastDone.map { calendar.isDate($0, inSameDayAs: now) } == true
        state.pendingSelectedChecklistReloadGuardTaskID = alreadyCompletedToday ? nil : task.id
    }

    func trackSelectedChecklistUndoReloadGuardIfNeeded(in state: inout State) {
        guard let selectedTaskID = state.selectedTaskID,
              let detailState = state.taskDetailState,
              detailState.task.id == selectedTaskID,
              detailState.task.isChecklistCompletionRoutine else {
            state.pendingSelectedChecklistReloadGuardTaskID = nil
            return
        }

        state.pendingSelectedChecklistReloadGuardTaskID = detailState.task.id
    }

    func reconcileSelectedDetailTask(_ incomingTasks: [RoutineTask], state: inout State) -> [RoutineTask] {
        guard let selectedTaskID = state.selectedTaskID,
              let detailTask = state.taskDetailState?.task,
              detailTask.id == selectedTaskID else {
            state.selectedTaskReloadGuard = nil
            return incomingTasks
        }

        guard let incomingIndex = incomingTasks.firstIndex(where: { $0.id == selectedTaskID }) else {
            state.selectedTaskReloadGuard = nil
            return incomingTasks
        }

        guard let reloadGuard = state.selectedTaskReloadGuard,
              reloadGuard.taskID == selectedTaskID else {
            return incomingTasks
        }

        let incomingTask = incomingTasks[incomingIndex]
        if matchesSelectedTaskReloadGuard(incomingTask, guard: reloadGuard) {
            return incomingTasks
        }

        guard shouldPreserveSelectedDetailTask(detailTask, over: incomingTask, guardedBy: reloadGuard) else {
            state.selectedTaskReloadGuard = nil
            return incomingTasks
        }

        var reconciledTasks = incomingTasks
        reconciledTasks[incomingIndex] = detailTask.detachedCopy()
        return reconciledTasks
    }
}
