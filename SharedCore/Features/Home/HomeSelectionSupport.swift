import Foundation

enum HomeSelectionEditor {
    static func clearTaskSelection(_ selection: inout HomeSelectionState) {
        selection.selectedTaskID = nil
        selection.taskDetailState = nil
        selection.selectedTaskReloadGuard = nil
        selection.pendingSelectedChecklistReloadGuardTaskID = nil
    }

    @discardableResult
    static func selectTask(
        taskID: UUID?,
        tasks: [RoutineTask],
        selection: inout HomeSelectionState,
        makeTaskDetailState: (RoutineTask) -> TaskDetailFeature.State
    ) -> Bool {
        guard let taskID,
              let task = tasks.first(where: { $0.id == taskID }) else {
            clearTaskSelection(&selection)
            return false
        }

        selection.selectedTaskID = taskID
        selection.taskDetailState = makeTaskDetailState(task)
        selection.selectedTaskReloadGuard = nil
        selection.pendingSelectedChecklistReloadGuardTaskID = nil
        return true
    }
}
