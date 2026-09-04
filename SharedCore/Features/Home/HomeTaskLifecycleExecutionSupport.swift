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
                guard let taskState = try RoutineLogHistory.markDueChecklistItemsDone(
                    taskID: update.taskID,
                    doneAt: update.completionDate,
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
                guard let task = try RoutineLogHistory.markExactTimedOccurrenceMissed(
                    taskID: update.taskID,
                    missedAt: update.missedDate,
                    context: context,
                    calendar: calendar
                ) else {
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
                guard let task = try RoutineLogHistory.confirmTaskCompletions(
                    taskID: update.taskID,
                    on: [update.resolutionDate],
                    context: context,
                    referenceDate: update.referenceDate,
                    calendar: calendar
                ) else {
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
                guard let task = try RoutineLogHistory.markAssumedCompletionMissed(
                    taskID: update.taskID,
                    on: update.resolutionDate,
                    context: context,
                    referenceDate: update.referenceDate,
                    calendar: calendar
                ) else {
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
                guard let task = try RoutineLogHistory.markExactTimedOccurrenceCanceled(
                    taskID: update.taskID,
                    canceledAt: update.canceledDate,
                    context: context,
                    calendar: calendar
                ) else {
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

    static func pauseTask<Action>(
        _ update: HomePauseTaskUpdate,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        cancelNotification: @escaping @Sendable (String) async -> Void
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard let task = try context.fetch(HomeTaskSupport.taskDescriptor(for: update.taskID)).first else {
                    return
                }
                guard !task.isOneOffTask || (!task.isCompletedOneOff && !task.isCanceledOneOff) else {
                    return
                }
                if !task.isOneOffTask, task.scheduleAnchor == nil {
                    task.scheduleAnchor = RoutineDateMath.effectiveScheduleAnchor(
                        for: task,
                        referenceDate: update.pauseDate
                    )
                }
                task.pausedAt = update.pauseDate
                task.pauseUntil = nil
                DeviceActivityRecorder.recordAction(
                    .paused,
                    entity: .task,
                    entityID: update.taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    at: update.pauseDate,
                    in: context
                )
                try context.save()
                await cancelNotification(update.taskID.uuidString)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Failed to pause routine from home list: \(error)")
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
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard let task = try context.fetch(HomeTaskSupport.taskDescriptor(for: update.taskID)).first else {
                    return
                }
                if !task.isOneOffTask {
                    task.scheduleAnchor = RoutineDateMath.resumedScheduleAnchor(
                        for: task,
                        resumedAt: update.resumeDate
                    )
                }
                task.pausedAt = nil
                task.pauseUntil = nil
                task.snoozedUntil = nil
                DeviceActivityRecorder.recordAction(
                    .resumed,
                    entity: .task,
                    entityID: update.taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    at: update.resumeDate,
                    in: context
                )
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
                RoutinaLog.error("Failed to resume routine from home list: \(error)")
            }
        }
    }

    static func pauseTasks<Action>(
        _ update: HomePauseTasksUpdate,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        cancelNotification: @escaping @Sendable (String) async -> Void
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                let taskIDs = Set(update.taskIDs)
                let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                    .filter { taskIDs.contains($0.id) }
                var tasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })

                for taskID in update.taskIDs {
                    guard let task = tasksByID.removeValue(forKey: taskID),
                          !task.isOneOffTask || (!task.isCompletedOneOff && !task.isCanceledOneOff)
                    else { continue }
                    if !task.isOneOffTask, task.scheduleAnchor == nil {
                        task.scheduleAnchor = RoutineDateMath.effectiveScheduleAnchor(
                            for: task,
                            referenceDate: update.pauseDate
                        )
                    }
                    task.pausedAt = update.pauseDate
                    task.pauseUntil = nil
                    DeviceActivityRecorder.recordAction(
                        .paused,
                        entity: .task,
                        entityID: taskID,
                        entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                        at: update.pauseDate,
                        in: context
                    )
                }

                try context.save()
                for taskID in update.taskIDs {
                    await cancelNotification(taskID.uuidString)
                }
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Failed to pause routines from custom section: \(error)")
            }
        }
    }

    static func resumeTasks<Action>(
        _ update: HomeResumeTasksUpdate,
        calendar: Calendar,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        cancelNotification: @escaping @Sendable (String) async -> Void,
        scheduleNotification: @escaping @Sendable (NotificationPayload) async -> Void
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                let taskIDs = Set(update.taskIDs)
                let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                    .filter { taskIDs.contains($0.id) }
                var tasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
                var resumedTasks: [RoutineTask] = []

                for taskID in update.taskIDs {
                    guard let task = tasksByID.removeValue(forKey: taskID), task.pausedAt != nil else {
                        continue
                    }
                    if !task.isOneOffTask {
                        task.scheduleAnchor = RoutineDateMath.resumedScheduleAnchor(
                            for: task,
                            resumedAt: update.resumeDate
                        )
                    }
                    task.pausedAt = nil
                    task.pauseUntil = nil
                    task.snoozedUntil = nil
                    resumedTasks.append(task)
                    DeviceActivityRecorder.recordAction(
                        .resumed,
                        entity: .task,
                        entityID: taskID,
                        entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                        at: update.resumeDate,
                        in: context
                    )
                }

                try context.save()
                for task in resumedTasks {
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
                        await cancelNotification(task.id.uuidString)
                    }
                }
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Failed to resume routines from custom section: \(error)")
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
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard let task = try context.fetch(HomeTaskSupport.taskDescriptor(for: update.taskID)).first else {
                    return
                }
                task.snoozedUntil = update.snoozedUntil
                DeviceActivityRecorder.recordAction(
                    .snoozed,
                    entity: .task,
                    entityID: update.taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    at: update.snoozedUntil,
                    in: context
                )
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
                RoutinaLog.error("Failed to archive routine for today from home list: \(error)")
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
