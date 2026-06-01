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
                    && log.kind == .completed
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
            log.kind == .completed && isSameCompletion(log.timestamp, as: lastDone)
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

        let existingLogs = detailLogs(taskID: taskID, context: context)
        let hasMatchingLog = existingLogs.contains { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind == .completed && calendar.isDate(timestamp, inSameDayAs: completedAt)
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
            return log.kind == .completed && calendar.isDate(timestamp, inSameDayAs: occurrence)
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
            return log.kind == .completed && calendar.isDate(timestamp, inSameDayAs: occurrence)
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
                return log.kind == .completed && calendar.isDate(timestamp, inSameDayAs: day)
            }
            if alreadyCompleted {
                continue
            }

            let completionDate = RoutineAssumedCompletion.completionTimestamp(
                for: day,
                referenceDate: referenceDate,
                calendar: calendar
            )
            let result = task.advance(completedAt: completionDate, calendar: calendar)
            switch result {
            case .completedRoutine:
                context.insert(RoutineLog(timestamp: completionDate, taskID: taskID, kind: .completed))
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
                return log.kind == .completed && calendar.isDate(timestamp, inSameDayAs: completedAt)
            }) {
                let currentTimestamp = existingLog.timestamp ?? .distantPast
                if completedAt > currentTimestamp {
                    existingLog.timestamp = completedAt
                }
            } else {
                context.insert(RoutineLog(timestamp: completedAt, taskID: taskID, kind: .completed))
            }

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
    static func markDueChecklistItemsPurchased(
        taskID: UUID,
        purchasedAt: Date,
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

        let dueItemIDs = Set(task.dueChecklistItems(referenceDate: purchasedAt, calendar: calendar).map(\.id))
        guard !dueItemIDs.isEmpty else { return nil }

        return try markChecklistItemsPurchased(
            taskID: taskID,
            itemIDs: dueItemIDs,
            purchasedAt: purchasedAt,
            context: context,
            calendar: calendar,
            sourceDevice: sourceDevice
        )
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
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )

        guard let task = try context.fetch(descriptor).first else {
            return nil
        }

        let updatedItemCount = task.markChecklistItemsPurchased(itemIDs, purchasedAt: purchasedAt)
        guard updatedItemCount > 0 else {
            return nil
        }

        let existingLogs = detailLogs(taskID: taskID, context: context)
        if let existingLog = existingLogs.first(where: { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind == .completed && calendar.isDate(timestamp, inSameDayAs: purchasedAt)
        }) {
            let currentTimestamp = existingLog.timestamp ?? .distantPast
            if purchasedAt > currentTimestamp {
                existingLog.timestamp = purchasedAt
            }
        } else {
            context.insert(RoutineLog(timestamp: purchasedAt, taskID: taskID, kind: .completed))
        }

        DeviceActivityRecorder.recordAction(
            .completed,
            entity: .task,
            entityID: taskID,
            entityTitle: taskTitle(task),
            details: "Completed \(updatedItemCount) checklist item(s)",
            sourceDevice: sourceDevice,
            at: purchasedAt,
            in: context
        )
        try context.save()
        return (task, updatedItemCount)
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

        let remainingLatestCompletion = existingLogs
            .filter { log in
                !matchingLogs.contains(where: { $0.id == log.id })
            }
            .filter { $0.kind == .completed }
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

        let remainingLatestCompletion = existingLogs
            .filter { log in
                !matchingLogs.contains(where: { $0.id == log.id })
            }
            .filter { $0.kind == .completed }
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
}

private struct RoutineLogDeduplicationKey: Hashable {
    var taskID: UUID
    var kind: RoutineLogKind
    var day: Date
}
