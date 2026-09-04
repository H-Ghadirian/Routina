import ComposableArchitecture
import Foundation
import SwiftData

extension TaskDetailFeature {
    func handleMarkAsDone(
        taskID: UUID,
        completedAt: Date,
        referenceDate: Date? = nil,
        previousStateTitle: String? = nil,
        manuallySelectedFulfillmentTargetIDs: Set<UUID> = [],
        actualDurationMinutes: Int? = nil,
        hasSpecificWorkTime: Bool? = nil,
        isConfirmedAssumedDone: Bool = false
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard
                    let advancedTask = try RoutineLogHistory.advanceTask(
                        taskID: taskID,
                        completedAt: completedAt,
                        referenceDate: referenceDate,
                        allowEarlyScheduledCompletion: true,
                        actualDurationMinutes: actualDurationMinutes,
                        hasSpecificWorkTime: hasSpecificWorkTime,
                        isConfirmedAssumedDone: isConfirmedAssumedDone,
                        context: context,
                        calendar: calendar
                    )
                else {
                    return
                }
                let shouldRecordStateChange =
                    advancedTask.task.isOneOffTask
                    && previousStateTitle != TodoState.done.displayTitle
                if shouldRecordStateChange {
                    advancedTask.task.appendChangeLogEntry(
                        RoutineTaskChangeLogEntry(
                            timestamp: now,
                            kind: .stateChanged,
                            previousValue: previousStateTitle,
                            newValue: TodoState.done.displayTitle
                        )
                    )
                    try context.save()
                }
                let shouldFulfillSelectedTargets =
                    advancedTask.result == .completedRoutine
                    && !manuallySelectedFulfillmentTargetIDs.isEmpty
                if shouldFulfillSelectedTargets {
                    try RoutineLogHistory.fulfillManuallySelectedLinkedTasks(
                        fromSourceTaskID: taskID,
                        targetTaskIDs: manuallySelectedFulfillmentTargetIDs,
                        completedAt: completedAt,
                        context: context,
                        calendar: calendar
                    )
                    try context.save()
                }
                let updatedLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(updatedLogs))
                if advancedTask.result != .ignoredAlreadyCompletedToday {
                    if !NotificationCoordinator.shouldScheduleNotification(
                        for: advancedTask.task,
                        referenceDate: completedAt,
                        calendar: calendar
                    ) {
                        await notificationClient.cancel(taskID.uuidString)
                    } else {
                        await notificationClient.schedule(
                            NotificationCoordinator.notificationPayload(
                                for: advancedTask.task,
                                referenceDate: completedAt,
                                calendar: calendar
                            )
                        )
                    }
                }
                WidgetStatsService.refreshAndReload(using: context)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error saving context: \(error)")
            }
        }
    }

    func handleCancelTodo(taskID: UUID, canceledAt: Date) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard
                    let updatedTask = try RoutineLogHistory.cancelTask(
                        taskID: taskID,
                        canceledAt: canceledAt,
                        context: context,
                        calendar: calendar
                    )
                else {
                    return
                }
                let updatedLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(updatedLogs))
                if updatedTask.isOneOffTask {
                    await notificationClient.cancel(taskID.uuidString)
                }
                WidgetStatsService.refreshAndReload(using: context)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error canceling todo: \(error)")
            }
        }
    }

    func handleMarkOccurrenceMissed(
        taskID: UUID,
        missedAt: Date
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard
                    let updatedTask = try RoutineLogHistory.markExactTimedOccurrenceMissed(
                        taskID: taskID,
                        missedAt: missedAt,
                        context: context,
                        calendar: calendar
                    )
                else {
                    return
                }
                let updatedLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(updatedLogs))
                await refreshNotificationAfterOccurrenceResolution(
                    for: updatedTask,
                    taskID: taskID
                )
                WidgetStatsService.refreshAndReload(using: context)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error marking routine occurrence missed: \(error)")
            }
        }
    }

    func handleMarkOccurrenceCanceled(
        taskID: UUID,
        canceledAt: Date
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard
                    let updatedTask = try RoutineLogHistory.markExactTimedOccurrenceCanceled(
                        taskID: taskID,
                        canceledAt: canceledAt,
                        context: context,
                        calendar: calendar
                    )
                else {
                    return
                }
                let updatedLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(updatedLogs))
                await refreshNotificationAfterOccurrenceResolution(
                    for: updatedTask,
                    taskID: taskID
                )
                WidgetStatsService.refreshAndReload(using: context)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error canceling routine occurrence: \(error)")
            }
        }
    }

    @MainActor
    private func refreshNotificationAfterOccurrenceResolution(
        for task: RoutineTask,
        taskID: UUID
    ) async {
        if !NotificationCoordinator.shouldScheduleNotification(
            for: task,
            referenceDate: now,
            calendar: calendar
        ) {
            await notificationClient.cancel(taskID.uuidString)
        } else {
            await notificationClient.schedule(
                NotificationCoordinator.notificationPayload(
                    for: task,
                    referenceDate: now,
                    calendar: calendar
                )
            )
        }
    }

    func handleUndoCompletion(taskID: UUID, completedDay: Date) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard
                    let updatedTask = try RoutineLogHistory.removeCompletion(
                        taskID: taskID,
                        on: completedDay,
                        context: context,
                        calendar: calendar
                    )
                else {
                    return
                }
                let updatedLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(updatedLogs))
                if !NotificationCoordinator.shouldScheduleNotification(
                    for: updatedTask,
                    referenceDate: now,
                    calendar: calendar
                ) {
                    await notificationClient.cancel(taskID.uuidString)
                } else {
                    await notificationClient.schedule(
                        NotificationCoordinator.notificationPayload(
                            for: updatedTask,
                            referenceDate: now,
                            calendar: calendar
                        )
                    )
                }
                WidgetStatsService.refreshAndReload(using: context)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error undoing routine completion: \(error)")
            }
        }
    }

    func handleRemoveLogEntry(taskID: UUID, timestamp: Date) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard
                    let updatedTask = try RoutineLogHistory.removeLogEntry(
                        taskID: taskID,
                        timestamp: timestamp,
                        context: context,
                        calendar: calendar
                    )
                else {
                    return
                }
                let updatedLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(updatedLogs))
                if !NotificationCoordinator.shouldScheduleNotification(
                    for: updatedTask,
                    referenceDate: now,
                    calendar: calendar
                ) {
                    await notificationClient.cancel(taskID.uuidString)
                } else {
                    await notificationClient.schedule(
                        NotificationCoordinator.notificationPayload(
                            for: updatedTask,
                            referenceDate: now,
                            calendar: calendar
                        )
                    )
                }
                WidgetStatsService.refreshAndReload(using: context)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error removing routine log entry: \(error)")
            }
        }
    }

    func handleUpdateLogDuration(
        taskID: UUID,
        logID: UUID,
        previousDurationMinutes: Int?,
        durationMinutes: Int?
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let log = try context.fetch(TaskDetailFetchDescriptors.log(for: logID)).first else { return }
                log.actualDurationMinutes = RoutineLog.sanitizedActualDurationMinutes(durationMinutes)
                if previousDurationMinutes != durationMinutes {
                    if let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first {
                        task.appendChangeLogEntry(
                            timeSpentChangeEntry(
                                previousDurationMinutes: previousDurationMinutes,
                                durationMinutes: durationMinutes
                            )
                        )
                    }
                }
                DeviceActivityRecorder.recordAction(
                    .updated,
                    entity: .routineLog,
                    entityID: logID,
                    entityTitle: "Time spent",
                    in: context
                )
                try context.save()
                WidgetStatsService.refreshAndReload(using: context)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error updating routine log duration: \(error)")
            }
        }
    }

    func handleUpdateTaskDuration(
        taskID: UUID,
        previousDurationMinutes: Int?,
        durationMinutes: Int?
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else { return }
                task.actualDurationMinutes = RoutineTask.sanitizedActualDurationMinutes(durationMinutes)
                if previousDurationMinutes != durationMinutes {
                    task.appendChangeLogEntry(
                        timeSpentChangeEntry(
                            previousDurationMinutes: previousDurationMinutes,
                            durationMinutes: durationMinutes
                        )
                    )
                }
                DeviceActivityRecorder.recordAction(
                    .updated,
                    entity: .task,
                    entityID: taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    details: "Updated time spent",
                    in: context
                )
                try context.save()
                WidgetStatsService.refreshAndReload(using: context)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error updating task duration: \(error)")
            }
        }
    }

    func handleTaskDetailHeatmapRevealed(taskID: UUID) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else { return }
                guard task.supportsTaskDetailHeatmap else { return }
                task.showsTaskDetailHeatmap = true
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error saving task detail heatmap visibility: \(error)")
            }
        }
    }

    func handleTaskDetailHistoryRevealed(taskID: UUID) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else { return }
                task.showsTaskDetailHistory = true
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error saving task detail history visibility: \(error)")
            }
        }
    }

    func handleConfirmAssumedPastDays(
        taskID: UUID,
        days: [Date]
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard
                    let updatedTask = try RoutineLogHistory.confirmTaskCompletions(
                        taskID: taskID,
                        on: days,
                        context: context,
                        referenceDate: now,
                        calendar: calendar
                    )
                else {
                    return
                }

                let updatedLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(updatedLogs))

                if !NotificationCoordinator.shouldScheduleNotification(
                    for: updatedTask,
                    referenceDate: now,
                    calendar: calendar
                ) {
                    await notificationClient.cancel(updatedTask.id.uuidString)
                } else {
                    await notificationClient.schedule(
                        NotificationCoordinator.notificationPayload(
                            for: updatedTask,
                            referenceDate: now,
                            calendar: calendar
                        )
                    )
                }
                WidgetStatsService.refreshAndReload(using: context)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error confirming assumed task days: \(error)")
            }
        }
    }

}
