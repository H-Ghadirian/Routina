import Foundation
import SwiftData

enum RoutineLogHistory {
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
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> (task: RoutineTask, result: RoutineAdvanceResult)? {
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )

        guard let task = try context.fetch(descriptor).first else {
            return nil
        }

        let existingLogs = detailLogs(taskID: taskID, context: context)
        let hasMatchingLog = existingLogs.contains { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind == .completed && calendar.isDate(timestamp, inSameDayAs: completedAt)
        }
        if hasMatchingLog {
            return (task, .ignoredAlreadyCompletedToday)
        }

        let result = task.advance(completedAt: completedAt, calendar: calendar)
        switch result {
        case .ignoredPaused, .ignoredAlreadyCompletedToday:
            return (task, result)

        case .advancedStep, .advancedChecklist:
            try context.save()
            return (task, result)

        case .completedRoutine:
            context.insert(RoutineLog(timestamp: completedAt, taskID: taskID, kind: .completed))
            try context.save()
            return (task, result)
        }
    }

    @MainActor
    static func confirmTaskCompletions(
        taskID: UUID,
        on days: [Date],
        context: ModelContext,
        referenceDate: Date = .now,
        calendar: Calendar = .current
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
        calendar: Calendar = .current
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

            try context.save()
            return (task, result)
        }
    }

    @discardableResult
    static func unmarkChecklistItem(
        taskID: UUID,
        itemID: UUID,
        context: ModelContext
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

        try context.save()
        return task
    }

    @MainActor
    static func markDueChecklistItemsPurchased(
        taskID: UUID,
        purchasedAt: Date,
        context: ModelContext,
        calendar: Calendar = .current
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
            calendar: calendar
        )
    }

    @MainActor
    static func markChecklistItemsPurchased(
        taskID: UUID,
        itemIDs: Set<UUID>,
        purchasedAt: Date,
        context: ModelContext,
        calendar: Calendar = .current
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

        try context.save()
        return (task, updatedItemCount)
    }

    @MainActor
    static func cancelTask(
        taskID: UUID,
        canceledAt: Date,
        context: ModelContext,
        calendar: Calendar = .current
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

        try context.save()
        return task
    }

    @MainActor
    static func removeCompletion(
        taskID: UUID,
        on completedDay: Date,
        context: ModelContext,
        calendar: Calendar = .current
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

        try context.save()
        return task
    }

    @MainActor
    static func removeLogEntry(
        taskID: UUID,
        timestamp: Date,
        context: ModelContext
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

        try context.save()
        return task
    }

    private static func isSameCompletion(_ lhs: Date?, as rhs: Date) -> Bool {
        guard let lhs else { return false }
        return Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }
}
