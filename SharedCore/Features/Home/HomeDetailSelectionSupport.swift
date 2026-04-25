import Foundation

enum HomeDetailSelectionSupport {
    static func refreshSelectedTaskDetailState(
        selection: inout HomeSelectionState,
        tasks: [RoutineTask],
        now: Date,
        calendar: Calendar,
        makeTaskDetailState: (RoutineTask) -> TaskDetailFeature.State
    ) {
        guard let selectedTaskID = selection.selectedTaskID else {
            HomeSelectionEditor.clearTaskSelection(&selection)
            return
        }

        guard let task = tasks.first(where: { $0.id == selectedTaskID }) else {
            HomeSelectionEditor.clearTaskSelection(&selection)
            return
        }

        if var detailState = selection.taskDetailState {
            updateDerivedDetailState(&detailState, task: task, now: now, calendar: calendar)
            selection.taskDetailState = detailState
        } else {
            selection.taskDetailState = makeTaskDetailState(task)
        }
    }

    static func syncSelectedTaskFromDetail(
        selection: inout HomeSelectionState,
        tasks: inout [RoutineTask]
    ) -> Bool {
        guard let detailTask = selection.taskDetailState?.task else { return false }
        guard let index = tasks.firstIndex(where: { $0.id == detailTask.id }) else { return false }

        let syncedTask = detailTask.detachedCopy()
        tasks[index] = syncedTask
        if selection.pendingSelectedChecklistReloadGuardTaskID == syncedTask.id,
           syncedTask.isChecklistCompletionRoutine,
           selection.selectedTaskID == detailTask.id {
            selection.selectedTaskReloadGuard = HomeReloadGuardSupport.makeSelectedTaskReloadGuard(for: syncedTask)
        }
        selection.pendingSelectedChecklistReloadGuardTaskID = nil
        return true
    }

    static func updatePendingChecklistReloadGuard(
        for itemID: UUID,
        selection: inout HomeSelectionState,
        now: Date,
        calendar: Calendar
    ) {
        selection.pendingSelectedChecklistReloadGuardTaskID = HomeReloadGuardSupport
            .pendingChecklistReloadGuardTaskID(
                for: itemID,
                selectedTaskID: selection.selectedTaskID,
                detailState: selection.taskDetailState,
                now: now,
                calendar: calendar
            )
    }

    static func updatePendingChecklistUndoReloadGuard(selection: inout HomeSelectionState) {
        selection.pendingSelectedChecklistReloadGuardTaskID = HomeReloadGuardSupport
            .pendingChecklistUndoReloadGuardTaskID(
                selectedTaskID: selection.selectedTaskID,
                detailState: selection.taskDetailState
            )
    }

    @discardableResult
    static func clearSelectionIfNeededForTaskListMode(
        selection: inout HomeSelectionState,
        tasks: [RoutineTask],
        modeRawValue: String
    ) -> Bool {
        guard let selectedTaskID = selection.selectedTaskID,
              let task = tasks.first(where: { $0.id == selectedTaskID }) else {
            return false
        }

        let keepSelection: Bool
        switch modeRawValue {
        case "All":
            keepSelection = true
        case "Todos":
            keepSelection = task.isOneOffTask
        case "Routines":
            keepSelection = !task.isOneOffTask
        default:
            keepSelection = true
        }

        guard !keepSelection else { return false }
        HomeSelectionEditor.clearTaskSelection(&selection)
        return true
    }

    private static func updateDerivedDetailState(
        _ detailState: inout TaskDetailFeature.State,
        task: RoutineTask,
        now: Date,
        calendar: Calendar
    ) {
        detailState.task = task.detachedCopy()
        detailState.taskRefreshID &+= 1
        detailState.daysSinceLastRoutine = RoutineDateMath.elapsedDaysSinceLastDone(
            from: detailState.task.lastDone,
            referenceDate: now
        )
        detailState.overdueDays = detailState.task.isArchived(referenceDate: now, calendar: calendar)
            ? 0
            : RoutineDateMath.overdueDays(for: detailState.task, referenceDate: now, calendar: calendar)
        detailState.isDoneToday = detailState.task.lastDone.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        detailState.isAssumedDoneToday = RoutineAssumedCompletion.isAssumedDone(
            for: detailState.task,
            on: now,
            logs: detailState.logs
        )
    }
}
