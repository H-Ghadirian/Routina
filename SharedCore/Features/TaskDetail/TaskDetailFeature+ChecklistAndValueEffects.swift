import ComposableArchitecture
import Foundation
import SwiftData

extension TaskDetailFeature {
    func handleChecklistItemsDone(
        taskID: UUID,
        itemIDs: Set<UUID>,
        doneAt: Date
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard
                    let updatedTask = try RoutineLogHistory.markChecklistItemsDone(
                        taskID: taskID,
                        itemIDs: itemIDs,
                        doneAt: doneAt,
                        context: context,
                        calendar: calendar
                    )
                else {
                    return
                }
                let updatedLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(updatedLogs))
                await notificationClient.schedule(
                    NotificationCoordinator.notificationPayload(
                        for: updatedTask.task,
                        referenceDate: doneAt,
                        calendar: calendar
                    )
                )
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error updating checklist items: \(error)")
            }
        }
    }

    func handleChecklistItemRunoutExtended(
        taskID: UUID,
        itemID: UUID,
        extendedAt: Date
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard
                    let updatedTask = try RoutineLogHistory.extendChecklistItemRunout(
                        taskID: taskID,
                        itemID: itemID,
                        extendedAt: extendedAt,
                        context: context,
                        calendar: calendar
                    )
                else {
                    return
                }
                let updatedLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(updatedLogs))
                await notificationClient.schedule(
                    NotificationCoordinator.notificationPayload(
                        for: updatedTask.task,
                        referenceDate: extendedAt,
                        calendar: calendar
                    )
                )
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error extending checklist item runout: \(error)")
            }
        }
    }

    func handleChecklistItemRunoutDoneUndone(
        taskID: UUID,
        itemID: UUID,
        undoneAt: Date
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard
                    let updatedTask = try RoutineLogHistory.undoChecklistItemRunoutDone(
                        taskID: taskID,
                        itemID: itemID,
                        undoneAt: undoneAt,
                        context: context,
                        calendar: calendar
                    )
                else {
                    return
                }
                let updatedLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(updatedLogs))
                await notificationClient.schedule(
                    NotificationCoordinator.notificationPayload(
                        for: updatedTask.task,
                        referenceDate: undoneAt,
                        calendar: calendar
                    )
                )
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error undoing checklist item runout: \(error)")
            }
        }
    }

    func handleChecklistItemCompleted(
        taskID: UUID,
        itemID: UUID,
        completedAt: Date
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard
                    let updatedTask = try RoutineLogHistory.advanceChecklistItem(
                        taskID: taskID,
                        itemID: itemID,
                        completedAt: completedAt,
                        context: context,
                        calendar: calendar
                    )
                else {
                    return
                }
                let updatedLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(updatedLogs))
                await notificationClient.schedule(
                    NotificationCoordinator.notificationPayload(
                        for: updatedTask.task,
                        referenceDate: completedAt,
                        calendar: calendar
                    )
                )
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error updating checklist progress: \(error)")
            }
        }
    }

    func handleChecklistItemUnmarked(
        taskID: UUID,
        itemID: UUID,
        referenceDate: Date
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard
                    let updatedTask = try RoutineLogHistory.unmarkChecklistItem(
                        taskID: taskID,
                        itemID: itemID,
                        context: context
                    )
                else {
                    return
                }
                let updatedLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(updatedLogs))
                await notificationClient.schedule(
                    NotificationCoordinator.notificationPayload(
                        for: updatedTask,
                        referenceDate: referenceDate,
                        calendar: calendar
                    )
                )
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error removing checklist progress: \(error)")
            }
        }
    }

    func handleOptionalChecklistItemCompleted(
        taskID: UUID,
        itemID: UUID,
        completedAt: Date
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                _ = try RoutineLogHistory.markOptionalChecklistItemCompleted(
                    taskID: taskID,
                    itemID: itemID,
                    completedAt: completedAt,
                    context: context
                )
                let updatedLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(updatedLogs))
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error updating checklist progress: \(error)")
            }
        }
    }

    func handleOptionalChecklistItemUnmarked(
        taskID: UUID,
        itemID: UUID
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                _ = try RoutineLogHistory.unmarkChecklistItem(
                    taskID: taskID,
                    itemID: itemID,
                    context: context
                )
                let updatedLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(updatedLogs))
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error removing checklist progress: \(error)")
            }
        }
    }

    func handleTodoStateChanged(
        taskID: UUID,
        rawValue: String?,
        pausedAt: Date?,
        clearSnoozed: Bool = false,
        previousStateTitle: String?,
        newStateTitle: String
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else { return }
                task.todoStateRawValue = rawValue
                task.pausedAt = pausedAt
                task.pauseUntil = nil
                if clearSnoozed { task.snoozedUntil = nil }
                if previousStateTitle != newStateTitle {
                    task.appendChangeLogEntry(
                        RoutineTaskChangeLogEntry(
                            timestamp: now,
                            kind: .stateChanged,
                            previousValue: previousStateTitle,
                            newValue: newStateTitle
                        )
                    )
                }
                DeviceActivityRecorder.recordAction(
                    .updated,
                    entity: .task,
                    entityID: taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    details: "Changed state to \(newStateTitle)",
                    at: now,
                    in: context
                )
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error updating todo state: \(error)")
            }
        }
    }

    func handlePressureChanged(taskID: UUID, pressure: RoutineTaskPressure) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else { return }
                task.pressure = pressure
                DeviceActivityRecorder.recordAction(
                    .updated,
                    entity: .task,
                    entityID: taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    details: "Updated pressure",
                    in: context
                )
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error updating pressure: \(error)")
            }
        }
    }

    func handleThinkingNeededChanged(
        taskID: UUID,
        thinkingNeeded: RoutineTaskThinkingNeeded
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else { return }
                task.thinkingNeeded = thinkingNeeded
                DeviceActivityRecorder.recordAction(
                    .updated,
                    entity: .task,
                    entityID: taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    details: "Updated thinking needed",
                    in: context
                )
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error updating thinking needed: \(error)")
            }
        }
    }

    func handleMatrixPositionChanged(
        taskID: UUID,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        priority: RoutineTaskPriority,
        hasExplicitImportance: Bool,
        hasExplicitUrgency: Bool
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else { return }
                task.importance = importance
                task.urgency = urgency
                task.priority = priority
                task.hasExplicitImportance = hasExplicitImportance
                task.hasExplicitUrgency = hasExplicitUrgency
                DeviceActivityRecorder.recordAction(
                    .updated,
                    entity: .task,
                    entityID: taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    details: "Updated priority matrix",
                    in: context
                )
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error updating matrix position: \(error)")
            }
        }
    }

}
