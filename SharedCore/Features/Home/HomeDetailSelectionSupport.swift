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
            let reconciliation = HomeReloadGuardSupport.reconcileSelectedDetailTask(
                [task],
                selectedTaskID: selectedTaskID,
                detailTask: detailState.task,
                selectedTaskReloadGuard: selection.selectedTaskReloadGuard
            )
            selection.selectedTaskReloadGuard = reconciliation.selectedTaskReloadGuard
            let refreshedTask = reconciliation.tasks.first ?? task
            updateDerivedDetailState(&detailState, task: refreshedTask, now: now, calendar: calendar)
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
           (syncedTask.isChecklistCompletionRoutine || syncedTask.isChecklistDriven),
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
        let pendingTaskID = HomeReloadGuardSupport
            .pendingChecklistReloadGuardTaskID(
                for: itemID,
                selectedTaskID: selection.selectedTaskID,
                detailState: selection.taskDetailState,
                now: now,
                calendar: calendar
            )
        selection.pendingSelectedChecklistReloadGuardTaskID = pendingTaskID

        if let pendingTaskID,
           let detailTask = selection.taskDetailState?.task,
           detailTask.id == pendingTaskID {
            selection.selectedTaskReloadGuard = HomeReloadGuardSupport.makeSelectedTaskReloadGuard(for: detailTask)
        }
    }

    static func updatePendingChecklistUndoReloadGuard(selection: inout HomeSelectionState) {
        selection.pendingSelectedChecklistReloadGuardTaskID = HomeReloadGuardSupport
            .pendingChecklistUndoReloadGuardTaskID(
                selectedTaskID: selection.selectedTaskID,
                detailState: selection.taskDetailState
            )
        if let pendingTaskID = selection.pendingSelectedChecklistReloadGuardTaskID,
           let detailTask = selection.taskDetailState?.task,
           detailTask.id == pendingTaskID {
            selection.selectedTaskReloadGuard = HomeReloadGuardSupport.makeSelectedTaskReloadGuard(for: detailTask)
        }
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
        let todayDisplayDay = calendar.startOfDay(for: now)
        let doneTodayFromLastDone = detailState.task.lastDone.flatMap {
            RoutineDateMath.completionDisplayDay(
                for: detailState.task,
                completionDate: $0,
                calendar: calendar
            )
        }.map { displayDay in
            !detailState.hasPendingLocalRemoval(on: displayDay, calendar: calendar)
                && calendar.isDate(displayDay, inSameDayAs: todayDisplayDay)
        } ?? false
        let doneTodayFromLogs = detailState.logs.contains {
            guard let timestamp = $0.timestamp else { return false }
            guard $0.kind == .completed else { return false }
            guard let displayDay = RoutineDateMath.completionDisplayDay(
                for: detailState.task,
                completionDate: timestamp,
                calendar: calendar
            ) else {
                return false
            }
            return !detailState.hasPendingLocalRemoval(on: displayDay, calendar: calendar)
                && calendar.isDate(displayDay, inSameDayAs: todayDisplayDay)
        }
        detailState.isDoneToday = doneTodayFromLastDone || doneTodayFromLogs
        detailState.isAssumedDoneToday = !detailState.isDoneToday && RoutineAssumedCompletion.isAssumedDone(
            for: detailState.task,
            on: now,
            logs: detailState.logs
        )
    }
}
