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

struct HomePauseTasksUpdate: Equatable {
    var taskIDs: [UUID]
    var pauseDate: Date
}

struct HomeResumeTasksUpdate: Equatable {
    var taskIDs: [UUID]
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
        guard
            let index = tasks.firstIndex(where: {
                $0.id == taskID && !$0.isArchived(referenceDate: referenceDate, calendar: calendar)
            })
        else {
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
            guard
                RoutineDateMath.canMarkDone(
                    for: tasks[index],
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            else {
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
        } else if RoutineDateMath.usesExactTimedOccurrences(for: task) {
            return nil
        } else {
            completionDate = referenceDate
        }

        if RoutineDateMath.usesExactTimedOccurrences(for: task) {
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
                        task: task,
                        calendar: calendar
                    )
            }
            let isSelectedMissedDate = missedDates.contains {
                calendar.isDate($0, inSameDayAs: completionDate)
            }
            let isReferenceDayMissedDate =
                isSelectedMissedDate
                && calendar.isDate(completionDate, inSameDayAs: referenceDate)
            guard (!hasUnresolvedPriorMissedDate || isReferenceDayMissedDate),
                isSelectedMissedDate
                    || RoutineDateMath.canMarkDone(
                        for: task,
                        referenceDate: completionDate,
                        calendar: calendar
                    )
            else {
                return nil
            }
        } else {
            guard
                RoutineDateMath.canMarkDone(
                    for: task,
                    referenceDate: completionDate,
                    calendar: calendar
                )
            else {
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
                previousTodoStateTitle != TodoState.done.displayTitle
            {
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

    static func pauseTask(
        taskID: UUID,
        pauseDate: Date,
        calendar: Calendar,
        tasks: inout [RoutineTask]
    ) -> HomePauseTaskUpdate? {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return nil }
        guard
            !tasks[index].isOneOffTask
                || (!tasks[index].isCompletedOneOff && !tasks[index].isCanceledOneOff)
        else { return nil }
        guard !tasks[index].isArchived(referenceDate: pauseDate, calendar: calendar) else { return nil }

        if !tasks[index].isOneOffTask, tasks[index].scheduleAnchor == nil {
            tasks[index].scheduleAnchor = RoutineDateMath.effectiveScheduleAnchor(
                for: tasks[index],
                referenceDate: pauseDate
            )
        }
        tasks[index].pausedAt = pauseDate
        tasks[index].pauseUntil = nil
        return HomePauseTaskUpdate(taskID: taskID, pauseDate: pauseDate)
    }

    static func resumeTask(
        taskID: UUID,
        resumeDate: Date,
        calendar: Calendar,
        tasks: inout [RoutineTask]
    ) -> HomeResumeTaskUpdate? {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return nil }
        guard tasks[index].isArchived(referenceDate: resumeDate, calendar: calendar) else { return nil }

        if !tasks[index].isOneOffTask {
            tasks[index].scheduleAnchor = RoutineDateMath.resumedScheduleAnchor(
                for: tasks[index],
                resumedAt: resumeDate
            )
        }
        tasks[index].pausedAt = nil
        tasks[index].pauseUntil = nil
        tasks[index].snoozedUntil = nil
        return HomeResumeTaskUpdate(taskID: taskID, resumeDate: resumeDate)
    }

    static func pauseTasks(
        taskIDs: [UUID],
        pauseDate: Date,
        calendar: Calendar,
        tasks: inout [RoutineTask]
    ) -> HomePauseTasksUpdate? {
        let updates = HomeCustomTaskSectionStorage.deduplicatedTaskIDs(taskIDs).compactMap { taskID in
            pauseTask(
                taskID: taskID,
                pauseDate: pauseDate,
                calendar: calendar,
                tasks: &tasks
            )
        }
        guard !updates.isEmpty else { return nil }
        return HomePauseTasksUpdate(taskIDs: updates.map(\.taskID), pauseDate: pauseDate)
    }

    static func resumeTasks(
        taskIDs: [UUID],
        resumeDate: Date,
        calendar: Calendar,
        tasks: inout [RoutineTask]
    ) -> HomeResumeTasksUpdate? {
        let updates = HomeCustomTaskSectionStorage.deduplicatedTaskIDs(taskIDs).compactMap { taskID in
            resumeTask(
                taskID: taskID,
                resumeDate: resumeDate,
                calendar: calendar,
                tasks: &tasks
            )
        }
        guard !updates.isEmpty else { return nil }
        return HomeResumeTasksUpdate(taskIDs: updates.map(\.taskID), resumeDate: resumeDate)
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

        let tomorrowStart =
            calendar.date(
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
        let customTaskSectionID = tasks[index].customTaskSectionID
        guard tasks[index].plannedDate != normalizedDate else { return nil }

        tasks[index].plannedDate = normalizedDate
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
            guard
                shouldFulfill(
                    target: tasks[index],
                    from: sourceTask,
                    completedAt: completedAt,
                    calendar: calendar
                )
            else {
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
            let alreadyResolved =
                doneStats.completedDatesByTaskID[targetTaskID]?.contains {
                    RoutineOccurrenceIdentity.matches(
                        $0,
                        fulfillmentDate,
                        for: tasks[index],
                        calendar: calendar
                    )
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
