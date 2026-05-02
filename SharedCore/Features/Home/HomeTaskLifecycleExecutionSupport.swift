import ComposableArchitecture
import Foundation
import SwiftData

enum HomeTaskLifecycleExecutionSupport {
    static func markChecklistItemsPurchased<Action>(
        _ update: HomeChecklistPurchaseUpdate,
        calendar: Calendar,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        scheduleNotification: @escaping @Sendable (NotificationPayload) async -> Void
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = ModelContext(modelContext().container)
                guard let taskState = try RoutineLogHistory.markDueChecklistItemsPurchased(
                    taskID: update.taskID,
                    purchasedAt: update.completionDate,
                    context: context,
                    calendar: calendar
                ) else {
                    return
                }
                if NotificationCoordinator.shouldScheduleNotification(
                    for: taskState.task,
                    referenceDate: update.completionDate,
                    calendar: calendar
                ) {
                    await scheduleNotification(
                        NotificationCoordinator.notificationPayload(
                            for: taskState.task,
                            referenceDate: update.completionDate,
                            calendar: calendar
                        )
                    )
                }
                WidgetStatsService.refreshAndReload(using: context)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Failed to update checklist routine from home list: \(error)")
            }
        }
    }

    static func advanceTask<Action>(
        _ update: HomeAdvanceTaskUpdate,
        calendar: Calendar,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        cancelNotification: @escaping @Sendable (String) async -> Void,
        scheduleNotification: @escaping @Sendable (NotificationPayload) async -> Void
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = ModelContext(modelContext().container)
                guard let taskState = try RoutineLogHistory.advanceTask(
                    taskID: update.taskID,
                    completedAt: update.completionDate,
                    context: context,
                    calendar: calendar
                ) else {
                    return
                }
                if taskState.task.isOneOffTask,
                   taskState.result == .completedRoutine,
                   update.previousTodoStateTitle != TodoState.done.displayTitle {
                    taskState.task.appendChangeLogEntry(
                        RoutineTaskChangeLogEntry(
                            timestamp: update.completionDate,
                            kind: .stateChanged,
                            previousValue: update.previousTodoStateTitle,
                            newValue: TodoState.done.displayTitle
                        )
                    )
                    try context.save()
                }
                if !NotificationCoordinator.shouldScheduleNotification(
                    for: taskState.task,
                    referenceDate: update.completionDate,
                    calendar: calendar
                ) {
                    await cancelNotification(update.taskID.uuidString)
                } else {
                    await scheduleNotification(
                        NotificationCoordinator.notificationPayload(
                            for: taskState.task,
                            referenceDate: update.completionDate,
                            calendar: calendar
                        )
                    )
                }
                WidgetStatsService.refreshAndReload(using: context)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Failed to mark routine as done from home list: \(error)")
            }
        }
    }

    static func pauseTask<Action>(
        _ update: HomePauseTaskUpdate,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        cancelNotification: @escaping @Sendable (String) async -> Void
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(HomeTaskSupport.taskDescriptor(for: update.taskID)).first else {
                    return
                }
                if task.scheduleAnchor == nil {
                    task.scheduleAnchor = RoutineDateMath.effectiveScheduleAnchor(
                        for: task,
                        referenceDate: update.pauseDate
                    )
                }
                task.pausedAt = update.pauseDate
                try context.save()
                await cancelNotification(update.taskID.uuidString)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Failed to pause routine from home list: \(error)")
            }
        }
    }

    static func resumeTask<Action>(
        _ update: HomeResumeTaskUpdate,
        calendar: Calendar,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        cancelNotification: @escaping @Sendable (String) async -> Void,
        scheduleNotification: @escaping @Sendable (NotificationPayload) async -> Void
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(HomeTaskSupport.taskDescriptor(for: update.taskID)).first else {
                    return
                }
                task.scheduleAnchor = RoutineDateMath.resumedScheduleAnchor(
                    for: task,
                    resumedAt: update.resumeDate
                )
                task.pausedAt = nil
                task.snoozedUntil = nil
                try context.save()
                if NotificationCoordinator.shouldScheduleNotification(
                    for: task,
                    referenceDate: update.resumeDate,
                    calendar: calendar
                ) {
                    await scheduleNotification(
                        NotificationCoordinator.notificationPayload(
                            for: task,
                            referenceDate: update.resumeDate,
                            calendar: calendar
                        )
                    )
                } else {
                    await cancelNotification(update.taskID.uuidString)
                }
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Failed to resume routine from home list: \(error)")
            }
        }
    }

    static func notTodayTask<Action>(
        _ update: HomeSnoozeTaskUpdate,
        calendar: Calendar,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        cancelNotification: @escaping @Sendable (String) async -> Void,
        scheduleNotification: @escaping @Sendable (NotificationPayload) async -> Void
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(HomeTaskSupport.taskDescriptor(for: update.taskID)).first else {
                    return
                }
                task.snoozedUntil = update.snoozedUntil
                try context.save()
                if NotificationCoordinator.shouldScheduleNotification(
                    for: task,
                    referenceDate: update.snoozedUntil,
                    calendar: calendar
                ) {
                    await scheduleNotification(
                        NotificationCoordinator.notificationPayload(
                            for: task,
                            triggerDate: NotificationPreferences.reminderDate(
                                on: update.snoozedUntil,
                                calendar: calendar
                            ),
                            isArchivedOverride: false,
                            referenceDate: update.snoozedUntil,
                            calendar: calendar
                        )
                    )
                } else {
                    await cancelNotification(update.taskID.uuidString)
                }
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Failed to archive routine for today from home list: \(error)")
            }
        }
    }

    static func pinTask<Action>(
        _ update: HomePinTaskUpdate,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(HomeTaskSupport.taskDescriptor(for: update.taskID)).first else {
                    return
                }
                task.pinnedAt = update.pinnedAt
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Failed to pin routine from home list: \(error)")
            }
        }
    }

    static func unpinTask<Action>(
        _ update: HomeUnpinTaskUpdate,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(HomeTaskSupport.taskDescriptor(for: update.taskID)).first else {
                    return
                }
                task.pinnedAt = nil
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Failed to unpin routine from home list: \(error)")
            }
        }
    }
}
