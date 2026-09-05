import ComposableArchitecture
import Foundation
import SwiftData

extension HomeTaskLifecycleExecutionSupport {
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
}
