import ComposableArchitecture
import Foundation
import SwiftData

extension TaskDetailFeature {
    func handleOnAppear(taskID: UUID) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                _ = try RoutineLogHistory.backfillMissingLastDoneLog(for: taskID, in: context)
                let logs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(logs))
                let attachments = try context.fetch(attachmentDescriptor(for: taskID))
                let items = attachments
                    .sorted { $0.createdAt < $1.createdAt }
                    .map { AttachmentItem(id: $0.id, fileName: $0.fileName, data: $0.data) }
                send(.attachmentsLoaded(items))
                let appNotificationsEnabled = appSettingsClient.notificationsEnabled()
                let systemNotificationsAuthorized = await notificationClient.systemNotificationsAuthorized()
                send(
                    .notificationStatusLoaded(
                        appEnabled: appNotificationsEnabled,
                        systemAuthorized: systemNotificationsAuthorized
                    )
                )
            } catch {
                print("Error loading logs: \(error)")
            }
        }
    }

    func sortedLogsDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineLog> {
        FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == taskID
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
    }

    func taskDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineTask> {
        FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )
    }

    func handleMarkAsDone(taskID: UUID, completedAt: Date) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = ModelContext(modelContext().container)
                guard let advancedTask = try RoutineLogHistory.advanceTask(
                    taskID: taskID,
                    completedAt: completedAt,
                    context: context,
                    calendar: calendar
                ) else {
                    return
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
                print("Error saving context: \(error)")
            }
        }
    }

    func handleCancelTodo(taskID: UUID, canceledAt: Date) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = ModelContext(modelContext().container)
                guard let updatedTask = try RoutineLogHistory.cancelTask(
                    taskID: taskID,
                    canceledAt: canceledAt,
                    context: context,
                    calendar: calendar
                ) else {
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
                print("Error canceling todo: \(error)")
            }
        }
    }

    func handleUndoCompletion(taskID: UUID, completedDay: Date) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = ModelContext(modelContext().container)
                guard let updatedTask = try RoutineLogHistory.removeCompletion(
                    taskID: taskID,
                    on: completedDay,
                    context: context,
                    calendar: calendar
                ) else {
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
                print("Error undoing routine completion: \(error)")
            }
        }
    }

    func handleRemoveLogEntry(taskID: UUID, timestamp: Date) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = ModelContext(modelContext().container)
                guard let updatedTask = try RoutineLogHistory.removeLogEntry(
                    taskID: taskID,
                    timestamp: timestamp,
                    context: context
                ) else {
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
                print("Error removing routine log entry: \(error)")
            }
        }
    }

    func handleEditSave(
        taskID: UUID,
        name: String,
        emoji: String,
        notes: String?,
        link: String?,
        deadline: Date?,
        priority: RoutineTaskPriority,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        pressure: RoutineTaskPressure,
        imageData: Data?,
        attachments: [AttachmentItem],
        placeID: UUID?,
        tags: [String],
        relationships: [RoutineTaskRelationship],
        steps: [RoutineStep],
        checklistItems: [RoutineChecklistItem],
        scheduleMode: RoutineScheduleMode,
        recurrenceRule: RoutineRecurrenceRule,
        color: RoutineTaskColor,
        autoAssumeDailyDone: Bool,
        estimatedDurationMinutes: Int?,
        storyPoints: Int?
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                guard let task = try context.fetch(taskDescriptor(for: taskID)).first else { return }
                if try hasDuplicateRoutineName(name, in: context, excludingID: taskID) {
                    return
                }
                let previousScheduleMode = task.scheduleMode
                let previousRecurrenceRule = task.recurrenceRule
                task.name = name
                task.emoji = emoji
                task.notes = notes
                task.link = link
                task.priority = priority
                task.importance = importance
                task.urgency = urgency
                task.pressure = pressure
                task.color = color
                task.imageData = imageData
                // Sync attachments by taskID
                let existingAtts = try context.fetch(attachmentDescriptor(for: taskID))
                let newIDs = Set(attachments.map(\.id))
                for att in existingAtts where !newIDs.contains(att.id) {
                    context.delete(att)
                }
                let existingIDs = Set(existingAtts.map(\.id))
                for item in attachments where !existingIDs.contains(item.id) {
                    let newAtt = RoutineAttachment(id: item.id, taskID: taskID, fileName: item.fileName, data: item.data)
                    context.insert(newAtt)
                }
                task.placeID = placeID
                task.tags = tags
                task.replaceRelationships(relationships)
                task.replaceSteps(steps)
                task.scheduleMode = scheduleMode
                task.deadline = scheduleMode == .oneOff ? deadline : nil
                task.recurrenceRule = recurrenceRule
                task.replaceChecklistItems(checklistItems)
                if scheduleMode != .softInterval {
                    task.activityState = .idle
                    task.ongoingSince = nil
                }
                task.autoAssumeDailyDone = autoAssumeDailyDone
                    && RoutineAssumedCompletion.isEligible(
                        scheduleMode: scheduleMode,
                        recurrenceRule: recurrenceRule,
                        hasSequentialSteps: !steps.isEmpty,
                        hasChecklistItems: !checklistItems.isEmpty
                    )
                task.estimatedDurationMinutes = RoutineTask.sanitizedEstimatedDurationMinutes(estimatedDurationMinutes)
                task.storyPoints = RoutineTask.sanitizedStoryPoints(storyPoints)
                if scheduleMode == .oneOff {
                    task.scheduleAnchor = task.lastDone
                    task.interval = 1
                } else if previousScheduleMode != scheduleMode || previousRecurrenceRule != recurrenceRule {
                    task.scheduleAnchor = now
                } else if task.scheduleAnchor == nil {
                    task.scheduleAnchor = RoutineDateMath.effectiveScheduleAnchor(for: task, referenceDate: now)
                }
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
                if !NotificationCoordinator.shouldScheduleNotification(
                    for: task,
                    referenceDate: now,
                    calendar: calendar
                ) {
                    await notificationClient.cancel(task.id.uuidString)
                } else {
                    let payload = NotificationCoordinator.notificationPayload(
                        for: task,
                        referenceDate: now,
                        calendar: calendar
                    )
                    await notificationClient.schedule(payload)
                }
                send(.onAppear)
            } catch {
                print("Error saving routine edits: \(error)")
            }
        }
    }

    func handleConfirmAssumedPastDays(
        taskID: UUID,
        days: [Date]
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = ModelContext(modelContext().container)
                guard let updatedTask = try RoutineLogHistory.confirmTaskCompletions(
                    taskID: taskID,
                    on: days,
                    context: context,
                    referenceDate: now,
                    calendar: calendar
                ) else {
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
                print("Error confirming assumed routine days: \(error)")
            }
        }
    }

    func handleStartOngoing(taskID: UUID, startedAt: Date) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                guard let task = try context.fetch(taskDescriptor(for: taskID)).first else { return }
                task.startOngoing(at: startedAt)
                try context.save()
                await notificationClient.cancel(task.id.uuidString)
                NotificationCenter.default.postRoutineDidUpdate()
                send(.onAppear)
            } catch {
                print("Error starting ongoing routine: \(error)")
            }
        }
    }

    func handleFinishOngoing(taskID: UUID, finishedAt: Date) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = ModelContext(modelContext().container)
                guard let task = try context.fetch(taskDescriptor(for: taskID)).first else { return }
                guard task.isOngoing else { return }

                task.finishOngoing(at: finishedAt)

                let existingLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                if let existingLog = existingLogs.first(where: { log in
                    guard let timestamp = log.timestamp else { return false }
                    return log.kind == .completed && calendar.isDate(timestamp, inSameDayAs: finishedAt)
                }) {
                    if finishedAt > (existingLog.timestamp ?? .distantPast) {
                        existingLog.timestamp = finishedAt
                    }
                } else {
                    context.insert(RoutineLog(timestamp: finishedAt, taskID: taskID, kind: .completed))
                }

                try context.save()

                let updatedLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(updatedLogs))
                await notificationClient.cancel(task.id.uuidString)
                WidgetStatsService.refreshAndReload(using: context)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Error finishing ongoing routine: \(error)")
            }
        }
    }

    func loadEditContext(excluding taskID: UUID) -> Effect<Action> {
        .run { @MainActor send in
            let context = modelContext()
            let places = (try? context.fetch(FetchDescriptor<RoutinePlace>())) ?? []
            let tasks = (try? context.fetch(FetchDescriptor<RoutineTask>())) ?? []
            send(.availablePlacesLoaded(RoutinePlace.summaries(from: places, linkedTo: tasks)))
            send(.availableTagsLoaded(RoutineTag.allTags(from: tasks.map(\.tags))))
            send(.relatedTagRulesLoaded(
                RoutineTagRelations.sanitized(
                    appSettingsClient.relatedTagRules() + RoutineTagRelations.learnedRules(from: tasks.map(\.tags))
                )
            ))
            send(.availableRelationshipTasksLoaded(RoutineTaskRelationshipCandidate.from(tasks, excluding: taskID)))
        }
    }

    func handleDeleteRoutine(taskID: UUID) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                guard let task = try context.fetch(taskDescriptor(for: taskID)).first else {
                    send(.routineDeleted)
                    return
                }

                let identifier = task.id.uuidString
                let allTasks = (try? context.fetch(FetchDescriptor<RoutineTask>())) ?? []
                RoutineTask.removeRelationships(targeting: Set([taskID]), from: allTasks)
                context.delete(task)
                let logs = try context.fetch(allLogsDescriptor(for: task.id))
                for log in logs {
                    context.delete(log)
                }
                let focusSessions = try context.fetch(focusSessionsDescriptor(for: task.id))
                for session in focusSessions {
                    context.delete(session)
                }
                let attachmentsToDelete = try context.fetch(attachmentDescriptor(for: task.id))
                for att in attachmentsToDelete {
                    context.delete(att)
                }
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
                await notificationClient.cancel(identifier)
                send(.routineDeleted)
            } catch {
                print("Error deleting routine: \(error)")
            }
        }
    }

    func handlePauseRoutine(taskID: UUID, pausedAt: Date) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(taskDescriptor(for: taskID)).first else { return }
                if task.scheduleAnchor == nil {
                    task.scheduleAnchor = RoutineDateMath.effectiveScheduleAnchor(for: task, referenceDate: pausedAt)
                }
                task.pausedAt = pausedAt
                task.snoozedUntil = nil
                try context.save()
                await notificationClient.cancel(taskID.uuidString)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Error pausing routine: \(error)")
            }
        }
    }

    func handleNotTodayRoutine(taskID: UUID, snoozedUntil: Date) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(taskDescriptor(for: taskID)).first else { return }
                task.snoozedUntil = snoozedUntil
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
                print("Error archiving routine for today: \(error)")
            }
        }
    }

    func handleResumeRoutine(taskID: UUID, resumedAt: Date) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(taskDescriptor(for: taskID)).first else { return }
                if let pausedAt = task.pausedAt, task.isChecklistDriven {
                    task.shiftChecklistItems(by: max(resumedAt.timeIntervalSince(pausedAt), 0))
                }
                task.scheduleAnchor = RoutineDateMath.resumedScheduleAnchor(for: task, resumedAt: resumedAt)
                task.pausedAt = nil
                task.snoozedUntil = nil
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
                print("Error resuming routine: \(error)")
            }
        }
    }

    func handleChecklistItemsPurchased(
        taskID: UUID,
        itemIDs: Set<UUID>,
        purchasedAt: Date
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = ModelContext(modelContext().container)
                guard let updatedTask = try RoutineLogHistory.markChecklistItemsPurchased(
                    taskID: taskID,
                    itemIDs: itemIDs,
                    purchasedAt: purchasedAt,
                    context: context,
                    calendar: calendar
                ) else {
                    return
                }
                let updatedLogs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(updatedLogs))
                await notificationClient.schedule(
                    NotificationCoordinator.notificationPayload(
                        for: updatedTask.task,
                        referenceDate: purchasedAt,
                        calendar: calendar
                    )
                )
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Error updating checklist items: \(error)")
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
                let context = ModelContext(modelContext().container)
                guard let updatedTask = try RoutineLogHistory.advanceChecklistItem(
                    taskID: taskID,
                    itemID: itemID,
                    completedAt: completedAt,
                    context: context,
                    calendar: calendar
                ) else {
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
                print("Error updating checklist progress: \(error)")
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
                let context = ModelContext(modelContext().container)
                guard let updatedTask = try RoutineLogHistory.unmarkChecklistItem(
                    taskID: taskID,
                    itemID: itemID,
                    context: context
                ) else {
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
                print("Error removing checklist progress: \(error)")
            }
        }
    }

    func handleTodoStateChanged(taskID: UUID, rawValue: String?, pausedAt: Date?, clearSnoozed: Bool = false) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(taskDescriptor(for: taskID)).first else { return }
                task.todoStateRawValue = rawValue
                task.pausedAt = pausedAt
                if clearSnoozed { task.snoozedUntil = nil }
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Error updating todo state: \(error)")
            }
        }
    }

    func handlePressureChanged(taskID: UUID, pressure: RoutineTaskPressure) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(taskDescriptor(for: taskID)).first else { return }
                task.pressure = pressure
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Error updating pressure: \(error)")
            }
        }
    }

    func handleMatrixPositionChanged(
        taskID: UUID,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        priority: RoutineTaskPriority
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(taskDescriptor(for: taskID)).first else { return }
                task.importance = importance
                task.urgency = urgency
                task.priority = priority
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Error updating matrix position: \(error)")
            }
        }
    }

    func allLogsDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineLog> {
        FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == taskID
            }
        )
    }

    func focusSessionsDescriptor(for taskID: UUID) -> FetchDescriptor<FocusSession> {
        FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.taskID == taskID
            }
        )
    }

    func attachmentDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineAttachment> {
        FetchDescriptor<RoutineAttachment>(
            predicate: #Predicate { att in
                att.taskID == taskID
            }
        )
    }
}
