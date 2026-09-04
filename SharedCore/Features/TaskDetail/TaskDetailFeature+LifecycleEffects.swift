import ComposableArchitecture
import Foundation
import SwiftData

extension TaskDetailFeature {
    func handleStartOngoing(taskID: UUID, startedAt: Date) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else { return }
                guard task.usesOngoingLifecycle else { return }
                task.startOngoing(at: startedAt)
                task.appendChangeLogEntry(
                    RoutineTaskChangeLogEntry(
                        timestamp: startedAt,
                        kind: .ongoingStarted,
                        newValue: RoutineTaskMultiDaySpanDateStorage.encode(startedAt)
                    )
                )
                DeviceActivityRecorder.recordAction(
                    .started,
                    entity: .task,
                    entityID: taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    details: "Started ongoing repeating task",
                    at: startedAt,
                    in: context
                )
                try context.save()
                await notificationClient.cancel(task.id.uuidString)
                NotificationCenter.default.postRoutineDidUpdate()
                send(.onAppear)
            } catch {
                RoutinaLog.error("Error starting ongoing routine: \(error)")
            }
        }
    }

    func handleFinishOngoing(taskID: UUID, finishedAt: Date) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else { return }
                guard task.usesOngoingLifecycle else { return }
                guard task.isOngoing else { return }

                let ongoingStartedAt = task.ongoingSince
                task.finishOngoing(at: finishedAt)
                task.appendChangeLogEntry(
                    RoutineTaskChangeLogEntry(
                        timestamp: finishedAt,
                        kind: .ongoingStopped,
                        previousValue: ongoingStartedAt.map(RoutineTaskMultiDaySpanDateStorage.encode),
                        newValue: RoutineTaskMultiDaySpanDateStorage.encode(finishedAt)
                    )
                )

                let existingLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                if let existingLog = existingLogs.first(where: { log in
                    guard let timestamp = log.timestamp else { return false }
                    return log.kind.resolvesDoneDate && calendar.isDate(timestamp, inSameDayAs: finishedAt)
                }) {
                    if finishedAt > (existingLog.timestamp ?? .distantPast) {
                        existingLog.timestamp = finishedAt
                    }
                } else {
                    context.insert(RoutineLog(timestamp: finishedAt, taskID: taskID, kind: .completed))
                }
                try RoutineLogHistory.fulfillLinkedTasks(
                    fromSourceTaskID: taskID,
                    completedAt: finishedAt,
                    context: context,
                    calendar: calendar
                )

                DeviceActivityRecorder.recordAction(
                    .completed,
                    entity: .task,
                    entityID: taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    details: "Finished ongoing repeating task",
                    at: finishedAt,
                    in: context
                )
                try context.save()

                let updatedLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(updatedLogs))
                await notificationClient.cancel(task.id.uuidString)
                WidgetStatsService.refreshAndReload(using: context)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error finishing ongoing routine: \(error)")
            }
        }
    }

    func loadEditContext(excluding taskID: UUID) -> Effect<Action> {
        .run { @MainActor send in
            let context = modelContext()
            let places = (try? context.fetch(FetchDescriptor<RoutinePlace>())) ?? []
            let tasks = (try? context.fetch(FetchDescriptor<RoutineTask>())) ?? []
            let goals = (try? context.fetch(FetchDescriptor<RoutineGoal>())) ?? []
            let logs = (try? context.fetch(FetchDescriptor<RoutineLog>())) ?? []
            let doneStats = HomeTaskSupport.makeDoneStats(tasks: tasks, logs: logs)
            send(.availablePlacesLoaded(RoutinePlace.summaries(from: places, linkedTo: tasks)))
            send(
                .availableTagSummariesLoaded(
                    RoutineTag.summaries(
                        from: tasks,
                        countsByTaskID: doneStats.countsByTaskID
                    )
                ))
            send(.availableFlagsLoaded(appSettingsClient.definedFlags()))
            send(.flagRulesLoaded(appSettingsClient.flagRules()))
            send(.availableGoalsLoaded(RoutineGoalSummary.summaries(from: goals)))
            send(
                .relatedTagRulesLoaded(
                    RoutineTagRelations.sanitized(
                        appSettingsClient.relatedTagRules() + RoutineTagRelations.learnedRules(from: tasks.map(\.tags))
                    )
                ))
            send(
                .availableRelationshipTasksLoaded(
                    RoutineTaskRelationshipCandidate.from(
                        tasks,
                        excluding: taskID,
                        completionDatesByTaskID: doneStats.completedDatesByTaskID
                    )))
        }
    }

    func handleDeleteRoutine(taskID: UUID) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else {
                    send(.routineDeleted)
                    return
                }

                let identifier = task.id.uuidString
                let taskTitle = RoutineTask.trimmedName(task.name) ?? "Untitled task"
                let allTasks = (try? context.fetch(FetchDescriptor<RoutineTask>())) ?? []
                try DayPlanStorage.deleteBlocks(forTaskIDs: Set([taskID]), context: context)
                RoutineTask.removeRelationships(targeting: Set([taskID]), from: allTasks)
                context.delete(task)
                let logs = try context.fetch(TaskDetailFetchDescriptors.allLogs(for: task.id))
                for log in logs {
                    context.delete(log)
                }
                let focusSessions = try context.fetch(TaskDetailFetchDescriptors.focusSessions(for: task.id))
                for session in focusSessions {
                    context.delete(session)
                }
                let attachmentsToDelete = try context.fetch(TaskDetailFetchDescriptors.attachments(for: task.id))
                for att in attachmentsToDelete {
                    context.delete(att)
                }
                DeviceActivityRecorder.recordAction(
                    .deleted,
                    entity: .task,
                    entityID: taskID,
                    entityTitle: taskTitle,
                    in: context
                )
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
                await notificationClient.cancel(identifier)
                send(.routineDeleted)
            } catch {
                RoutinaLog.error("Error deleting routine: \(error)")
            }
        }
    }

    func handlePauseRoutine(
        taskID: UUID,
        pausedAt: Date,
        pauseUntil: Date?
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else { return }
                guard !task.isOneOffTask || (!task.isCompletedOneOff && !task.isCanceledOneOff) else { return }
                if !task.isOneOffTask, task.scheduleAnchor == nil {
                    task.scheduleAnchor = RoutineDateMath.effectiveScheduleAnchor(for: task, referenceDate: pausedAt)
                }
                task.pausedAt = pausedAt
                task.pauseUntil = pauseUntil
                task.snoozedUntil = nil
                DeviceActivityRecorder.recordAction(
                    .paused,
                    entity: .task,
                    entityID: taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    at: pausedAt,
                    in: context
                )
                try context.save()
                await notificationClient.cancel(taskID.uuidString)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error pausing routine: \(error)")
            }
        }
    }

    func handleNotTodayRoutine(taskID: UUID, snoozedUntil: Date) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else { return }
                task.snoozedUntil = snoozedUntil
                DeviceActivityRecorder.recordAction(
                    .snoozed,
                    entity: .task,
                    entityID: taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    at: snoozedUntil,
                    in: context
                )
                try context.save()
                if NotificationCoordinator.shouldScheduleNotification(
                    for: task,
                    referenceDate: snoozedUntil,
                    calendar: calendar
                ) {
                    await notificationClient.schedule(
                        NotificationCoordinator.notificationPayload(
                            for: task,
                            triggerDate: NotificationPreferences.reminderDate(on: snoozedUntil, calendar: calendar),
                            isArchivedOverride: false,
                            referenceDate: snoozedUntil,
                            calendar: calendar
                        )
                    )
                } else {
                    await notificationClient.cancel(task.id.uuidString)
                }
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error archiving routine for today: \(error)")
            }
        }
    }

    func handleResumeRoutine(taskID: UUID, resumedAt: Date) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first else { return }
                if !task.isOneOffTask {
                    if let pausedAt = task.pausedAt, task.isChecklistDriven {
                        task.shiftChecklistItems(by: max(resumedAt.timeIntervalSince(pausedAt), 0))
                    }
                    task.scheduleAnchor = RoutineDateMath.resumedScheduleAnchor(for: task, resumedAt: resumedAt)
                }
                task.pausedAt = nil
                task.pauseUntil = nil
                task.snoozedUntil = nil
                DeviceActivityRecorder.recordAction(
                    .resumed,
                    entity: .task,
                    entityID: taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    at: resumedAt,
                    in: context
                )
                try context.save()
                if NotificationCoordinator.shouldScheduleNotification(
                    for: task,
                    referenceDate: resumedAt,
                    calendar: calendar
                ) {
                    let payload = NotificationCoordinator.notificationPayload(
                        for: task,
                        referenceDate: resumedAt,
                        calendar: calendar
                    )
                    await notificationClient.schedule(payload)
                } else {
                    await notificationClient.cancel(task.id.uuidString)
                }
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Error resuming routine: \(error)")
            }
        }
    }

}
