import Foundation
import SwiftData

enum RoutineLogHistory {
    @MainActor
    static func deduplicateRedundantSameDayLogs(
        in context: ModelContext,
        calendar: Calendar = .current
    ) throws -> Bool {
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        var keptLogsByKey: [RoutineLogDeduplicationKey: RoutineLog] = [:]
        var didDeleteAny = false

        for log in logs {
            guard let timestamp = log.timestamp else { continue }
            let key = RoutineLogDeduplicationKey(
                taskID: log.taskID,
                kind: log.kind,
                sourceTaskID: log.sourceTaskID,
                day: calendar.startOfDay(for: timestamp)
            )

            guard let keptLog = keptLogsByKey[key] else {
                keptLogsByKey[key] = log
                continue
            }

            let keptTimestamp = keptLog.timestamp ?? .distantPast
            if timestamp > keptTimestamp {
                context.delete(keptLog)
                keptLogsByKey[key] = log
            } else {
                context.delete(log)
            }
            didDeleteAny = true
        }

        guard didDeleteAny else { return false }
        try context.save()
        return true
    }

    @MainActor
    static func backfillMissingLastDoneLogs(in context: ModelContext) throws -> Bool {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        var didInsertAny = false

        for task in tasks {
            guard let lastDone = task.lastDone else { continue }
            let hasMatchingLog = logs.contains { log in
                log.taskID == task.id
                    && log.kind.resolvesDoneDate
                    && isSameCompletion(log.timestamp, as: lastDone)
            }

            guard !hasMatchingLog else { continue }
            context.insert(RoutineLog(timestamp: lastDone, taskID: task.id, kind: .completed))
            didInsertAny = true
        }

        if didInsertAny {
            try context.save()
        }

        return didInsertAny
    }

    @MainActor
    static func backfillMissingLastDoneLog(for taskID: UUID, in context: ModelContext) throws -> Bool {
        let taskDescriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )
        guard let task = try context.fetch(taskDescriptor).first,
              let lastDone = task.lastDone else {
            return false
        }

        let logDescriptor = FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == taskID
            }
        )
        let logs = try context.fetch(logDescriptor)
        let hasMatchingLog = logs.contains { log in
            log.kind.resolvesDoneDate && isSameCompletion(log.timestamp, as: lastDone)
        }

        guard !hasMatchingLog else { return false }
        context.insert(RoutineLog(timestamp: lastDone, taskID: taskID, kind: .completed))
        try context.save()
        return true
    }

    @MainActor
    static func detailLogs(taskID: UUID, context: ModelContext) -> [RoutineLog] {
        let descriptor = FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == taskID
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    static func advanceTask(
        taskID: UUID,
        completedAt: Date,
        referenceDate: Date? = nil,
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
        guard !task.blocksManualCompletionForIncompleteChecklist else {
            return nil
        }

        let allTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let existingLogs = detailLogs(taskID: taskID, context: context)
        let hasMatchingLog = existingLogs.contains { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind.resolvesDoneDate && calendar.isDate(timestamp, inSameDayAs: completedAt)
        }
        if hasMatchingLog {
            if BatteryRoutineService.dismissCompletedLowBatteryPrompt(for: task, at: completedAt) {
                try context.save()
            }
            return (task, .ignoredAlreadyCompletedToday)
        }

        if let referenceDate {
            task.preserveCurrentScheduleAnchorForBackfill(
                completedAt: completedAt,
                referenceDate: referenceDate
            )
        }

        let result = task.advance(completedAt: completedAt, calendar: calendar)
        switch result {
        case .ignoredPaused, .ignoredAlreadyCompletedToday:
            return (task, result)

        case .advancedStep, .advancedChecklist:
            DeviceActivityRecorder.recordAction(
                .updated,
                entity: .task,
                entityID: taskID,
                entityTitle: taskTitle(task),
                details: "Advanced task progress",
                sourceDevice: sourceDevice,
                at: completedAt,
                in: context
            )
            try context.save()
            return (task, result)

        case .completedRoutine:
            deleteNonCompletionResolutionLogs(on: completedAt, from: existingLogs, context: context, calendar: calendar)
            context.insert(RoutineLog(timestamp: completedAt, taskID: taskID, kind: .completed))
            try fulfillLinkedTasks(
                from: task,
                completedAt: completedAt,
                tasks: allTasks,
                context: context,
                calendar: calendar,
                sourceDevice: sourceDevice
            )
            _ = BatteryRoutineService.dismissCompletedLowBatteryPrompt(for: task, at: completedAt)
            DeviceActivityRecorder.recordAction(
                .completed,
                entity: .task,
                entityID: taskID,
                entityTitle: taskTitle(task),
                sourceDevice: sourceDevice,
                at: completedAt,
                in: context
            )
            try context.save()
            return (task, result)
        }
    }

    @MainActor
    static func markExactTimedOccurrenceMissed(
        taskID: UUID,
        missedAt: Date,
        context: ModelContext,
        calendar: Calendar = .current,
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
        guard RoutineDateMath.usesExactTimedOccurrenceTracking(for: task) else {
            return task
        }
        guard let occurrence = RoutineDateMath.scheduledOccurrence(
            for: task,
            on: missedAt,
            calendar: calendar
        ) else {
            return task
        }

        let existingLogs = detailLogs(taskID: taskID, context: context)
        let hasCompletedLog = existingLogs.contains { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind.resolvesDoneDate && calendar.isDate(timestamp, inSameDayAs: occurrence)
        }
        guard !hasCompletedLog else {
            return task
        }

        deleteResolutionLogs(
            on: occurrence,
            matchingKinds: [.canceled],
            from: existingLogs,
            context: context,
            calendar: calendar
        )

        if let existingMissedLog = existingLogs.first(where: { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind == .missed && calendar.isDate(timestamp, inSameDayAs: occurrence)
        }) {
            if occurrence > (existingMissedLog.timestamp ?? .distantPast) {
                existingMissedLog.timestamp = occurrence
            }
        } else {
            context.insert(RoutineLog(timestamp: occurrence, taskID: taskID, kind: .missed))
        }

        DeviceActivityRecorder.recordAction(
            .missed,
            entity: .task,
            entityID: taskID,
            entityTitle: taskTitle(task),
            sourceDevice: sourceDevice,
            at: occurrence,
            in: context
        )
        try context.save()
        return task
    }

    @MainActor
    static func markExactTimedOccurrenceCanceled(
        taskID: UUID,
        canceledAt: Date,
        context: ModelContext,
        calendar: Calendar = .current,
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
        guard RoutineDateMath.usesExactTimedOccurrenceTracking(for: task) else {
            return task
        }
        guard let occurrence = RoutineDateMath.scheduledOccurrence(
            for: task,
            on: canceledAt,
            calendar: calendar
        ) else {
            return task
        }

        let existingLogs = detailLogs(taskID: taskID, context: context)
        let hasCompletedLog = existingLogs.contains { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind.resolvesDoneDate && calendar.isDate(timestamp, inSameDayAs: occurrence)
        }
        guard !hasCompletedLog else {
            return task
        }

        deleteResolutionLogs(
            on: occurrence,
            matchingKinds: [.missed],
            from: existingLogs,
            context: context,
            calendar: calendar
        )

        if let existingCanceledLog = existingLogs.first(where: { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind == .canceled && calendar.isDate(timestamp, inSameDayAs: occurrence)
        }) {
            if occurrence > (existingCanceledLog.timestamp ?? .distantPast) {
                existingCanceledLog.timestamp = occurrence
            }
        } else {
            context.insert(RoutineLog(timestamp: occurrence, taskID: taskID, kind: .canceled))
        }

        DeviceActivityRecorder.recordAction(
            .canceled,
            entity: .task,
            entityID: taskID,
            entityTitle: taskTitle(task),
            sourceDevice: sourceDevice,
            at: occurrence,
            in: context
        )
        try context.save()
        return task
    }

    @MainActor
    static func confirmTaskCompletions(
        taskID: UUID,
        on days: [Date],
        context: ModelContext,
        referenceDate: Date = .now,
        calendar: Calendar = .current,
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

        let orderedDays = Array(
            Set(days.map { calendar.startOfDay(for: $0) })
        ).sorted()
        guard !orderedDays.isEmpty else { return task }

        let existingLogs = detailLogs(taskID: taskID, context: context)
        var didChange = false

        for day in orderedDays {
            let alreadyCompleted = existingLogs.contains { log in
                guard let timestamp = log.timestamp else { return false }
                return log.kind.resolvesDoneDate && calendar.isDate(timestamp, inSameDayAs: day)
            }
            if alreadyCompleted {
                continue
            }

            let completionDate = RoutineAssumedCompletion.completionTimestamp(
                for: task,
                on: day,
                referenceDate: referenceDate,
                calendar: calendar
            )
            let result = task.advance(completedAt: completionDate, calendar: calendar)
            switch result {
            case .completedRoutine:
                context.insert(RoutineLog(timestamp: completionDate, taskID: taskID, kind: .completed))
                let allTasks = try context.fetch(FetchDescriptor<RoutineTask>())
                try fulfillLinkedTasks(
                    from: task,
                    completedAt: completionDate,
                    tasks: allTasks,
                    context: context,
                    calendar: calendar,
                    sourceDevice: sourceDevice
                )
                didChange = true
            case .advancedStep, .advancedChecklist:
                didChange = true
            case .ignoredPaused, .ignoredAlreadyCompletedToday:
                continue
            }
        }

        if didChange {
            DeviceActivityRecorder.recordAction(
                .completed,
                entity: .task,
                entityID: taskID,
                entityTitle: taskTitle(task),
                details: "Confirmed \(orderedDays.count) assumed day(s)",
                sourceDevice: sourceDevice,
                at: referenceDate,
                in: context
            )
            try context.save()
        }

        return task
    }

    @MainActor
    static func markAssumedCompletionMissed(
        taskID: UUID,
        on day: Date,
        context: ModelContext,
        referenceDate: Date = .now,
        calendar: Calendar = .current,
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

        let day = calendar.startOfDay(for: day)
        let existingLogs = detailLogs(taskID: taskID, context: context)
        guard RoutineAssumedCompletion.isAssumedDone(
            for: task,
            on: day,
            referenceDate: referenceDate,
            logs: existingLogs,
            calendar: calendar
        ) else {
            return task
        }

        let missedAt = RoutineAssumedCompletion.completionTimestamp(
            for: task,
            on: day,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let hasCompletedLog = existingLogs.contains { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind.resolvesDoneDate && calendar.isDate(timestamp, inSameDayAs: missedAt)
        }
        guard !hasCompletedLog else {
            return task
        }

        if let existingMissedLog = existingLogs.first(where: { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind == .missed && calendar.isDate(timestamp, inSameDayAs: missedAt)
        }) {
            if missedAt > (existingMissedLog.timestamp ?? .distantPast) {
                existingMissedLog.timestamp = missedAt
            }
        } else {
            context.insert(RoutineLog(timestamp: missedAt, taskID: taskID, kind: .missed))
        }

        DeviceActivityRecorder.recordAction(
            .missed,
            entity: .task,
            entityID: taskID,
            entityTitle: taskTitle(task),
            details: "Marked assumed day not done",
            sourceDevice: sourceDevice,
            at: referenceDate,
            in: context
        )
        try context.save()
        return task
    }

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
            } else {
                context.insert(RoutineLog(timestamp: completedAt, taskID: taskID, kind: .completed))
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
            } else {
                context.insert(RoutineLog(timestamp: doneAt, taskID: taskID, kind: .completed))
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
        guard let result = try markDueChecklistItemsDone(
            taskID: taskID,
            doneAt: purchasedAt,
            context: context,
            calendar: calendar,
            sourceDevice: sourceDevice
        ) else { return nil }
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
        guard let result = try markChecklistItemsDone(
            taskID: taskID,
            itemIDs: itemIDs,
            doneAt: purchasedAt,
            context: context,
            calendar: calendar,
            sourceDevice: sourceDevice
        ) else { return nil }
        return (result.task, result.update.updatedItemCount)
    }

    @MainActor
    static func cancelTask(
        taskID: UUID,
        canceledAt: Date,
        context: ModelContext,
        calendar: Calendar = .current,
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

        guard task.cancelOneOff(at: canceledAt) else {
            return task
        }

        let existingLogs = detailLogs(taskID: taskID, context: context)
        if let existingLog = existingLogs.first(where: { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind == .canceled && calendar.isDate(timestamp, inSameDayAs: canceledAt)
        }) {
            let currentTimestamp = existingLog.timestamp ?? .distantPast
            if canceledAt > currentTimestamp {
                existingLog.timestamp = canceledAt
            }
        } else {
            context.insert(RoutineLog(timestamp: canceledAt, taskID: taskID, kind: .canceled))
        }

        DeviceActivityRecorder.recordAction(
            .canceled,
            entity: .task,
            entityID: taskID,
            entityTitle: taskTitle(task),
            sourceDevice: sourceDevice,
            at: canceledAt,
            in: context
        )
        try context.save()
        return task
    }

    @MainActor
    static func removeCompletion(
        taskID: UUID,
        on completedDay: Date,
        context: ModelContext,
        calendar: Calendar = .current,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> RoutineTask? {
        let taskDescriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )

        guard let task = try context.fetch(taskDescriptor).first else {
            return nil
        }

        let existingLogs = detailLogs(taskID: taskID, context: context)
        let matchingLogs = existingLogs.filter { log in
            guard let timestamp = log.timestamp else { return false }
            return calendar.isDate(timestamp, inSameDayAs: completedDay)
        }
        let didMatchLastDone = task.lastDone.map { calendar.isDate($0, inSameDayAs: completedDay) } ?? false
        let didMatchCanceledAt = task.canceledAt.map { calendar.isDate($0, inSameDayAs: completedDay) } ?? false

        guard !matchingLogs.isEmpty || didMatchLastDone || didMatchCanceledAt else {
            return task
        }

        for log in matchingLogs {
            context.delete(log)
        }
        if didMatchLastDone || matchingLogs.contains(where: { $0.kind == .completed }) {
            try removeFulfillmentsSourcedBy(
                taskID: taskID,
                on: completedDay,
                context: context,
                calendar: calendar
            )
        }

        let remainingLatestCompletion = existingLogs
            .filter { log in
                !matchingLogs.contains(where: { $0.id == log.id })
            }
            .filter { $0.kind.resolvesDoneDate }
            .compactMap(\.timestamp)
            .max()

        if didMatchLastDone {
            task.lastDone = remainingLatestCompletion
        }

        if didMatchCanceledAt {
            task.removeCanceledState()
        }

        if didMatchLastDone {
            task.refreshScheduleAnchorAfterRemovingLatestCompletion(
                remainingLatestCompletion: remainingLatestCompletion
            )
        }

        task.removeMultiDaySpan(containing: completedDay, calendar: calendar)
        task.resetStepProgress()
        task.resetChecklistProgress()

        DeviceActivityRecorder.recordAction(
            .deleted,
            entity: .routineLog,
            entityID: taskID,
            entityTitle: taskTitle(task),
            details: "Removed timeline entry",
            sourceDevice: sourceDevice,
            in: context
        )
        try context.save()
        return task
    }

    @MainActor
    static func removeLogEntry(
        taskID: UUID,
        timestamp: Date,
        context: ModelContext,
        calendar: Calendar = .current,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> RoutineTask? {
        let taskDescriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )

        guard let task = try context.fetch(taskDescriptor).first else {
            return nil
        }

        let existingLogs = detailLogs(taskID: taskID, context: context)
        let matchingLogs = existingLogs.filter { $0.timestamp == timestamp }
        let didMatchLastDone = task.lastDone == timestamp
        let didMatchCanceledAt = task.canceledAt == timestamp

        guard !matchingLogs.isEmpty || didMatchLastDone || didMatchCanceledAt else {
            return task
        }

        for log in matchingLogs {
            context.delete(log)
        }
        if didMatchLastDone || matchingLogs.contains(where: { $0.kind == .completed }) {
            try removeFulfillmentsSourcedBy(
                taskID: taskID,
                on: timestamp,
                context: context,
                calendar: calendar
            )
        }

        let remainingLatestCompletion = existingLogs
            .filter { log in
                !matchingLogs.contains(where: { $0.id == log.id })
            }
            .filter { $0.kind.resolvesDoneDate }
            .compactMap(\.timestamp)
            .max()

        if didMatchLastDone {
            task.lastDone = remainingLatestCompletion
            task.refreshScheduleAnchorAfterRemovingLatestCompletion(
                remainingLatestCompletion: remainingLatestCompletion
            )
        }

        if didMatchCanceledAt {
            task.removeCanceledState()
        }

        task.removeMultiDaySpan(containing: timestamp, calendar: calendar)
        task.resetStepProgress()
        task.resetChecklistProgress()

        DeviceActivityRecorder.recordAction(
            .deleted,
            entity: .routineLog,
            entityID: taskID,
            entityTitle: taskTitle(task),
            details: "Removed timeline entry",
            sourceDevice: sourceDevice,
            at: timestamp,
            in: context
        )
        try context.save()
        return task
    }

    private static func isSameCompletion(_ lhs: Date?, as rhs: Date) -> Bool {
        guard let lhs else { return false }
        return Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }

    private static func taskTitle(_ task: RoutineTask) -> String {
        RoutineTask.trimmedName(task.name) ?? "Untitled task"
    }

    private static func deleteNonCompletionResolutionLogs(
        on completedAt: Date,
        from logs: [RoutineLog],
        context: ModelContext,
        calendar: Calendar
    ) {
        deleteResolutionLogs(
            on: completedAt,
            matchingKinds: [.missed, .canceled],
            from: logs,
            context: context,
            calendar: calendar
        )
    }

    private static func deleteResolutionLogs(
        on date: Date,
        matchingKinds: [RoutineLogKind],
        from logs: [RoutineLog],
        context: ModelContext,
        calendar: Calendar
    ) {
        for log in logs {
            guard matchingKinds.contains(log.kind), let timestamp = log.timestamp else { continue }
            guard calendar.isDate(timestamp, inSameDayAs: date) else { continue }
            context.delete(log)
        }
    }

    @MainActor
    static func fulfillLinkedTasks(
        fromSourceTaskID sourceTaskID: UUID,
        completedAt: Date,
        context: ModelContext,
        calendar: Calendar = .current,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws {
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == sourceTaskID
            }
        )
        guard let sourceTask = try context.fetch(descriptor).first else { return }
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        try fulfillLinkedTasks(
            from: sourceTask,
            completedAt: completedAt,
            tasks: tasks,
            context: context,
            calendar: calendar,
            sourceDevice: sourceDevice
        )
    }

    @MainActor
    private static func fulfillLinkedTasks(
        from sourceTask: RoutineTask,
        completedAt: Date,
        tasks: [RoutineTask],
        context: ModelContext,
        calendar: Calendar,
        sourceDevice: RoutinaDeviceActivitySource?
    ) throws {
        let targets = fulfillmentTargets(
            for: sourceTask,
            in: tasks,
            completedAt: completedAt,
            calendar: calendar
        )
        guard !targets.isEmpty else { return }

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        for target in targets {
            let targetLogs = logs.filter { $0.taskID == target.id }
            let alreadyCompleted = targetLogs.contains { log in
                guard let timestamp = log.timestamp else { return false }
                return log.kind == .completed
                    && calendar.isDate(timestamp, inSameDayAs: completedAt)
            }
            guard !alreadyCompleted else { continue }

            let alreadyFulfilledBySource = targetLogs.contains { log in
                guard let timestamp = log.timestamp else { return false }
                return log.kind == .fulfilled
                    && log.sourceTaskID == sourceTask.id
                    && calendar.isDate(timestamp, inSameDayAs: completedAt)
            }
            guard !alreadyFulfilledBySource else { continue }

            let alreadyResolved = targetLogs.contains { log in
                guard let timestamp = log.timestamp else { return false }
                return log.kind.resolvesDoneDate
                    && calendar.isDate(timestamp, inSameDayAs: completedAt)
            }
            if !alreadyResolved {
                guard target.recordFulfillment(at: completedAt, calendar: calendar) else { continue }
            }

            deleteNonCompletionResolutionLogs(
                on: completedAt,
                from: targetLogs,
                context: context,
                calendar: calendar
            )
            context.insert(
                RoutineLog(
                    timestamp: completedAt,
                    taskID: target.id,
                    kind: .fulfilled,
                    sourceTaskID: sourceTask.id
                )
            )
            DeviceActivityRecorder.recordAction(
                .completed,
                entity: .task,
                entityID: target.id,
                entityTitle: taskTitle(target),
                details: "Fulfilled by \(taskTitle(sourceTask))",
                sourceDevice: sourceDevice,
                at: completedAt,
                in: context
            )
        }
    }

    private static func fulfillmentTargets(
        for sourceTask: RoutineTask,
        in tasks: [RoutineTask],
        completedAt: Date,
        calendar: Calendar
    ) -> [RoutineTask] {
        tasks.filter { candidate in
            guard candidate.id != sourceTask.id,
                  candidate.canBeFulfilledByLinkedTask(referenceDate: completedAt, calendar: calendar)
            else {
                return false
            }

            let candidateIsDoneWhenSource = candidate.relationships.contains { relationship in
                relationship.targetTaskID == sourceTask.id && relationship.kind == .doneWhen
            }
            let sourceCompletesCandidate = sourceTask.relationships.contains { relationship in
                relationship.targetTaskID == candidate.id && relationship.kind == .completes
            }
            return candidateIsDoneWhenSource || sourceCompletesCandidate
        }
    }

    @MainActor
    private static func removeFulfillmentsSourcedBy(
        taskID sourceTaskID: UUID,
        on date: Date,
        context: ModelContext,
        calendar: Calendar
    ) throws {
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        let matchingFulfillments = logs.filter { log in
            guard log.kind == .fulfilled,
                  log.sourceTaskID == sourceTaskID,
                  let timestamp = log.timestamp else {
                return false
            }
            return calendar.isDate(timestamp, inSameDayAs: date)
        }
        guard !matchingFulfillments.isEmpty else { return }

        let affectedTaskIDs = Set(matchingFulfillments.map(\.taskID))
        for log in matchingFulfillments {
            context.delete(log)
        }

        let removedLogIDs = Set(matchingFulfillments.map(\.id))
        let remainingLogsByTaskID = Dictionary(grouping: logs.filter { log in
            affectedTaskIDs.contains(log.taskID) && !removedLogIDs.contains(log.id)
        }, by: \.taskID)
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
            .filter { affectedTaskIDs.contains($0.id) }

        for task in tasks {
            let removedTaskFulfillments = matchingFulfillments.filter { $0.taskID == task.id }
            let removedMatchesLastDone = task.lastDone.map { lastDone in
                removedTaskFulfillments.contains { log in
                    guard let timestamp = log.timestamp else { return false }
                    return calendar.isDate(timestamp, inSameDayAs: lastDone)
                }
            } ?? false
            guard removedMatchesLastDone else { continue }

            let remainingLatestCompletion = remainingLogsByTaskID[task.id, default: []]
                .filter { $0.kind.resolvesDoneDate }
                .compactMap(\.timestamp)
                .max()
            task.lastDone = remainingLatestCompletion
            task.refreshScheduleAnchorAfterRemovingLatestCompletion(
                remainingLatestCompletion: remainingLatestCompletion
            )
            task.resetStepProgress()
            task.resetChecklistProgress()
        }
    }
}

private struct RoutineLogDeduplicationKey: Hashable {
    var taskID: UUID
    var kind: RoutineLogKind
    var sourceTaskID: UUID?
    var day: Date
}
