import Foundation

struct HomeSelectedTaskReloadGuard: Equatable {
    var taskID: UUID
    var checklistItems: [RoutineChecklistItem] = []
    var completedChecklistItemIDsStorage: String
    var completedChecklistProgressStartedAt: Date?
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
            checklistItems: task.checklistItems,
            completedChecklistItemIDsStorage: task.completedChecklistItemIDsStorage,
            completedChecklistProgressStartedAt: task.completedChecklistProgressStartedAt,
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
              !detailState.task.isArchived(),
              detailState.task.checklistItems.contains(where: { $0.id == itemID }) else {
            return nil
        }

        let task = detailState.task
        let selectedDay = calendar.startOfDay(for: detailState.selectedDate ?? now)
        let today = calendar.startOfDay(for: now)
        guard selectedDay <= today else { return nil }

        if task.isChecklistDriven {
            return task.id
        }

        // Final checklist completion clears item progress after writing lastDone, so the
        // completed state needs the same stale-reload guard as partial progress.
        guard calendar.isDate(selectedDay, inSameDayAs: today) else { return nil }
        return task.isChecklistCompletionRoutine ? task.id : nil
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
            && (reloadGuard.checklistItems.isEmpty || task.checklistItems == reloadGuard.checklistItems)
            && task.completedChecklistItemIDsStorage == reloadGuard.completedChecklistItemIDsStorage
            && task.completedChecklistProgressStartedAt == reloadGuard.completedChecklistProgressStartedAt
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
              current.scheduleMode == incoming.scheduleMode else {
            return false
        }

        let isChecklistProgressMutation = current.isChecklistCompletionRoutine && incoming.isChecklistCompletionRoutine
            || current.isChecklistDriven && incoming.isChecklistDriven
        guard isChecklistProgressMutation else { return false }

        return current.name == incoming.name
            && current.emoji == incoming.emoji
            && current.placeIDs == incoming.placeIDs
            && current.tags == incoming.tags
            && current.goalIDs == incoming.goalIDs
            && current.eventIDs == incoming.eventIDs
            && current.steps == incoming.steps
            && checklistItemStructuresMatch(current.checklistItems, incoming.checklistItems)
            && current.scheduleMode == incoming.scheduleMode
            && current.recurrenceRule == incoming.recurrenceRule
            && current.interval == incoming.interval
            && current.pausedAt == incoming.pausedAt
            && current.completedStepCount == incoming.completedStepCount
            && current.sequenceStartedAt == incoming.sequenceStartedAt
    }

    private static func checklistItemStructuresMatch(
        _ currentItems: [RoutineChecklistItem],
        _ incomingItems: [RoutineChecklistItem]
    ) -> Bool {
        guard currentItems.count == incomingItems.count else { return false }

        return zip(currentItems, incomingItems).allSatisfy { current, incoming in
            current.id == incoming.id
                && current.title == incoming.title
                && current.intervalDays == incoming.intervalDays
                && current.createdAt == incoming.createdAt
        }
    }
}
