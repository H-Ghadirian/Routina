import Foundation

struct HomeSelectedTaskReloadGuard: Equatable {
    var taskID: UUID
    var completedChecklistItemIDsStorage: String
    var lastDone: Date?
    var scheduleAnchor: Date?
}

struct HomeSelectedTaskReconciliation {
    var tasks: [RoutineTask]
    var selectedTaskReloadGuard: HomeSelectedTaskReloadGuard?
}

enum HomeReloadGuardSupport {
    static func makeSelectedTaskReloadGuard(for task: RoutineTask) -> HomeSelectedTaskReloadGuard {
        HomeSelectedTaskReloadGuard(
            taskID: task.id,
            completedChecklistItemIDsStorage: task.completedChecklistItemIDsStorage,
            lastDone: task.lastDone,
            scheduleAnchor: task.scheduleAnchor
        )
    }

    static func pendingChecklistReloadGuardTaskID(
        for itemID: UUID,
        selectedTaskID: UUID?,
        detailState: TaskDetailFeature.State?,
        now: Date,
        calendar: Calendar
    ) -> UUID? {
        guard let selectedTaskID,
              let detailState,
              detailState.task.id == selectedTaskID,
              detailState.task.isChecklistCompletionRoutine,
              !detailState.task.isArchived(),
              detailState.task.checklistItems.contains(where: { $0.id == itemID }),
              calendar.isDate(detailState.selectedDate ?? now, inSameDayAs: now) else {
            return nil
        }

        let task = detailState.task
        if task.isChecklistItemCompleted(itemID) {
            return task.isChecklistInProgress ? task.id : nil
        }

        let alreadyCompletedToday = task.completedChecklistItemIDs.isEmpty
            && task.lastDone.map { calendar.isDate($0, inSameDayAs: now) } == true
        return alreadyCompletedToday ? nil : task.id
    }

    static func pendingChecklistUndoReloadGuardTaskID(
        selectedTaskID: UUID?,
        detailState: TaskDetailFeature.State?
    ) -> UUID? {
        guard let selectedTaskID,
              let detailState,
              detailState.task.id == selectedTaskID,
              detailState.task.isChecklistCompletionRoutine else {
            return nil
        }

        return detailState.task.id
    }

    static func reconcileSelectedDetailTask(
        _ incomingTasks: [RoutineTask],
        selectedTaskID: UUID?,
        detailTask: RoutineTask?,
        selectedTaskReloadGuard: HomeSelectedTaskReloadGuard?
    ) -> HomeSelectedTaskReconciliation {
        guard let selectedTaskID,
              let detailTask,
              detailTask.id == selectedTaskID else {
            return HomeSelectedTaskReconciliation(
                tasks: incomingTasks,
                selectedTaskReloadGuard: nil
            )
        }

        guard let incomingIndex = incomingTasks.firstIndex(where: { $0.id == selectedTaskID }) else {
            return HomeSelectedTaskReconciliation(
                tasks: incomingTasks,
                selectedTaskReloadGuard: nil
            )
        }

        guard let selectedTaskReloadGuard,
              selectedTaskReloadGuard.taskID == selectedTaskID else {
            return HomeSelectedTaskReconciliation(
                tasks: incomingTasks,
                selectedTaskReloadGuard: nil
            )
        }

        let incomingTask = incomingTasks[incomingIndex]
        if matchesSelectedTaskReloadGuard(incomingTask, guard: selectedTaskReloadGuard) {
            return HomeSelectedTaskReconciliation(
                tasks: incomingTasks,
                selectedTaskReloadGuard: selectedTaskReloadGuard
            )
        }

        guard shouldPreserveSelectedDetailTask(
            detailTask,
            over: incomingTask,
            guardedBy: selectedTaskReloadGuard
        ) else {
            return HomeSelectedTaskReconciliation(
                tasks: incomingTasks,
                selectedTaskReloadGuard: nil
            )
        }

        var reconciledTasks = incomingTasks
        reconciledTasks[incomingIndex] = detailTask.detachedCopy()
        return HomeSelectedTaskReconciliation(
            tasks: reconciledTasks,
            selectedTaskReloadGuard: selectedTaskReloadGuard
        )
    }

    private static func matchesSelectedTaskReloadGuard(
        _ task: RoutineTask,
        guard reloadGuard: HomeSelectedTaskReloadGuard
    ) -> Bool {
        task.id == reloadGuard.taskID
            && task.completedChecklistItemIDsStorage == reloadGuard.completedChecklistItemIDsStorage
            && task.lastDone == reloadGuard.lastDone
            && task.scheduleAnchor == reloadGuard.scheduleAnchor
    }

    private static func shouldPreserveSelectedDetailTask(
        _ current: RoutineTask,
        over incoming: RoutineTask,
        guardedBy reloadGuard: HomeSelectedTaskReloadGuard
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
            && current.goalIDs == incoming.goalIDs
            && current.steps == incoming.steps
            && current.checklistItems == incoming.checklistItems
            && current.scheduleMode == incoming.scheduleMode
            && current.recurrenceRule == incoming.recurrenceRule
            && current.interval == incoming.interval
            && current.pausedAt == incoming.pausedAt
            && current.completedStepCount == incoming.completedStepCount
            && current.sequenceStartedAt == incoming.sequenceStartedAt
    }
}
