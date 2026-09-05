import ComposableArchitecture
import Foundation
import SwiftData

enum HomeTaskLifecycleExecutionSupport {
    static func markChecklistItemsDone<Action>(
        _ update: HomeChecklistRunoutDoneUpdate,
        calendar: Calendar,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        scheduleNotification: @escaping @Sendable (NotificationPayload) async -> Void
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard
                    let taskState = try RoutineLogHistory.markDueChecklistItemsDone(
                        taskID: update.taskID,
                        doneAt: update.completionDate,
                        context: context,
                        calendar: calendar
                    )
                else {
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
                RoutinaLog.error("Failed to update checklist routine from home list: \(error)")
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
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard
                    let taskState = try RoutineLogHistory.advanceTask(
                        taskID: update.taskID,
                        completedAt: update.completionDate,
                        context: context,
                        calendar: calendar
                    )
                else {
                    return
                }
                if taskState.task.isOneOffTask,
                    taskState.result == .completedRoutine,
                    update.previousTodoStateTitle != TodoState.done.displayTitle
                {
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
                RoutinaLog.error("Failed to mark routine as done from home list: \(error)")
            }
        }
    }

    static func markTaskMissed<Action>(
        _ update: HomeMarkTaskMissedUpdate,
        calendar: Calendar,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        cancelNotification: @escaping @Sendable (String) async -> Void,
        scheduleNotification: @escaping @Sendable (NotificationPayload) async -> Void
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard
                    let task = try RoutineLogHistory.markExactTimedOccurrenceMissed(
                        taskID: update.taskID,
                        missedAt: update.missedDate,
                        context: context,
                        calendar: calendar
                    )
                else {
                    return
                }
                if !NotificationCoordinator.shouldScheduleNotification(
                    for: task,
                    referenceDate: update.referenceDate,
                    calendar: calendar
                ) {
                    await cancelNotification(update.taskID.uuidString)
                } else {
                    await scheduleNotification(
                        NotificationCoordinator.notificationPayload(
                            for: task,
                            referenceDate: update.referenceDate,
                            calendar: calendar
                        )
                    )
                }
                WidgetStatsService.refreshAndReload(using: context)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Failed to mark exact-time routine as missed from home list: \(error)")
            }
        }
    }

    static func confirmAssumedTaskDone<Action>(
        _ update: HomeResolveAssumedTaskUpdate,
        calendar: Calendar,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        cancelNotification: @escaping @Sendable (String) async -> Void,
        scheduleNotification: @escaping @Sendable (NotificationPayload) async -> Void
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard
                    let task = try RoutineLogHistory.confirmTaskCompletions(
                        taskID: update.taskID,
                        on: [update.resolutionDate],
                        context: context,
                        referenceDate: update.referenceDate,
                        calendar: calendar
                    )
                else {
                    return
                }
                if !NotificationCoordinator.shouldScheduleNotification(
                    for: task,
                    referenceDate: update.referenceDate,
                    calendar: calendar
                ) {
                    await cancelNotification(update.taskID.uuidString)
                } else {
                    await scheduleNotification(
                        NotificationCoordinator.notificationPayload(
                            for: task,
                            referenceDate: update.referenceDate,
                            calendar: calendar
                        )
                    )
                }
                WidgetStatsService.refreshAndReload(using: context)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Failed to confirm assumed task from home list: \(error)")
            }
        }
    }

    static func markAssumedTaskMissed<Action>(
        _ update: HomeResolveAssumedTaskUpdate,
        calendar: Calendar,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        cancelNotification: @escaping @Sendable (String) async -> Void,
        scheduleNotification: @escaping @Sendable (NotificationPayload) async -> Void
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard
                    let task = try RoutineLogHistory.markAssumedCompletionMissed(
                        taskID: update.taskID,
                        on: update.resolutionDate,
                        context: context,
                        referenceDate: update.referenceDate,
                        calendar: calendar
                    )
                else {
                    return
                }
                if !NotificationCoordinator.shouldScheduleNotification(
                    for: task,
                    referenceDate: update.referenceDate,
                    calendar: calendar
                ) {
                    await cancelNotification(update.taskID.uuidString)
                } else {
                    await scheduleNotification(
                        NotificationCoordinator.notificationPayload(
                            for: task,
                            referenceDate: update.referenceDate,
                            calendar: calendar
                        )
                    )
                }
                WidgetStatsService.refreshAndReload(using: context)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Failed to mark assumed task as missed from home list: \(error)")
            }
        }
    }

    static func markTaskCanceled<Action>(
        _ update: HomeMarkTaskCanceledUpdate,
        calendar: Calendar,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        cancelNotification: @escaping @Sendable (String) async -> Void,
        scheduleNotification: @escaping @Sendable (NotificationPayload) async -> Void
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard
                    let task = try RoutineLogHistory.markExactTimedOccurrenceCanceled(
                        taskID: update.taskID,
                        canceledAt: update.canceledDate,
                        context: context,
                        calendar: calendar
                    )
                else {
                    return
                }
                if !NotificationCoordinator.shouldScheduleNotification(
                    for: task,
                    referenceDate: update.referenceDate,
                    calendar: calendar
                ) {
                    await cancelNotification(update.taskID.uuidString)
                } else {
                    await scheduleNotification(
                        NotificationCoordinator.notificationPayload(
                            for: task,
                            referenceDate: update.referenceDate,
                            calendar: calendar
                        )
                    )
                }
                WidgetStatsService.refreshAndReload(using: context)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Failed to mark exact-time routine occurrence as canceled from home list: \(error)")
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
                DeviceActivityRecorder.recordAction(
                    .updated,
                    entity: .task,
                    entityID: update.taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    details: "Pinned task",
                    at: update.pinnedAt,
                    in: context
                )
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Failed to pin routine from home list: \(error)")
            }
        }
    }

    static func planTask<Action>(
        _ update: HomePlanTaskUpdate,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(HomeTaskSupport.taskDescriptor(for: update.taskID)).first else {
                    return
                }
                task.plannedDate = update.plannedDate
                task.customTaskSectionID = update.customTaskSectionID
                DeviceActivityRecorder.recordAction(
                    .updated,
                    entity: .task,
                    entityID: update.taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    details: update.plannedDate == nil ? "Cleared task plan" : "Planned task",
                    in: context
                )
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Failed to plan routine from home list: \(error)")
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
                DeviceActivityRecorder.recordAction(
                    .updated,
                    entity: .task,
                    entityID: update.taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    details: "Unpinned task",
                    in: context
                )
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Failed to unpin routine from home list: \(error)")
            }
        }
    }
}
