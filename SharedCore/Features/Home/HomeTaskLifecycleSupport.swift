import Foundation

struct HomeChecklistPurchaseUpdate: Equatable {
    var taskID: UUID
    var completionDate: Date
}

struct HomeAdvanceTaskUpdate: Equatable {
    var taskID: UUID
    var completionDate: Date
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
        guard RoutineDateMath.canMarkDone(
            for: tasks[index],
            referenceDate: referenceDate,
            calendar: calendar
        ) else {
            return nil
        }

        if tasks[index].isChecklistDriven {
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

        let result = tasks[index].advance(completedAt: referenceDate, calendar: calendar)
        if case .completedRoutine = result {
            doneStats.totalCount += 1
            doneStats.countsByTaskID[taskID, default: 0] += 1
        }
        return .advance(
            HomeAdvanceTaskUpdate(
                taskID: taskID,
                completionDate: referenceDate
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
}
