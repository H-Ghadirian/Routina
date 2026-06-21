import Foundation

struct HomeRoutineDisplayFactory {
    var now: Date
    var calendar: Calendar

    func makeCore(
        for task: RoutineTask,
        placesByID: [UUID: RoutinePlace],
        goalsByID: [UUID: RoutineGoal],
        locationSnapshot: LocationSnapshot,
        doneStats: HomeDoneStats,
        fileAttachmentTaskIDs: Set<UUID> = []
    ) -> HomeRoutineDisplayCore {
        let currentOccurrenceDay = RoutineAssumedCompletion.currentOccurrenceDay(
            for: task,
            referenceDate: now,
            calendar: calendar
        )
        let doneTodayFromLastDone = task.lastDone.flatMap {
            RoutineDateMath.completionDisplayDay(
                for: task,
                completionDate: $0,
                calendar: calendar
            )
        }.map { calendar.isDate($0, inSameDayAs: currentOccurrenceDay) } ?? false
        let doneTodayFromLogs = doneStats.completedDatesByTaskID[task.id]?.contains {
            guard let displayDay = RoutineDateMath.completionDisplayDay(
                for: task,
                completionDate: $0,
                calendar: calendar
            ) else {
                return false
            }
            return calendar.isDate(displayDay, inSameDayAs: currentOccurrenceDay)
        } ?? false
        let isDoneToday = doneTodayFromLastDone || doneTodayFromLogs
        let assumedDoneToday = !isDoneToday && RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: currentOccurrenceDay,
            referenceDate: now,
            calendar: calendar
        )
        let presentsCompletedChecklistDay = task.isChecklistCompletionRoutine && (isDoneToday || assumedDoneToday)
        let linkedPlaces = task.placeIDs.compactMap { placesByID[$0] }
        let displayPlaceName = placeListDisplayName(for: linkedPlaces)
        let locationPlaces = equivalentPlaces(
            for: linkedPlaces,
            allPlaces: Array(placesByID.values)
        )
        let locationAvailability = makeLocationAvailability(
            for: locationPlaces,
            fallbackPlaceName: displayPlaceName,
            locationSnapshot: locationSnapshot
        )
        let isArchived = task.isArchived(referenceDate: now, calendar: calendar)
        let isSnoozed = task.isSnoozed(referenceDate: now, calendar: calendar)
        let nextDueChecklistItem = task.nextDueChecklistItem(referenceDate: now, calendar: calendar)
        let dueChecklistItems = task.dueChecklistItems(referenceDate: now, calendar: calendar)
        let missedExactTimedOccurrenceDate = RoutineDateMath.missedExactTimedOccurrenceDate(
            for: task,
            referenceDate: now,
            calendar: calendar
        )
        let hasMissedExactTimedOccurrence = missedExactTimedOccurrenceDate.map {
            !doneStats.hasResolvedMissedDate(taskID: task.id, missedDate: $0, calendar: calendar)
        } ?? false

        return HomeRoutineDisplayCore(
            taskID: task.id,
            name: task.name ?? "Unnamed task",
            emoji: CalendarTaskImportSupport.displayEmoji(for: task.emoji) ?? "✨",
            notes: CalendarTaskImportSupport.displayNotes(from: task.notes),
            hasImage: task.hasImage,
            hasFileAttachment: fileAttachmentTaskIDs.contains(task.id),
            placeID: task.placeID,
            placeIDs: task.placeIDs,
            placeName: displayPlaceName,
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
            plannedDate: task.plannedDate,
            priority: task.priority,
            importance: task.importance,
            urgency: task.urgency,
            pressure: task.pressure,
            scheduleAnchor: task.scheduleAnchor,
            pausedAt: task.pausedAt,
            snoozedUntil: task.snoozedUntil,
            pinnedAt: task.pinnedAt,
            daysUntilDue: daysUntilDue(for: task, isArchived: isArchived),
            hasMissedExactTimedOccurrence: hasMissedExactTimedOccurrence,
            isOneOffTask: task.isOneOffTask,
            isCompletedOneOff: task.isCompletedOneOff,
            isCanceledOneOff: task.isCanceledOneOff,
            isDoneToday: isDoneToday || assumedDoneToday,
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
            completedChecklistItemCount: presentsCompletedChecklistDay
                ? 0
                : task.completedChecklistItemCount(referenceDate: now, calendar: calendar),
            dueChecklistItemCount: dueChecklistItems.count,
            hasDailyRunoutChecklistItem: task.hasDailyRunoutChecklistItem,
            nextPendingChecklistItemTitle: presentsCompletedChecklistDay
                ? nil
                : task.nextPendingChecklistItemTitle(referenceDate: now, calendar: calendar),
            nextDueChecklistItemTitle: nextDueChecklistItem?.title,
            doneCount: doneStats.countsByTaskID[task.id, default: 0],
            manualSectionOrders: task.manualSectionOrders,
            color: task.color,
            todoState: task.todoState
        )
    }

    private func makeLocationAvailability(
        for linkedPlaces: [RoutinePlace],
        fallbackPlaceName: String?,
        locationSnapshot: LocationSnapshot
    ) -> RoutineLocationAvailability {
        guard !linkedPlaces.isEmpty else { return .unrestricted }
        let placeName = fallbackPlaceName ?? placeListDisplayName(for: linkedPlaces) ?? "saved place"
        guard locationSnapshot.canDeterminePresence, let coordinate = locationSnapshot.coordinate else {
            return .unknown(placeName: placeName)
        }

        if let containingPlace = linkedPlaces.first(where: { $0.contains(coordinate) }) {
            return .available(placeName: containingPlace.displayName)
        }

        guard let nearestPlace = linkedPlaces.min(by: {
            $0.distance(to: coordinate) < $1.distance(to: coordinate)
        }) else { return .away(placeName: placeName, distanceMeters: 0) }
        return .away(
            placeName: nearestPlace.displayName,
            distanceMeters: nearestPlace.distance(to: coordinate)
        )
    }

    private func equivalentPlaces(
        for linkedPlaces: [RoutinePlace],
        allPlaces: [RoutinePlace]
    ) -> [RoutinePlace] {
        let linkedPlaceIDs = Set(linkedPlaces.map(\.id))
        let linkedKinds = Set(linkedPlaces.compactMap { RoutinePlace.normalizedKind($0.kind) })
        guard !linkedKinds.isEmpty else { return linkedPlaces }

        let sameKindPlaces = allPlaces
            .filter { place in
                guard !linkedPlaceIDs.contains(place.id),
                      let normalizedKind = RoutinePlace.normalizedKind(place.kind)
                else { return false }
                return linkedKinds.contains(normalizedKind)
            }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

        return linkedPlaces + sameKindPlaces
    }

    private func placeListDisplayName(for places: [RoutinePlace]) -> String? {
        switch places.count {
        case 0:
            return nil
        case 1:
            return places[0].displayName
        default:
            return "\(places[0].displayName) + \(places.count - 1)"
        }
    }

    private func dueDate(for task: RoutineTask, isArchived: Bool) -> Date? {
        if task.isOneOffTask {
            return task.deadline ?? task.availabilityStartDate
        }
        guard !isArchived,
              !task.isChecklistDriven,
              task.recurrenceRule.isFixedCalendar || task.recurrenceRule.usesTimeConstraint else {
            return nil
        }
        return RoutineDateMath.upcomingDueDate(for: task, referenceDate: now, calendar: calendar)
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
