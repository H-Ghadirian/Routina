import Foundation

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
extension HomeTaskLifecycleSupport {
    static func markTaskMissed(
        taskID: UUID,
        referenceDate: Date,
        calendar: Calendar,
        tasks: [RoutineTask],
        doneStats: inout HomeDoneStats
    ) -> HomeMarkTaskMissedUpdate? {
        guard
            let task = tasks.first(where: {
                $0.id == taskID && !$0.isArchived(referenceDate: referenceDate, calendar: calendar)
            })
        else {
            return nil
        }
        guard
            let missedDate = unresolvedMissedExactTimedOccurrenceDate(
                for: task,
                taskID: taskID,
                referenceDate: referenceDate,
                calendar: calendar,
                doneStats: doneStats
            )
        else {
            return nil
        }

        let hadCanceledResolution =
            doneStats.canceledDatesByTaskID[taskID]?.contains {
                RoutineOccurrenceIdentity.matches($0, missedDate, for: task, calendar: calendar)
            } ?? false
        doneStats.missedDatesByTaskID[taskID, default: []].insert(missedDate)
        removeDate(
            missedDate,
            for: task,
            taskID: taskID,
            from: &doneStats.canceledDatesByTaskID,
            calendar: calendar
        )
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
        guard
            let task = assumedTask(
                taskID: taskID,
                referenceDate: referenceDate,
                calendar: calendar,
                tasks: tasks,
                doneStats: doneStats
            )
        else {
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
        removeDate(
            completionDate,
            for: task,
            taskID: taskID,
            from: &doneStats.missedDatesByTaskID,
            calendar: calendar
        )
        removeDate(
            completionDate,
            for: task,
            taskID: taskID,
            from: &doneStats.canceledDatesByTaskID,
            calendar: calendar
        )
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
        guard
            let task = assumedTask(
                taskID: taskID,
                referenceDate: referenceDate,
                calendar: calendar,
                tasks: tasks,
                doneStats: doneStats
            )
        else {
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
        removeDate(
            missedDate,
            for: task,
            taskID: taskID,
            from: &doneStats.canceledDatesByTaskID,
            calendar: calendar
        )
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
        guard
            let task = tasks.first(where: {
                $0.id == taskID && !$0.isArchived(referenceDate: referenceDate, calendar: calendar)
            })
        else {
            return nil
        }
        guard
            let canceledDate = unresolvedMissedExactTimedOccurrenceDate(
                for: task,
                taskID: taskID,
                referenceDate: referenceDate,
                calendar: calendar,
                doneStats: doneStats
            )
        else {
            return nil
        }

        let alreadyCanceled =
            doneStats.canceledDatesByTaskID[taskID]?.contains {
                RoutineOccurrenceIdentity.matches($0, canceledDate, for: task, calendar: calendar)
            } ?? false
        if !alreadyCanceled {
            doneStats.canceledTotalCount += 1
            doneStats.canceledCountsByTaskID[taskID, default: 0] += 1
        }
        doneStats.canceledDatesByTaskID[taskID, default: []].insert(canceledDate)
        removeDate(
            canceledDate,
            for: task,
            taskID: taskID,
            from: &doneStats.missedDatesByTaskID,
            calendar: calendar
        )

        return HomeMarkTaskCanceledUpdate(taskID: taskID, canceledDate: canceledDate, referenceDate: referenceDate)
    }

    static func unresolvedMissedExactTimedOccurrenceDate(
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
            doneStats.hasResolvedMissedDate(
                taskID: taskID,
                missedDate: missedDate,
                task: task,
                calendar: calendar
            )
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
        guard
            let task = tasks.first(where: {
                $0.id == taskID && !$0.isArchived(referenceDate: referenceDate, calendar: calendar)
            })
        else {
            return nil
        }
        let day = RoutineAssumedCompletion.currentOccurrenceDay(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        guard !doneStats.hasCompletedDate(taskID: taskID, date: day, task: task, calendar: calendar),
            !doneStats.hasResolvedMissedDate(
                taskID: taskID,
                missedDate: day,
                task: task,
                calendar: calendar
            ),
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
        for task: RoutineTask,
        taskID: UUID,
        from datesByTaskID: inout [UUID: Set<Date>],
        calendar: Calendar
    ) {
        guard var dates = datesByTaskID[taskID] else { return }
        dates = dates.filter {
            !RoutineOccurrenceIdentity.matches($0, date, for: task, calendar: calendar)
        }
        if dates.isEmpty {
            datesByTaskID.removeValue(forKey: taskID)
        } else {
            datesByTaskID[taskID] = dates
        }
    }

}
