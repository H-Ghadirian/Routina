import ComposableArchitecture
import Foundation
import SwiftData

extension HomeFeature {
    func makeRoutineDisplay(
        _ task: RoutineTask,
        placesByID: [UUID: RoutinePlace],
        locationSnapshot: LocationSnapshot,
        doneStats: DoneStats
    ) -> RoutineDisplay {
        let doneTodayFromLastDone = task.lastDone.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        let assumedDoneToday = !doneTodayFromLastDone && RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: now,
            referenceDate: now,
            calendar: calendar
        )
        let linkedPlace = task.placeID.flatMap { placesByID[$0] }
        let locationAvailability: RoutineLocationAvailability

        if let linkedPlace {
            if locationSnapshot.canDeterminePresence, let coordinate = locationSnapshot.coordinate {
                let distance = linkedPlace.distance(to: coordinate)
                if linkedPlace.contains(coordinate) {
                    locationAvailability = .available(placeName: linkedPlace.displayName)
                } else {
                    locationAvailability = .away(
                        placeName: linkedPlace.displayName,
                        distanceMeters: distance
                    )
                }
            } else {
                locationAvailability = .unknown(placeName: linkedPlace.displayName)
            }
        } else {
            locationAvailability = .unrestricted
        }

        let isArchived = task.isArchived(referenceDate: now, calendar: calendar)
        let isSnoozed = task.isSnoozed(referenceDate: now, calendar: calendar)
        let nextDueChecklistItem = task.nextDueChecklistItem(referenceDate: now, calendar: calendar)
        let dueChecklistItems = task.dueChecklistItems(referenceDate: now, calendar: calendar)
        let dueDate: Date? = {
            if task.isOneOffTask {
                return task.deadline
            }
            guard !isArchived, !task.isChecklistDriven, task.recurrenceRule.isFixedCalendar else {
                return nil
            }
            return RoutineDateMath.dueDate(for: task, referenceDate: now, calendar: calendar)
        }()
        let daysUntilDue = isArchived
            ? 0
            : (task.isCompletedOneOff || task.isCanceledOneOff)
                ? Int.max
                : RoutineDateMath.daysUntilDue(for: task, referenceDate: now, calendar: calendar)

        return RoutineDisplay(
            taskID: task.id,
            name: task.name ?? "Unnamed task",
            emoji: CalendarTaskImportSupport.displayEmoji(for: task.emoji) ?? "✨",
            notes: CalendarTaskImportSupport.displayNotes(from: task.notes),
            hasImage: task.hasImage,
            placeID: task.placeID,
            placeName: linkedPlace?.displayName,
            locationAvailability: locationAvailability,
            tags: task.tags,
            steps: task.steps.map(\.title),
            interval: max(Int(task.interval), 1),
            recurrenceRule: task.recurrenceRule,
            scheduleMode: task.scheduleMode,
            createdAt: task.createdAt,
            isSoftIntervalRoutine: task.isSoftIntervalRoutine,
            lastDone: task.lastDone,
            canceledAt: task.canceledAt,
            dueDate: dueDate,
            priority: task.priority,
            importance: task.importance,
            urgency: task.urgency,
            pressure: task.pressure,
            scheduleAnchor: task.scheduleAnchor,
            pausedAt: task.pausedAt,
            snoozedUntil: task.snoozedUntil,
            pinnedAt: task.pinnedAt,
            daysUntilDue: daysUntilDue,
            isOneOffTask: task.isOneOffTask,
            isCompletedOneOff: task.isCompletedOneOff,
            isCanceledOneOff: task.isCanceledOneOff,
            isDoneToday: doneTodayFromLastDone || assumedDoneToday,
            isAssumedDoneToday: assumedDoneToday,
            isPaused: isArchived,
            isSnoozed: isSnoozed,
            isPinned: task.isPinned,
            isOngoing: task.isOngoing,
            ongoingSince: task.ongoingSince,
            hasPassedSoftThreshold: RoutineDateMath.hasPassedSoftIntervalThreshold(
                for: task,
                referenceDate: now,
                calendar: calendar
            ),
            completedStepCount: task.completedSteps,
            isInProgress: task.isInProgress,
            nextStepTitle: task.nextStepTitle,
            checklistItemCount: task.checklistItems.count,
            completedChecklistItemCount: task.completedChecklistItemCount,
            dueChecklistItemCount: dueChecklistItems.count,
            nextPendingChecklistItemTitle: task.nextPendingChecklistItemTitle,
            nextDueChecklistItemTitle: nextDueChecklistItem?.title,
            doneCount: doneStats.countsByTaskID[task.id, default: 0],
            manualSectionOrders: task.manualSectionOrders,
            color: task.color,
            todoState: task.todoState
        )
    }

    func refreshDisplays(_ state: inout State) {
        let placesByID = Dictionary(state.routinePlaces.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var active: [RoutineDisplay] = []
        var away: [RoutineDisplay] = []
        var archived: [RoutineDisplay] = []

        for task in state.routineTasks {
            let display = makeRoutineDisplay(
                task,
                placesByID: placesByID,
                locationSnapshot: state.locationSnapshot,
                doneStats: state.doneStats
            )

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

    func makeDoneStats(tasks: [RoutineTask], logs: [RoutineLog]) -> DoneStats {
        HomeTaskSupport.makeDoneStats(tasks: tasks, logs: logs)
    }
}
