import Foundation

struct HomeRoutineDisplayFactory {
    var now: Date
    var calendar: Calendar

    func makeCore(
        for task: RoutineTask,
        placesByID: [UUID: RoutinePlace],
        goalsByID: [UUID: RoutineGoal],
        locationSnapshot: LocationSnapshot,
        doneStats: HomeDoneStats
    ) -> HomeRoutineDisplayCore {
        let doneTodayFromLastDone = task.lastDone.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        let assumedDoneToday = !doneTodayFromLastDone && RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: now,
            referenceDate: now,
            calendar: calendar
        )
        let linkedPlace = task.placeID.flatMap { placesByID[$0] }
        let locationAvailability = makeLocationAvailability(
            for: linkedPlace,
            locationSnapshot: locationSnapshot
        )
        let isArchived = task.isArchived(referenceDate: now, calendar: calendar)
        let isSnoozed = task.isSnoozed(referenceDate: now, calendar: calendar)
        let nextDueChecklistItem = task.nextDueChecklistItem(referenceDate: now, calendar: calendar)
        let dueChecklistItems = task.dueChecklistItems(referenceDate: now, calendar: calendar)

        return HomeRoutineDisplayCore(
            taskID: task.id,
            name: task.name ?? "Unnamed task",
            emoji: CalendarTaskImportSupport.displayEmoji(for: task.emoji) ?? "✨",
            notes: CalendarTaskImportSupport.displayNotes(from: task.notes),
            hasImage: task.hasImage,
            placeID: task.placeID,
            placeName: linkedPlace?.displayName,
            locationAvailability: locationAvailability,
            tags: task.tags,
            goalIDs: task.goalIDs,
            goalTitles: task.goalIDs.compactMap { goalsByID[$0]?.displayTitle },
            steps: task.steps.map(\.title),
            interval: max(Int(task.interval), 1),
            recurrenceRule: task.recurrenceRule,
            scheduleMode: task.scheduleMode,
            createdAt: task.createdAt,
            isSoftIntervalRoutine: task.isSoftIntervalRoutine,
            lastDone: task.lastDone,
            canceledAt: task.canceledAt,
            dueDate: dueDate(for: task, isArchived: isArchived),
            priority: task.priority,
            importance: task.importance,
            urgency: task.urgency,
            pressure: task.pressure,
            scheduleAnchor: task.scheduleAnchor,
            pausedAt: task.pausedAt,
            snoozedUntil: task.snoozedUntil,
            pinnedAt: task.pinnedAt,
            daysUntilDue: daysUntilDue(for: task, isArchived: isArchived),
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

    private func makeLocationAvailability(
        for linkedPlace: RoutinePlace?,
        locationSnapshot: LocationSnapshot
    ) -> RoutineLocationAvailability {
        guard let linkedPlace else { return .unrestricted }
        guard locationSnapshot.canDeterminePresence, let coordinate = locationSnapshot.coordinate else {
            return .unknown(placeName: linkedPlace.displayName)
        }

        let distance = linkedPlace.distance(to: coordinate)
        if linkedPlace.contains(coordinate) {
            return .available(placeName: linkedPlace.displayName)
        }
        return .away(placeName: linkedPlace.displayName, distanceMeters: distance)
    }

    private func dueDate(for task: RoutineTask, isArchived: Bool) -> Date? {
        if task.isOneOffTask {
            return task.deadline
        }
        guard !isArchived, !task.isChecklistDriven, task.recurrenceRule.isFixedCalendar else {
            return nil
        }
        return RoutineDateMath.dueDate(for: task, referenceDate: now, calendar: calendar)
    }

    private func daysUntilDue(for task: RoutineTask, isArchived: Bool) -> Int {
        if isArchived {
            return 0
        }
        if task.isCompletedOneOff || task.isCanceledOneOff {
            return Int.max
        }
        return RoutineDateMath.daysUntilDue(for: task, referenceDate: now, calendar: calendar)
    }
}
