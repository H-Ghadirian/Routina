import Foundation

struct HomeChecklistRunoutDoneUpdate: Equatable {
    var taskID: UUID
    var completionDate: Date
}

struct HomeAdvanceTaskUpdate: Equatable {
    var taskID: UUID
    var completionDate: Date
    var previousTodoStateTitle: String?
}

struct HomePauseTaskUpdate: Equatable {
    var taskID: UUID
    var pauseDate: Date
}

struct HomeResumeTaskUpdate: Equatable {
    var taskID: UUID
    var resumeDate: Date
}

struct HomeSnoozeTaskUpdate: Equatable {
    var taskID: UUID
    var snoozedUntil: Date
}

struct HomePinTaskUpdate: Equatable {
    var taskID: UUID
    var pinnedAt: Date
}

struct HomePlanTaskUpdate: Equatable {
    var taskID: UUID
    var plannedDate: Date?
    var customTaskSectionID: UUID? = nil
}

struct HomeDeleteCustomTaskSectionUpdate: Equatable {
    var sectionID: UUID
    var sectionKey: String
    var taskIDs: [UUID]
}

struct HomeUnpinTaskUpdate: Equatable {
    var taskID: UUID
}

struct HomeMarkTaskMissedUpdate: Equatable {
    var taskID: UUID
    var missedDate: Date
    var referenceDate: Date
}

struct HomeResolveAssumedTaskUpdate: Equatable {
    var taskID: UUID
    var resolutionDate: Date
    var referenceDate: Date
}

struct HomeMarkTaskCanceledUpdate: Equatable {
    var taskID: UUID
    var canceledDate: Date
    var referenceDate: Date
}

enum HomeMarkTaskDoneUpdate: Equatable {
    case checklist(HomeChecklistRunoutDoneUpdate)
    case advance(HomeAdvanceTaskUpdate)
}

enum HomeTaskLifecycleSupport {
    static func markTaskDone(
        taskID: UUID,
        referenceDate: Date,
        calendar: Calendar,
        tasks: inout [RoutineTask],
        doneStats: inout HomeDoneStats
    ) -> HomeMarkTaskDoneUpdate? {
        guard let index = tasks.firstIndex(where: {
            $0.id == taskID && !$0.isArchived(referenceDate: referenceDate, calendar: calendar)
        }) else {
            return nil
        }
        guard !tasks[index].isCompletedOneOff else {
            return nil
        }
        guard !tasks[index].isCanceledOneOff else {
            return nil
        }
        guard !tasks[index].isChecklistCompletionRoutine else {
            return nil
        }

        if tasks[index].isChecklistDriven {
            guard RoutineDateMath.canMarkDone(
                for: tasks[index],
                referenceDate: referenceDate,
                calendar: calendar
            ) else {
                return nil
            }
            let dueItemIDs = Set(
                tasks[index]
                    .dueChecklistItems(referenceDate: referenceDate, calendar: calendar)
                    .map(\.id)
            )
            let update = tasks[index].markChecklistItemsDone(
                dueItemIDs,
                doneAt: referenceDate,
                calendar: calendar
            )
            guard update.updatedItemCount > 0 else { return nil }
            if update.didCompleteRoutine {
                doneStats.totalCount += 1
                doneStats.countsByTaskID[taskID, default: 0] += 1
                doneStats.completedDatesByTaskID[taskID, default: []].insert(referenceDate)
                fulfillLinkedTasks(
                    from: taskID,
                    completedAt: referenceDate,
                    calendar: calendar,
                    tasks: &tasks,
                    doneStats: &doneStats
                )
            }
            return .checklist(
                HomeChecklistRunoutDoneUpdate(
                    taskID: taskID,
                    completionDate: referenceDate
                )
            )
        }
        guard !tasks[index].blocksManualCompletionForIncompleteChecklist else {
            return nil
        }

        let task = tasks[index]
        let completionDate: Date
        if let missedDate = unresolvedMissedExactTimedOccurrenceDate(
            for: task,
            taskID: taskID,
            referenceDate: referenceDate,
            calendar: calendar,
            doneStats: doneStats
        ) {
            completionDate = missedDate
        } else if let exactTimedTarget = RoutineDateMath.completionTargetDate(
            for: task,
            selectedDay: referenceDate,
            referenceDate: referenceDate,
            calendar: calendar
        ) {
            completionDate = exactTimedTarget
        } else if RoutineDateMath.usesExactTimedOccurrenceTracking(for: task) {
            return nil
        } else {
            completionDate = referenceDate
        }

        if RoutineDateMath.usesExactTimedOccurrenceTracking(for: task) {
            let missedDates = RoutineDateMath.missedExactTimedOccurrenceDates(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            )
            let hasUnresolvedPriorMissedDate = missedDates.contains { missedDate in
                missedDate < completionDate
                    && !doneStats.hasResolvedMissedDate(
                        taskID: taskID,
                        missedDate: missedDate,
                        calendar: calendar
                    )
            }
            let isSelectedMissedDate = missedDates.contains {
                calendar.isDate($0, inSameDayAs: completionDate)
            }
            let isReferenceDayMissedDate = isSelectedMissedDate
                && calendar.isDate(completionDate, inSameDayAs: referenceDate)
            guard (!hasUnresolvedPriorMissedDate || isReferenceDayMissedDate),
                  isSelectedMissedDate
                    || RoutineDateMath.canMarkDone(
                        for: task,
                        referenceDate: completionDate,
                        calendar: calendar
                    ) else {
                return nil
            }
        } else {
            guard RoutineDateMath.canMarkDone(
                for: task,
                referenceDate: completionDate,
                calendar: calendar
            ) else {
                return nil
            }
        }

        let previousTodoStateTitle = tasks[index].isOneOffTask ? tasks[index].todoState?.displayTitle : nil
        let result = tasks[index].advance(completedAt: completionDate, calendar: calendar)
        if case .completedRoutine = result {
            doneStats.totalCount += 1
            doneStats.countsByTaskID[taskID, default: 0] += 1
            doneStats.completedDatesByTaskID[taskID, default: []].insert(completionDate)
            fulfillLinkedTasks(
                from: taskID,
                completedAt: completionDate,
                calendar: calendar,
                tasks: &tasks,
                doneStats: &doneStats
            )
            _ = BatteryRoutineService.dismissCompletedLowBatteryPrompt(
                for: tasks[index],
                at: completionDate
            )
            if tasks[index].isOneOffTask,
               previousTodoStateTitle != TodoState.done.displayTitle {
                tasks[index].appendChangeLogEntry(
                    RoutineTaskChangeLogEntry(
                        timestamp: completionDate,
                        kind: .stateChanged,
                        previousValue: previousTodoStateTitle,
                        newValue: TodoState.done.displayTitle
                    )
                )
            }
        }
        return .advance(
            HomeAdvanceTaskUpdate(
                taskID: taskID,
                completionDate: completionDate,
                previousTodoStateTitle: previousTodoStateTitle
            )
        )
    }

    static func markTaskMissed(
        taskID: UUID,
        referenceDate: Date,
        calendar: Calendar,
        tasks: [RoutineTask],
        doneStats: inout HomeDoneStats
    ) -> HomeMarkTaskMissedUpdate? {
        guard let task = tasks.first(where: {
            $0.id == taskID && !$0.isArchived(referenceDate: referenceDate, calendar: calendar)
        }) else {
            return nil
        }
        guard let missedDate = unresolvedMissedExactTimedOccurrenceDate(
            for: task,
            taskID: taskID,
            referenceDate: referenceDate,
            calendar: calendar,
            doneStats: doneStats
        ) else {
            return nil
        }

        let hadCanceledResolution = doneStats.canceledDatesByTaskID[taskID]?.contains {
            calendar.isDate($0, inSameDayAs: missedDate)
        } ?? false
        doneStats.missedDatesByTaskID[taskID, default: []].insert(missedDate)
        removeDate(missedDate, for: taskID, from: &doneStats.canceledDatesByTaskID, calendar: calendar)
        if hadCanceledResolution {
            doneStats.canceledTotalCount = max(doneStats.canceledTotalCount - 1, 0)
            let updatedTaskCount = max(doneStats.canceledCountsByTaskID[taskID, default: 0] - 1, 0)
            if updatedTaskCount == 0 {
                doneStats.canceledCountsByTaskID.removeValue(forKey: taskID)
            } else {
                doneStats.canceledCountsByTaskID[taskID] = updatedTaskCount
            }
        }
        return HomeMarkTaskMissedUpdate(taskID: taskID, missedDate: missedDate, referenceDate: referenceDate)
    }

    static func confirmAssumedTaskDone(
        taskID: UUID,
        referenceDate: Date,
        calendar: Calendar,
        tasks: [RoutineTask],
        doneStats: inout HomeDoneStats
    ) -> HomeResolveAssumedTaskUpdate? {
        guard let task = assumedTask(
            taskID: taskID,
            referenceDate: referenceDate,
            calendar: calendar,
            tasks: tasks,
            doneStats: doneStats
        ) else {
            return nil
        }

        let day = RoutineAssumedCompletion.currentOccurrenceDay(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let completionDate = RoutineAssumedCompletion.completionTimestamp(
            for: task,
            on: day,
            referenceDate: referenceDate,
            calendar: calendar
        )
        doneStats.totalCount += 1
        doneStats.countsByTaskID[taskID, default: 0] += 1
        doneStats.completedDatesByTaskID[taskID, default: []].insert(completionDate)
        removeDate(completionDate, for: taskID, from: &doneStats.missedDatesByTaskID, calendar: calendar)
        removeDate(completionDate, for: taskID, from: &doneStats.canceledDatesByTaskID, calendar: calendar)
        return HomeResolveAssumedTaskUpdate(
            taskID: taskID,
            resolutionDate: completionDate,
            referenceDate: referenceDate
        )
    }

    static func markAssumedTaskMissed(
        taskID: UUID,
        referenceDate: Date,
        calendar: Calendar,
        tasks: [RoutineTask],
        doneStats: inout HomeDoneStats
    ) -> HomeResolveAssumedTaskUpdate? {
        guard let task = assumedTask(
            taskID: taskID,
            referenceDate: referenceDate,
            calendar: calendar,
            tasks: tasks,
            doneStats: doneStats
        ) else {
            return nil
        }

        let day = RoutineAssumedCompletion.currentOccurrenceDay(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let missedDate = RoutineAssumedCompletion.completionTimestamp(
            for: task,
            on: day,
            referenceDate: referenceDate,
            calendar: calendar
        )
        doneStats.missedDatesByTaskID[taskID, default: []].insert(missedDate)
        removeDate(missedDate, for: taskID, from: &doneStats.canceledDatesByTaskID, calendar: calendar)
        return HomeResolveAssumedTaskUpdate(
            taskID: taskID,
            resolutionDate: missedDate,
            referenceDate: referenceDate
        )
    }

    static func markTaskCanceled(
        taskID: UUID,
        referenceDate: Date,
        calendar: Calendar,
        tasks: [RoutineTask],
        doneStats: inout HomeDoneStats
    ) -> HomeMarkTaskCanceledUpdate? {
        guard let task = tasks.first(where: {
            $0.id == taskID && !$0.isArchived(referenceDate: referenceDate, calendar: calendar)
        }) else {
            return nil
        }
        guard let canceledDate = unresolvedMissedExactTimedOccurrenceDate(
            for: task,
            taskID: taskID,
            referenceDate: referenceDate,
            calendar: calendar,
            doneStats: doneStats
        ) else {
            return nil
        }

        let alreadyCanceled = doneStats.canceledDatesByTaskID[taskID]?.contains {
            calendar.isDate($0, inSameDayAs: canceledDate)
        } ?? false
        if !alreadyCanceled {
            doneStats.canceledTotalCount += 1
            doneStats.canceledCountsByTaskID[taskID, default: 0] += 1
        }
        doneStats.canceledDatesByTaskID[taskID, default: []].insert(canceledDate)
        removeDate(canceledDate, for: taskID, from: &doneStats.missedDatesByTaskID, calendar: calendar)

        return HomeMarkTaskCanceledUpdate(taskID: taskID, canceledDate: canceledDate, referenceDate: referenceDate)
    }

    static func pauseTask(
        taskID: UUID,
        pauseDate: Date,
        calendar: Calendar,
        tasks: inout [RoutineTask]
    ) -> HomePauseTaskUpdate? {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return nil }
        guard !tasks[index].isOneOffTask else { return nil }
        guard !tasks[index].isArchived(referenceDate: pauseDate, calendar: calendar) else { return nil }

        if tasks[index].scheduleAnchor == nil {
            tasks[index].scheduleAnchor = RoutineDateMath.effectiveScheduleAnchor(
                for: tasks[index],
                referenceDate: pauseDate
            )
        }
        tasks[index].pausedAt = pauseDate
        return HomePauseTaskUpdate(taskID: taskID, pauseDate: pauseDate)
    }

    static func resumeTask(
        taskID: UUID,
        resumeDate: Date,
        calendar: Calendar,
        tasks: inout [RoutineTask]
    ) -> HomeResumeTaskUpdate? {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return nil }
        guard !tasks[index].isOneOffTask else { return nil }
        guard tasks[index].isArchived(referenceDate: resumeDate, calendar: calendar) else { return nil }

        tasks[index].scheduleAnchor = RoutineDateMath.resumedScheduleAnchor(
            for: tasks[index],
            resumedAt: resumeDate
        )
        tasks[index].pausedAt = nil
        tasks[index].snoozedUntil = nil
        return HomeResumeTaskUpdate(taskID: taskID, resumeDate: resumeDate)
    }

    static func notTodayTask(
        taskID: UUID,
        referenceDate: Date,
        calendar: Calendar,
        tasks: inout [RoutineTask]
    ) -> HomeSnoozeTaskUpdate? {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return nil }
        guard !tasks[index].isOneOffTask else { return nil }
        guard !tasks[index].isArchived(referenceDate: referenceDate, calendar: calendar) else { return nil }

        let tomorrowStart = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: referenceDate)
        ) ?? referenceDate
        tasks[index].snoozedUntil = tomorrowStart
        return HomeSnoozeTaskUpdate(taskID: taskID, snoozedUntil: tomorrowStart)
    }

    static func pinTask(
        taskID: UUID,
        pinnedAt: Date,
        tasks: inout [RoutineTask]
    ) -> HomePinTaskUpdate? {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return nil }
        guard tasks[index].pinnedAt == nil else { return nil }

        tasks[index].pinnedAt = pinnedAt
        return HomePinTaskUpdate(taskID: taskID, pinnedAt: pinnedAt)
    }

    static func planTask(
        taskID: UUID,
        plannedDate: Date?,
        calendar: Calendar,
        tasks: inout [RoutineTask]
    ) -> HomePlanTaskUpdate? {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return nil }
        guard tasks[index].supportsStoredPlanning else { return nil }

        let normalizedDate = RoutineTask.effectivePlannedDate(
            plannedDate: plannedDate,
            scheduleMode: tasks[index].scheduleMode,
            availabilityStartDate: tasks[index].availabilityStartDate,
            availabilityEndDate: tasks[index].availabilityEndDate,
            calendar: calendar
        )
        let customTaskSectionID = normalizedDate == nil ? tasks[index].customTaskSectionID : nil
        guard tasks[index].plannedDate != normalizedDate
            || tasks[index].customTaskSectionID != customTaskSectionID else { return nil }

        tasks[index].plannedDate = normalizedDate
        tasks[index].customTaskSectionID = customTaskSectionID
        return HomePlanTaskUpdate(
            taskID: taskID,
            plannedDate: normalizedDate,
            customTaskSectionID: customTaskSectionID
        )
    }

    static func deleteCustomTaskSection(
        sectionID: UUID,
        tasks: inout [RoutineTask]
    ) -> HomeDeleteCustomTaskSectionUpdate? {
        let sectionKey = HomeCustomTaskSectionStorage.manualOrderSectionKey(for: sectionID)
        var changedTaskIDs: [UUID] = []

        for index in tasks.indices {
            var manualSectionOrders = tasks[index].manualSectionOrders
            let removedManualOrder = manualSectionOrders.removeValue(forKey: sectionKey) != nil
            let removedSectionAssignment = tasks[index].customTaskSectionID == sectionID

            guard removedSectionAssignment || removedManualOrder else { continue }

            if removedSectionAssignment {
                tasks[index].customTaskSectionID = nil
            }
            tasks[index].manualSectionOrders = manualSectionOrders
            changedTaskIDs.append(tasks[index].id)
        }

        guard !changedTaskIDs.isEmpty else { return nil }
        return HomeDeleteCustomTaskSectionUpdate(
            sectionID: sectionID,
            sectionKey: sectionKey,
            taskIDs: changedTaskIDs
        )
    }

    static func unpinTask(
        taskID: UUID,
        tasks: inout [RoutineTask]
    ) -> HomeUnpinTaskUpdate? {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return nil }
        guard tasks[index].pinnedAt != nil else { return nil }

        tasks[index].pinnedAt = nil
        return HomeUnpinTaskUpdate(taskID: taskID)
    }

    private static func unresolvedMissedExactTimedOccurrenceDate(
        for task: RoutineTask,
        taskID: UUID,
        referenceDate: Date,
        calendar: Calendar,
        doneStats: HomeDoneStats
    ) -> Date? {
        let unresolvedDates = RoutineDateMath.unresolvedMissedExactTimedOccurrenceDates(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        ) { missedDate in
            doneStats.hasResolvedMissedDate(taskID: taskID, missedDate: missedDate, calendar: calendar)
        }

        if let referenceDayDate = unresolvedDates.first(where: {
            calendar.isDate($0, inSameDayAs: referenceDate)
        }) {
            return referenceDayDate
        }

        return unresolvedDates.first
    }

    private static func assumedTask(
        taskID: UUID,
        referenceDate: Date,
        calendar: Calendar,
        tasks: [RoutineTask],
        doneStats: HomeDoneStats
    ) -> RoutineTask? {
        guard let task = tasks.first(where: {
            $0.id == taskID && !$0.isArchived(referenceDate: referenceDate, calendar: calendar)
        }) else {
            return nil
        }
        let day = RoutineAssumedCompletion.currentOccurrenceDay(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        guard !doneStats.hasCompletedDate(taskID: taskID, date: day, calendar: calendar),
              !doneStats.hasResolvedMissedDate(taskID: taskID, missedDate: day, calendar: calendar),
              RoutineAssumedCompletion.isAssumedDone(
                for: task,
                on: day,
                referenceDate: referenceDate,
                calendar: calendar
              )
        else {
            return nil
        }
        return task
    }

    private static func removeDate(
        _ date: Date,
        for taskID: UUID,
        from datesByTaskID: inout [UUID: Set<Date>],
        calendar: Calendar
    ) {
        guard var dates = datesByTaskID[taskID] else { return }
        dates = dates.filter { !calendar.isDate($0, inSameDayAs: date) }
        if dates.isEmpty {
            datesByTaskID.removeValue(forKey: taskID)
        } else {
            datesByTaskID[taskID] = dates
        }
    }

    private static func fulfillLinkedTasks(
        from sourceTaskID: UUID,
        completedAt: Date,
        calendar: Calendar,
        tasks: inout [RoutineTask],
        doneStats: inout HomeDoneStats
    ) {
        guard let sourceTask = tasks.first(where: { $0.id == sourceTaskID }) else {
            return
        }

        for index in tasks.indices where tasks[index].id != sourceTaskID {
            let targetTaskID = tasks[index].id
            guard shouldFulfill(
                target: tasks[index],
                from: sourceTask,
                completedAt: completedAt,
                calendar: calendar
            ) else {
                continue
            }
            let fulfillmentDate: Date
            if tasks[index].recurrenceRule.usesAdvancedModel {
                let due = RoutineDateMath.dueDate(
                    for: tasks[index],
                    referenceDate: completedAt,
                    calendar: calendar
                )
                guard due != .distantFuture, due <= completedAt else { continue }
                fulfillmentDate = due
            } else {
                fulfillmentDate = completedAt
            }
            let alreadyResolved = doneStats.completedDatesByTaskID[targetTaskID]?.contains {
                if tasks[index].recurrenceRule.occursMoreThanOncePerDay {
                    return abs($0.timeIntervalSince(fulfillmentDate)) < 1
                }
                return calendar.isDate($0, inSameDayAs: fulfillmentDate)
            } ?? false
            guard !alreadyResolved else { continue }
            guard tasks[index].recordFulfillment(at: fulfillmentDate, calendar: calendar) else { continue }
            doneStats.completedDatesByTaskID[targetTaskID, default: []].insert(fulfillmentDate)
        }
    }

    private static func shouldFulfill(
        target: RoutineTask,
        from source: RoutineTask,
        completedAt: Date,
        calendar: Calendar
    ) -> Bool {
        guard target.canBeFulfilledByLinkedTask(referenceDate: completedAt, calendar: calendar) else {
            return false
        }
        let targetIsDoneWhenSource = target.relationships.contains { relationship in
            relationship.targetTaskID == source.id && relationship.kind == .doneWhen
        }
        let sourceCompletesTarget = source.relationships.contains { relationship in
            relationship.targetTaskID == target.id && relationship.kind == .completes
        }
        return targetIsDoneWhenSource || sourceCompletesTarget
    }
}
