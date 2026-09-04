import Foundation
import SwiftData

extension RoutineLogHistory {
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
        let removedLatestCompletionTimestamp = task.lastDone
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

        let remainingLatestLog =
            existingLogs
            .filter { log in
                !matchingLogs.contains(where: { $0.id == log.id })
            }
            .filter { $0.kind.resolvesDoneDate }
            .max { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
        let remainingLatestCompletion = remainingLatestLog?.timestamp

        if didMatchLastDone {
            task.lastDone = remainingLatestCompletion
            task.lastSatisfiedScheduledOccurrenceAt = remainingLatestLog?.scheduledOccurrenceAt
            let shouldClearAutoPause =
                task.autoPauseAfterCompletion
                && task.pausedAt == removedLatestCompletionTimestamp
            if shouldClearAutoPause {
                task.pausedAt = nil
                task.pauseUntil = nil
            }
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

        let remainingLatestLog =
            existingLogs
            .filter { log in
                !matchingLogs.contains(where: { $0.id == log.id })
            }
            .filter { $0.kind.resolvesDoneDate }
            .max { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
        let remainingLatestCompletion = remainingLatestLog?.timestamp

        if didMatchLastDone {
            task.lastDone = remainingLatestCompletion
            task.lastSatisfiedScheduledOccurrenceAt = remainingLatestLog?.scheduledOccurrenceAt
            let shouldClearAutoPause =
                task.autoPauseAfterCompletion && task.pausedAt == timestamp
            if shouldClearAutoPause {
                task.pausedAt = nil
                task.pauseUntil = nil
            }
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

}
