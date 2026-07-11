import ComposableArchitecture
import Foundation
import SwiftData

struct HomeTaskLifecycleCoordinator<Action> {
    var referenceDate: @Sendable () -> Date
    var calendar: Calendar
    var modelContext: @MainActor @Sendable () -> ModelContext
    var cancelNotification: @Sendable (String) async -> Void
    var scheduleNotification: @Sendable (NotificationPayload) async -> Void

    func markTaskDone(
        taskID: UUID,
        tasks: inout [RoutineTask],
        doneStats: inout HomeDoneStats
    ) -> Effect<Action>? {
        let date = referenceDate()
        guard let update = HomeTaskLifecycleSupport.markTaskDone(
            taskID: taskID,
            referenceDate: date,
            calendar: calendar,
            tasks: &tasks,
            doneStats: &doneStats
        ) else {
            return nil
        }

        switch update {
        case let .checklist(checklistUpdate):
            return HomeTaskLifecycleExecutionSupport.markChecklistItemsDone(
                checklistUpdate,
                calendar: calendar,
                modelContext: modelContext,
                scheduleNotification: scheduleNotification
            )

        case let .advance(advanceUpdate):
            return HomeTaskLifecycleExecutionSupport.advanceTask(
                advanceUpdate,
                calendar: calendar,
                modelContext: modelContext,
                cancelNotification: cancelNotification,
                scheduleNotification: scheduleNotification
            )
        }
    }

    func markTaskMissed(
        taskID: UUID,
        tasks: [RoutineTask],
        doneStats: inout HomeDoneStats
    ) -> Effect<Action>? {
        guard let update = HomeTaskLifecycleSupport.markTaskMissed(
            taskID: taskID,
            referenceDate: referenceDate(),
            calendar: calendar,
            tasks: tasks,
            doneStats: &doneStats
        ) else {
            return nil
        }

        return HomeTaskLifecycleExecutionSupport.markTaskMissed(
            update,
            calendar: calendar,
            modelContext: modelContext,
            cancelNotification: cancelNotification,
            scheduleNotification: scheduleNotification
        )
    }

    func confirmAssumedTaskDone(
        taskID: UUID,
        tasks: [RoutineTask],
        doneStats: inout HomeDoneStats
    ) -> Effect<Action>? {
        let referenceDate = referenceDate()
        guard let update = HomeTaskLifecycleSupport.confirmAssumedTaskDone(
            taskID: taskID,
            referenceDate: referenceDate,
            calendar: calendar,
            tasks: tasks,
            doneStats: &doneStats
        ) else {
            return nil
        }

        return HomeTaskLifecycleExecutionSupport.confirmAssumedTaskDone(
            update,
            calendar: calendar,
            modelContext: modelContext,
            cancelNotification: cancelNotification,
            scheduleNotification: scheduleNotification
        )
    }

    func markAssumedTaskMissed(
        taskID: UUID,
        tasks: [RoutineTask],
        doneStats: inout HomeDoneStats
    ) -> Effect<Action>? {
        let referenceDate = referenceDate()
        guard let update = HomeTaskLifecycleSupport.markAssumedTaskMissed(
            taskID: taskID,
            referenceDate: referenceDate,
            calendar: calendar,
            tasks: tasks,
            doneStats: &doneStats
        ) else {
            return nil
        }

        return HomeTaskLifecycleExecutionSupport.markAssumedTaskMissed(
            update,
            calendar: calendar,
            modelContext: modelContext,
            cancelNotification: cancelNotification,
            scheduleNotification: scheduleNotification
        )
    }

    func markTaskCanceled(
        taskID: UUID,
        tasks: [RoutineTask],
        doneStats: inout HomeDoneStats
    ) -> Effect<Action>? {
        guard let update = HomeTaskLifecycleSupport.markTaskCanceled(
            taskID: taskID,
            referenceDate: referenceDate(),
            calendar: calendar,
            tasks: tasks,
            doneStats: &doneStats
        ) else {
            return nil
        }

        return HomeTaskLifecycleExecutionSupport.markTaskCanceled(
            update,
            calendar: calendar,
            modelContext: modelContext,
            cancelNotification: cancelNotification,
            scheduleNotification: scheduleNotification
        )
    }

    func pauseTask(
        taskID: UUID,
        tasks: inout [RoutineTask]
    ) -> Effect<Action>? {
        guard let update = HomeTaskLifecycleSupport.pauseTask(
            taskID: taskID,
            pauseDate: referenceDate(),
            calendar: calendar,
            tasks: &tasks
        ) else {
            return nil
        }

        return HomeTaskLifecycleExecutionSupport.pauseTask(
            update,
            modelContext: modelContext,
            cancelNotification: cancelNotification
        )
    }

    func resumeTask(
        taskID: UUID,
        tasks: inout [RoutineTask]
    ) -> Effect<Action>? {
        guard let update = HomeTaskLifecycleSupport.resumeTask(
            taskID: taskID,
            resumeDate: referenceDate(),
            calendar: calendar,
            tasks: &tasks
        ) else {
            return nil
        }

        return HomeTaskLifecycleExecutionSupport.resumeTask(
            update,
            calendar: calendar,
            modelContext: modelContext,
            cancelNotification: cancelNotification,
            scheduleNotification: scheduleNotification
        )
    }

    func notTodayTask(
        taskID: UUID,
        tasks: inout [RoutineTask]
    ) -> Effect<Action>? {
        guard let update = HomeTaskLifecycleSupport.notTodayTask(
            taskID: taskID,
            referenceDate: referenceDate(),
            calendar: calendar,
            tasks: &tasks
        ) else {
            return nil
        }

        return HomeTaskLifecycleExecutionSupport.notTodayTask(
            update,
            calendar: calendar,
            modelContext: modelContext,
            cancelNotification: cancelNotification,
            scheduleNotification: scheduleNotification
        )
    }

    func pinTask(
        taskID: UUID,
        tasks: inout [RoutineTask]
    ) -> Effect<Action>? {
        guard let update = HomeTaskLifecycleSupport.pinTask(
            taskID: taskID,
            pinnedAt: referenceDate(),
            tasks: &tasks
        ) else {
            return nil
        }

        return HomeTaskLifecycleExecutionSupport.pinTask(
            update,
            modelContext: modelContext
        )
    }

    func planTask(
        taskID: UUID,
        plannedDate: Date?,
        tasks: inout [RoutineTask]
    ) -> Effect<Action>? {
        guard let update = HomeTaskLifecycleSupport.planTask(
            taskID: taskID,
            plannedDate: plannedDate,
            calendar: calendar,
            tasks: &tasks
        ) else {
            return nil
        }

        return HomeTaskLifecycleExecutionSupport.planTask(
            update,
            modelContext: modelContext
        )
    }

    func unpinTask(
        taskID: UUID,
        tasks: inout [RoutineTask]
    ) -> Effect<Action>? {
        guard let update = HomeTaskLifecycleSupport.unpinTask(
            taskID: taskID,
            tasks: &tasks
        ) else {
            return nil
        }

        return HomeTaskLifecycleExecutionSupport.unpinTask(
            update,
            modelContext: modelContext
        )
    }
}
