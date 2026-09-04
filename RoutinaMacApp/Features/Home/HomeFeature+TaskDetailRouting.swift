import ComposableArchitecture
import Foundation

extension HomeFeature {
    func reduceTaskDetail(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        guard case let .taskDetail(taskDetailAction) = action,
            var taskDetailState = state.taskDetailState
        else {
            return .none
        }

        let taskDetailID = taskDetailState.task.id
        state.selection.taskDetailEffectTaskID = taskDetailID
        let effect = TaskDetailFeature()
            .reduce(into: &taskDetailState, action: taskDetailAction)
            .map(Action.taskDetail)
            .cancellable(id: TaskDetailCancelID.task(taskDetailID))
        state.taskDetailState = taskDetailState
        return effect
    }

    func cancelStaleTaskDetailEffects(state: inout State) -> Effect<Action> {
        let currentTaskID = state.taskDetailState?.task.id
        guard state.selection.taskDetailEffectTaskID != currentTaskID else { return .none }

        let previousTaskID = state.selection.taskDetailEffectTaskID
        state.selection.taskDetailEffectTaskID = currentTaskID
        guard let previousTaskID else { return .none }
        return .cancel(id: TaskDetailCancelID.task(previousTaskID))
    }

    func syncSelectedTaskLogs(_ logs: [RoutineLog], state: inout State) {
        guard let detailTask = state.selection.taskDetailState?.task else { return }
        let taskID = detailTask.id
        let resolvedLogs = state.selection.taskDetailState?.logs ?? logs
        let timelineLogs = TimelineLogic.logsIncludingLastDoneFallbacks(
            logs: resolvedLogs,
            tasks: [detailTask],
            calendar: calendar
        )

        var updatedDoneStats = state.doneStats
        updatedDoneStats.replaceLogs(for: taskID, with: timelineLogs)
        let existingTimelineLogs = state.timelineLogs.filter { $0.taskID == taskID }
        guard
            updatedDoneStats != state.doneStats
                || !HomeTaskSupport.logsHaveSamePayload(existingTimelineLogs, timelineLogs)
        else {
            return
        }

        state.doneStats = updatedDoneStats
        state.timelineLogs = HomeTaskSupport.replacingTimelineLogs(
            for: taskID,
            in: state.timelineLogs,
            with: timelineLogs
        )
        refreshDisplays(&state)
    }
}
