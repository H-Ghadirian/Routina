import Foundation
import SwiftData

extension RoutineLogHistory {
    @MainActor
    static func advanceChecklistItem(
        taskID: UUID,
        itemID: UUID,
        completedAt: Date,
        context: ModelContext,
        calendar: Calendar = .current,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> (task: RoutineTask, result: RoutineAdvanceResult)? {
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )

        guard let task = try context.fetch(descriptor).first else {
            return nil
        }

        let result = task.markChecklistItemCompleted(
            itemID,
            completedAt: completedAt,
            calendar: calendar
        )

        switch result {
        case .ignoredPaused, .ignoredAlreadyCompletedToday:
            return (task, result)

        case .advancedStep, .advancedChecklist:
            DeviceActivityRecorder.recordAction(
                .updated,
                entity: .task,
                entityID: taskID,
                entityTitle: taskTitle(task),
                details: "Completed checklist item",
                sourceDevice: sourceDevice,
                at: completedAt,
                in: context
            )
            try context.save()
            return (task, result)

        case .completedRoutine:
            if let existingLog = detailLogs(taskID: taskID, context: context).first(where: { log in
                guard let timestamp = log.timestamp else { return false }
                return log.kind.resolvesDoneDate && calendar.isDate(timestamp, inSameDayAs: completedAt)
            }) {
                let currentTimestamp = existingLog.timestamp ?? .distantPast
                if completedAt > currentTimestamp {
                    existingLog.timestamp = completedAt
                }
                existingLog.scheduledOccurrenceAt = task.lastSatisfiedScheduledOccurrenceAt
            } else {
                context.insert(
                    RoutineLog(
                        timestamp: completedAt,
                        scheduledOccurrenceAt: task.lastSatisfiedScheduledOccurrenceAt,
                        taskID: taskID,
                        kind: .completed
                    ))
            }
            let allTasks = try context.fetch(FetchDescriptor<RoutineTask>())
            try fulfillLinkedTasks(
                from: task,
                completedAt: completedAt,
                tasks: allTasks,
                context: context,
                calendar: calendar,
                sourceDevice: sourceDevice
            )

            DeviceActivityRecorder.recordAction(
                .completed,
                entity: .task,
                entityID: taskID,
                entityTitle: taskTitle(task),
                details: "Completed checklist item",
                sourceDevice: sourceDevice,
                at: completedAt,
                in: context
            )
            try context.save()
            return (task, result)
        }
    }

    @discardableResult
    @MainActor
    static func unmarkChecklistItem(
        taskID: UUID,
        itemID: UUID,
        context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> RoutineTask? {
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )

        guard let task = try context.fetch(descriptor).first else {
            return nil
        }

        guard task.unmarkChecklistItemCompleted(itemID) else {
            return task
        }

        DeviceActivityRecorder.recordAction(
            .updated,
            entity: .task,
            entityID: taskID,
            entityTitle: taskTitle(task),
            details: "Unchecked checklist item",
            sourceDevice: sourceDevice,
            in: context
        )
        try context.save()
        return task
    }

    @discardableResult
    @MainActor
    static func markOptionalChecklistItemCompleted(
        taskID: UUID,
        itemID: UUID,
        completedAt: Date,
        context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> RoutineTask? {
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )

        guard let task = try context.fetch(descriptor).first else {
            return nil
        }

        guard task.markOptionalChecklistItemCompleted(itemID) else {
            return task
        }

        DeviceActivityRecorder.recordAction(
            .updated,
            entity: .task,
            entityID: taskID,
            entityTitle: taskTitle(task),
            details: "Checked checklist item",
            sourceDevice: sourceDevice,
            at: completedAt,
            in: context
        )
        try context.save()
        return task
    }

    @MainActor
    static func markDueChecklistItemsDone(
        taskID: UUID,
        doneAt: Date,
        context: ModelContext,
        calendar: Calendar = .current,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> (task: RoutineTask, update: RoutineTask.ChecklistRunoutUpdate)? {
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )

        guard let task = try context.fetch(descriptor).first else {
            return nil
        }

        let dueItemIDs = Set(task.dueChecklistItems(referenceDate: doneAt, calendar: calendar).map(\.id))
        guard !dueItemIDs.isEmpty else { return nil }

        return try markChecklistItemsDone(
            taskID: taskID,
            itemIDs: dueItemIDs,
            doneAt: doneAt,
            context: context,
            calendar: calendar,
            sourceDevice: sourceDevice
        )
    }

    @MainActor
    static func markChecklistItemsDone(
        taskID: UUID,
        itemIDs: Set<UUID>,
        doneAt: Date,
        context: ModelContext,
        calendar: Calendar = .current,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> (task: RoutineTask, update: RoutineTask.ChecklistRunoutUpdate)? {
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )

        guard let task = try context.fetch(descriptor).first else {
            return nil
        }

        let update = task.markChecklistItemsDone(itemIDs, doneAt: doneAt, calendar: calendar)
        guard update.updatedItemCount > 0 else {
            return nil
        }

        if update.didCompleteRoutine {
            let existingLogs = detailLogs(taskID: taskID, context: context)
            if let existingLog = existingLogs.first(where: { log in
                guard let timestamp = log.timestamp else { return false }
                return log.kind.resolvesDoneDate && calendar.isDate(timestamp, inSameDayAs: doneAt)
            }) {
                let currentTimestamp = existingLog.timestamp ?? .distantPast
                if doneAt > currentTimestamp {
                    existingLog.timestamp = doneAt
                }
                existingLog.scheduledOccurrenceAt = task.lastSatisfiedScheduledOccurrenceAt
            } else {
                context.insert(
                    RoutineLog(
                        timestamp: doneAt,
                        scheduledOccurrenceAt: task.lastSatisfiedScheduledOccurrenceAt,
                        taskID: taskID,
                        kind: .completed
                    ))
            }
            let allTasks = try context.fetch(FetchDescriptor<RoutineTask>())
            try fulfillLinkedTasks(
                from: task,
                completedAt: doneAt,
                tasks: allTasks,
                context: context,
                calendar: calendar,
                sourceDevice: sourceDevice
            )
        }

        DeviceActivityRecorder.recordAction(
            update.didCompleteRoutine ? .completed : .updated,
            entity: .task,
            entityID: taskID,
            entityTitle: taskTitle(task),
            details: "Marked \(update.updatedItemCount) checklist item(s) done",
            sourceDevice: sourceDevice,
            at: doneAt,
            in: context
        )
        try context.save()
        return (task, update)
    }

    @MainActor
    static func extendChecklistItemRunout(
        taskID: UUID,
        itemID: UUID,
        extendedAt: Date,
        context: ModelContext,
        calendar: Calendar = .current,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> (task: RoutineTask, updatedItemCount: Int)? {
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )

        guard let task = try context.fetch(descriptor).first else {
            return nil
        }

        let updatedItemCount = task.extendChecklistItemsRunout(
            [itemID],
            referenceDate: extendedAt,
            calendar: calendar
        )
        guard updatedItemCount > 0 else { return nil }

        DeviceActivityRecorder.recordAction(
            .updated,
            entity: .task,
            entityID: taskID,
            entityTitle: taskTitle(task),
            details: "Extended checklist item runout",
            sourceDevice: sourceDevice,
            at: extendedAt,
            in: context
        )
        try context.save()
        return (task, updatedItemCount)
    }

    @MainActor
    static func undoChecklistItemRunoutDone(
        taskID: UUID,
        itemID: UUID,
        undoneAt: Date,
        context: ModelContext,
        calendar: Calendar = .current,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> (task: RoutineTask, update: RoutineTask.ChecklistRunoutUndoUpdate)? {
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )

        guard let task = try context.fetch(descriptor).first else {
            return nil
        }

        let update = task.undoChecklistItemRunoutDone(
            itemID,
            referenceDate: undoneAt,
            calendar: calendar
        )
        guard update.restoredItemCount > 0 else { return nil }

        if let removedCompletionAt = update.removedCompletionAt {
            let logs = detailLogs(taskID: taskID, context: context)
            for log in logs where log.kind == .completed && log.timestamp == removedCompletionAt {
                context.delete(log)
            }
            try removeFulfillmentsSourcedBy(
                taskID: taskID,
                on: removedCompletionAt,
                context: context,
                calendar: calendar
            )
        }

        DeviceActivityRecorder.recordAction(
            .updated,
            entity: .task,
            entityID: taskID,
            entityTitle: taskTitle(task),
            details: "Unchecked checklist item runout",
            sourceDevice: sourceDevice,
            at: undoneAt,
            in: context
        )
        try context.save()
        return (task, update)
    }

    @MainActor
    static func markDueChecklistItemsPurchased(
        taskID: UUID,
        purchasedAt: Date,
        context: ModelContext,
        calendar: Calendar = .current,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> (task: RoutineTask, updatedItemCount: Int)? {
        guard
            let result = try markDueChecklistItemsDone(
                taskID: taskID,
                doneAt: purchasedAt,
                context: context,
                calendar: calendar,
                sourceDevice: sourceDevice
            )
        else { return nil }
        return (result.task, result.update.updatedItemCount)
    }

    @MainActor
    static func markChecklistItemsPurchased(
        taskID: UUID,
        itemIDs: Set<UUID>,
        purchasedAt: Date,
        context: ModelContext,
        calendar: Calendar = .current,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> (task: RoutineTask, updatedItemCount: Int)? {
        guard
            let result = try markChecklistItemsDone(
                taskID: taskID,
                itemIDs: itemIDs,
                doneAt: purchasedAt,
                context: context,
                calendar: calendar,
                sourceDevice: sourceDevice
            )
        else { return nil }
        return (result.task, result.update.updatedItemCount)
    }

}
