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

        let nextDueChecklistItem = task.nextDueChecklistItem(referenceDate: now, calendar: calendar)
        let dueChecklistItems = task.dueChecklistItems(referenceDate: now, calendar: calendar)
        let dueDate: Date? = {
            if task.isOneOffTask {
                return task.deadline
            }
            guard !task.isPaused, !task.isChecklistDriven, task.recurrenceRule.isFixedCalendar else {
                return nil
            }
            return RoutineDateMath.dueDate(for: task, referenceDate: now, calendar: calendar)
        }()
        let daysUntilDue = task.isPaused
            ? 0
            : (task.isCompletedOneOff || task.isCanceledOneOff)
                ? Int.max
                : RoutineDateMath.daysUntilDue(for: task, referenceDate: now, calendar: calendar)

        return RoutineDisplay(
            taskID: task.id,
            name: task.name ?? "Unnamed task",
            emoji: task.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "✨",
            notes: task.notes,
            hasImage: task.hasImage,
            placeID: task.placeID,
            placeName: linkedPlace?.displayName,
            locationAvailability: locationAvailability,
            tags: task.tags,
            steps: task.steps.map(\.title),
            interval: max(Int(task.interval), 1),
            recurrenceRule: task.recurrenceRule,
            scheduleMode: task.scheduleMode,
            lastDone: task.lastDone,
            canceledAt: task.canceledAt,
            dueDate: dueDate,
            priority: task.priority,
            scheduleAnchor: task.scheduleAnchor,
            pausedAt: task.pausedAt,
            pinnedAt: task.pinnedAt,
            daysUntilDue: daysUntilDue,
            isOneOffTask: task.isOneOffTask,
            isCompletedOneOff: task.isCompletedOneOff,
            isCanceledOneOff: task.isCanceledOneOff,
            isDoneToday: doneTodayFromLastDone,
            isPaused: task.isPaused,
            isPinned: task.isPinned,
            completedStepCount: task.completedSteps,
            isInProgress: task.isInProgress,
            nextStepTitle: task.nextStepTitle,
            checklistItemCount: task.checklistItems.count,
            completedChecklistItemCount: task.completedChecklistItemCount,
            dueChecklistItemCount: dueChecklistItems.count,
            nextPendingChecklistItemTitle: task.nextPendingChecklistItemTitle,
            nextDueChecklistItemTitle: nextDueChecklistItem?.title,
            doneCount: doneStats.countsByTaskID[task.id, default: 0]
        )
    }

    func refreshDisplays(_ state: inout State) {
        let placesByID = Dictionary(uniqueKeysWithValues: state.routinePlaces.map { ($0.id, $0) })
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

            if task.isPaused {
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
        let detailTask = task.detachedCopy()
        let defaultSelectedDate = (detailTask.isCompletedOneOff || detailTask.isCanceledOneOff)
            ? calendar.startOfDay(for: detailTask.lastDone ?? detailTask.canceledAt ?? now)
            : calendar.startOfDay(for: now)
        return TaskDetailFeature.State(
            task: detailTask,
            logs: [],
            selectedDate: defaultSelectedDate,
            daysSinceLastRoutine: RoutineDateMath.elapsedDaysSinceLastDone(
                from: detailTask.lastDone,
                referenceDate: now
            ),
            overdueDays: detailTask.isPaused
                ? 0
                : RoutineDateMath.overdueDays(for: detailTask, referenceDate: now, calendar: calendar),
            isDoneToday: detailTask.lastDone.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        )
    }

    func availableTags(from tasks: [RoutineTask]) -> [String] {
        RoutineTag.allTags(from: tasks.map(\.tags))
    }

    func uniqueTaskIDs(_ ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return ids.filter { seen.insert($0).inserted }
    }

    func existingRoutineNames(from tasks: [RoutineTask]) -> [String] {
        tasks.compactMap(\.name)
    }

    func makeDoneStats(tasks: [RoutineTask], logs: [RoutineLog]) -> DoneStats {
        let taskIDs = Set(tasks.map(\.id))
        let countsByTaskID = logs.reduce(into: [UUID: Int]()) { partialResult, log in
            guard taskIDs.contains(log.taskID) else { return }
            guard log.kind == .completed else { return }
            partialResult[log.taskID, default: 0] += 1
        }
        let canceledCountsByTaskID = logs.reduce(into: [UUID: Int]()) { partialResult, log in
            guard taskIDs.contains(log.taskID) else { return }
            guard log.kind == .canceled else { return }
            partialResult[log.taskID, default: 0] += 1
        }
        return DoneStats(
            totalCount: countsByTaskID.values.reduce(0, +),
            countsByTaskID: countsByTaskID,
            canceledTotalCount: canceledCountsByTaskID.values.reduce(0, +),
            canceledCountsByTaskID: canceledCountsByTaskID
        )
    }
}
