import ComposableArchitecture
import Foundation
import SwiftData

extension HomeFeature {
    func makeRoutineDisplay(
        _ task: RoutineTask,
        placesByID: [UUID: RoutinePlace],
        goalsByID: [UUID: RoutineGoal],
        locationSnapshot: LocationSnapshot,
        doneStats: DoneStats,
        sprintBoardData: SprintBoardData
    ) -> RoutineDisplay {
        let core = HomeRoutineDisplayFactory(now: now, calendar: calendar).makeCore(
            for: task,
            placesByID: placesByID,
            goalsByID: goalsByID,
            locationSnapshot: locationSnapshot,
            doneStats: doneStats
        )
        let assignedSprint = sprintBoardData.sprint(for: task.id)
        let assignedBacklog = sprintBoardData.backlog(for: task.id)

        return RoutineDisplay(core: core, assignedSprint: assignedSprint, assignedBacklog: assignedBacklog)
    }

    func refreshDisplays(_ state: inout State) {
        let placesByID = Dictionary(state.routinePlaces.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let goalsByID = Dictionary(state.routineGoals.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var active: [RoutineDisplay] = []
        var away: [RoutineDisplay] = []
        var archived: [RoutineDisplay] = []
        var boardTodos: [RoutineDisplay] = []

        for task in state.routineTasks {
            let display = makeRoutineDisplay(
                task,
                placesByID: placesByID,
                goalsByID: goalsByID,
                locationSnapshot: state.locationSnapshot,
                doneStats: state.doneStats,
                sprintBoardData: state.sprintBoardData
            )

            if task.isOneOffTask {
                boardTodos.append(display)
            }

            if task.isArchived(referenceDate: now, calendar: calendar) {
                archived.append(display)
            } else if case .away = display.locationAvailability {
                away.append(display)
            } else if task.isCompletedOneOff || task.isCanceledOneOff {
                continue
            } else {
                active.append(display)
            }
        }

        state.routineDisplays = active
        state.awayRoutineDisplays = away
        state.archivedRoutineDisplays = archived
        state.boardTodoDisplays = boardTodos
    }

    func makeTaskDetailState(for task: RoutineTask) -> TaskDetailFeature.State {
        HomeTaskSupport.makeTaskDetailState(for: task, now: now, calendar: calendar)
    }

    func availableTags(from tasks: [RoutineTask]) -> [String] {
        HomeTaskSupport.availableTags(from: tasks)
    }

    func uniqueTaskIDs(_ ids: [UUID]) -> [UUID] {
        HomeTaskSupport.uniqueTaskIDs(ids)
    }

    func existingRoutineNames(from tasks: [RoutineTask]) -> [String] {
        HomeTaskSupport.existingRoutineNames(from: tasks)
    }

    static func placeLinkedCounts(
        from displays: [RoutineDisplay],
        taskListMode: TaskListMode
    ) -> [UUID: Int] {
        displays
            .filter { display in
                switch taskListMode {
                case .all:
                    return true
                case .routines:
                    return !display.isOneOffTask
                case .todos:
                    return display.isOneOffTask
                }
            }
            .reduce(into: [UUID: Int]()) { partialResult, display in
                guard let placeID = display.placeID else { return }
                partialResult[placeID, default: 0] += 1
            }
    }
}

private extension HomeFeature.RoutineDisplay {
    init(
        core: HomeRoutineDisplayCore,
        assignedSprint: BoardSprint?,
        assignedBacklog: BoardBacklog?
    ) {
        self.init(
            taskID: core.taskID,
            name: core.name,
            emoji: core.emoji,
            notes: core.notes,
            hasImage: core.hasImage,
            placeID: core.placeID,
            placeName: core.placeName,
            locationAvailability: core.locationAvailability,
            tags: core.tags,
            goalIDs: core.goalIDs,
            goalTitles: core.goalTitles,
            steps: core.steps,
            interval: core.interval,
            recurrenceRule: core.recurrenceRule,
            scheduleMode: core.scheduleMode,
            createdAt: core.createdAt,
            isSoftIntervalRoutine: core.isSoftIntervalRoutine,
            lastDone: core.lastDone,
            canceledAt: core.canceledAt,
            dueDate: core.dueDate,
            priority: core.priority,
            importance: core.importance,
            urgency: core.urgency,
            pressure: core.pressure,
            scheduleAnchor: core.scheduleAnchor,
            pausedAt: core.pausedAt,
            snoozedUntil: core.snoozedUntil,
            pinnedAt: core.pinnedAt,
            daysUntilDue: core.daysUntilDue,
            isOneOffTask: core.isOneOffTask,
            isCompletedOneOff: core.isCompletedOneOff,
            isCanceledOneOff: core.isCanceledOneOff,
            isDoneToday: core.isDoneToday,
            isAssumedDoneToday: core.isAssumedDoneToday,
            isPaused: core.isPaused,
            isSnoozed: core.isSnoozed,
            isPinned: core.isPinned,
            isOngoing: core.isOngoing,
            ongoingSince: core.ongoingSince,
            hasPassedSoftThreshold: core.hasPassedSoftThreshold,
            completedStepCount: core.completedStepCount,
            isInProgress: core.isInProgress,
            nextStepTitle: core.nextStepTitle,
            checklistItemCount: core.checklistItemCount,
            completedChecklistItemCount: core.completedChecklistItemCount,
            dueChecklistItemCount: core.dueChecklistItemCount,
            nextPendingChecklistItemTitle: core.nextPendingChecklistItemTitle,
            nextDueChecklistItemTitle: core.nextDueChecklistItemTitle,
            doneCount: core.doneCount,
            manualSectionOrders: core.manualSectionOrders,
            color: core.color,
            todoState: core.todoState,
            assignedSprintID: assignedSprint?.id,
            assignedSprintTitle: assignedSprint?.title,
            assignedBacklogID: assignedBacklog?.id,
            assignedBacklogTitle: assignedBacklog?.title
        )
    }
}
