import Foundation
import SwiftData

extension RoutineLogHistory {
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
        guard RoutineDateMath.usesExactTimedOccurrences(for: task) else {
            return task
        }
        let scheduledOccurrences = RoutineDateMath.scheduledOccurrences(
            for: task,
            on: missedAt,
            calendar: calendar
        )
        let occurrence =
            RoutineOccurrenceIdentity.isTimestampScoped(for: task)
            ? scheduledOccurrences.first(where: {
                RoutineOccurrenceIdentity.matches($0, missedAt, for: task, calendar: calendar)
            })
            : scheduledOccurrences.first
        guard let occurrence else {
            return task
        }

        let existingLogs = detailLogs(taskID: taskID, context: context)
        let hasCompletedLog = existingLogs.contains { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind.resolvesDoneDate
                && RoutineOccurrenceIdentity.matches(timestamp, occurrence, for: task, calendar: calendar)
        }
        guard !hasCompletedLog else {
            return task
        }

        deleteResolutionLogs(
            on: occurrence,
            matchingKinds: [.canceled],
            from: existingLogs,
            context: context,
            calendar: calendar,
            matchesExactOccurrence: RoutineOccurrenceIdentity.isTimestampScoped(for: task)
        )

        if let existingMissedLog = existingLogs.first(where: { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind == .missed
                && RoutineOccurrenceIdentity.matches(timestamp, occurrence, for: task, calendar: calendar)
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
        guard RoutineDateMath.usesExactTimedOccurrences(for: task) else {
            return task
        }
        let scheduledOccurrences = RoutineDateMath.scheduledOccurrences(
            for: task,
            on: canceledAt,
            calendar: calendar
        )
        let occurrence =
            RoutineOccurrenceIdentity.isTimestampScoped(for: task)
            ? scheduledOccurrences.first(where: {
                RoutineOccurrenceIdentity.matches($0, canceledAt, for: task, calendar: calendar)
            })
            : scheduledOccurrences.first
        guard let occurrence else {
            return task
        }

        let existingLogs = detailLogs(taskID: taskID, context: context)
        let hasCompletedLog = existingLogs.contains { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind.resolvesDoneDate
                && RoutineOccurrenceIdentity.matches(timestamp, occurrence, for: task, calendar: calendar)
        }
        guard !hasCompletedLog else {
            return task
        }

        deleteResolutionLogs(
            on: occurrence,
            matchingKinds: [.missed],
            from: existingLogs,
            context: context,
            calendar: calendar,
            matchesExactOccurrence: RoutineOccurrenceIdentity.isTimestampScoped(for: task)
        )

        if let existingCanceledLog = existingLogs.first(where: { log in
            guard let timestamp = log.timestamp else { return false }
            return log.kind == .canceled
                && RoutineOccurrenceIdentity.matches(timestamp, occurrence, for: task, calendar: calendar)
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

}
