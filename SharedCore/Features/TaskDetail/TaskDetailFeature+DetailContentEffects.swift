import ComposableArchitecture
import Foundation
import SwiftData

extension TaskDetailFeature {
    func handleTaskDetailCalendarExpansionChanged(
        taskID: UUID,
        isExpanded: Bool
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else { return }
                task.isTaskDetailCalendarExpanded = isExpanded
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error saving task detail calendar expansion: \(error)")
            }
        }
    }

    func handleTaskDetailImportanceRevealed(taskID: UUID) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else { return }
                task.hasExplicitImportance = true
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error saving task detail importance visibility: \(error)")
            }
        }
    }

    func handleTaskDetailUrgencyRevealed(taskID: UUID) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else { return }
                task.hasExplicitUrgency = true
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error saving task detail urgency visibility: \(error)")
            }
        }
    }

    func handleTodoStateDetailRevealed(taskID: UUID) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else { return }
                guard task.isOneOffTask, !task.isCompletedOneOff, !task.isCanceledOneOff else { return }
                guard task.todoStateRawValue == nil, !task.isPaused else { return }
                task.todoStateRawValue = TodoState.ready.rawValue
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error saving task detail state visibility: \(error)")
            }
        }
    }

    func handleDetailCommentsChanged(
        taskID: UUID,
        comments: [RoutineTaskComment]
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else { return }
                task.comments = comments
                DeviceActivityRecorder.recordAction(
                    .updated,
                    entity: .task,
                    entityID: taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    details: "Updated comments",
                    in: context
                )
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error saving detail comments: \(error)")
            }
        }
    }

    func handleDetailLinkExistingTask(
        taskID: UUID,
        targetTaskID: UUID,
        kind: RoutineTaskRelationshipKind
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                try RoutineTaskRelationshipMutationSupport.link(
                    sourceTaskID: taskID,
                    targetTaskID: targetTaskID,
                    kind: kind,
                    timestamp: now,
                    calendar: calendar,
                    context: modelContext()
                )
            } catch {
                RoutinaLog.error("Error linking existing task from Task Detail: \(error)")
            }
        }
    }

    func handleDetailChecklistItemsChanged(
        taskID: UUID,
        checklistItems: [RoutineChecklistItem],
        scheduleMode: RoutineScheduleMode? = nil
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else { return }
                if let scheduleMode {
                    task.scheduleMode = scheduleMode
                }
                task.replaceChecklistItems(checklistItems)
                DeviceActivityRecorder.recordAction(
                    .updated,
                    entity: .task,
                    entityID: taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    details: "Updated checklist items",
                    in: context
                )
                try context.save()
                WidgetStatsService.refreshAndReload(using: context)
                NotificationCenter.default.postRoutineDidUpdate()
                if !NotificationCoordinator.shouldScheduleNotification(
                    for: task,
                    referenceDate: now,
                    calendar: calendar
                ) {
                    await notificationClient.cancel(task.id.uuidString)
                } else {
                    await notificationClient.schedule(
                        NotificationCoordinator.notificationPayload(
                            for: task,
                            referenceDate: now,
                            calendar: calendar
                        )
                    )
                }
            } catch {
                RoutinaLog.error("Error saving detail checklist items: \(error)")
            }
        }
    }

}
