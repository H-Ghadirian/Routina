import Foundation

struct HomeChecklistPurchaseUpdate: Equatable {
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

struct HomeUnpinTaskUpdate: Equatable {
    var taskID: UUID
}

struct HomeMarkTaskMissedUpdate: Equatable {
    var taskID: UUID
    var missedDate: Date
    var referenceDate: Date
}

struct HomeMarkTaskCanceledUpdate: Equatable {
    var taskID: UUID
    var canceledDate: Date
    var referenceDate: Date
}

enum HomeMarkTaskDoneUpdate: Equatable {
    case checklist(HomeChecklistPurchaseUpdate)
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
            let hadCompletionToday = tasks[index].lastDone.map {
                calendar.isDate($0, inSameDayAs: referenceDate)
            } ?? false
            let dueItemIDs = Set(
                tasks[index]
                    .dueChecklistItems(referenceDate: referenceDate, calendar: calendar)
                    .map(\.id)
            )
            let updatedItemCount = tasks[index].markChecklistItemsPurchased(
                dueItemIDs,
                purchasedAt: referenceDate
            )
            guard updatedItemCount > 0 else { return nil }
            if !hadCompletionToday {
                doneStats.totalCount += 1
                doneStats.countsByTaskID[taskID, default: 0] += 1
            }
            return .checklist(
                HomeChecklistPurchaseUpdate(
                    taskID: taskID,
                    completionDate: referenceDate
                )
            )
        }

        let completionDate: Date
        if let missedDate = RoutineDateMath.missedExactTimedOccurrenceDate(
            for: tasks[index],
            referenceDate: referenceDate,
            calendar: calendar
        ) {
            completionDate = missedDate
        } else if let exactTimedTarget = RoutineDateMath.completionTargetDate(
            for: tasks[index],
            selectedDay: referenceDate,
            referenceDate: referenceDate,
            calendar: calendar
        ) {
            completionDate = exactTimedTarget
        } else if RoutineDateMath.usesExactTimedOccurrenceTracking(for: tasks[index]) {
            return nil
        } else {
            completionDate = referenceDate
        }

        guard RoutineDateMath.canMarkDone(
            for: tasks[index],
            referenceDate: completionDate,
            calendar: calendar
        ) else {
            return nil
        }

        let previousTodoStateTitle = tasks[index].isOneOffTask ? tasks[index].todoState?.displayTitle : nil
        let result = tasks[index].advance(completedAt: completionDate, calendar: calendar)
        if case .completedRoutine = result {
            doneStats.totalCount += 1
            doneStats.countsByTaskID[taskID, default: 0] += 1
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
        guard let missedDate = RoutineDateMath.missedExactTimedOccurrenceDate(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
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
        guard let canceledDate = RoutineDateMath.missedExactTimedOccurrenceDate(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
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

    static func unpinTask(
        taskID: UUID,
        tasks: inout [RoutineTask]
    ) -> HomeUnpinTaskUpdate? {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return nil }
        guard tasks[index].pinnedAt != nil else { return nil }

        tasks[index].pinnedAt = nil
        return HomeUnpinTaskUpdate(taskID: taskID)
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
}
