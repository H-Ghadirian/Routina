import Foundation
import SwiftData

enum RoutineLogHistory {
    static func deduplicateRedundantSameDayLogs(
        in context: ModelContext,
        calendar: Calendar = .current
    ) throws -> Bool {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let occurrenceLevelTaskIDs = Set(
            tasks.lazy.filter {
                RoutineOccurrenceIdentity.isTimestampScoped(for: $0)
            }.map(\.id))
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        var keptLogsByKey: [RoutineLogDeduplicationKey: RoutineLog] = [:]
        var didDeleteAny = false

        for log in logs {
            guard let timestamp = log.timestamp else { continue }
            let key = RoutineLogDeduplicationKey(
                taskID: log.taskID,
                kind: log.kind,
                sourceTaskID: log.sourceTaskID,
                resolutionDate: occurrenceLevelTaskIDs.contains(log.taskID)
                    ? timestamp
                    : calendar.startOfDay(for: timestamp)
            )

            guard let keptLog = keptLogsByKey[key] else {
                keptLogsByKey[key] = log
                continue
            }

            let keptTimestamp = keptLog.timestamp ?? .distantPast
            if timestamp > keptTimestamp {
                if log.scheduledOccurrenceAt == nil {
                    log.scheduledOccurrenceAt = keptLog.scheduledOccurrenceAt
                }
                context.delete(keptLog)
                keptLogsByKey[key] = log
            } else {
                if keptLog.scheduledOccurrenceAt == nil {
                    keptLog.scheduledOccurrenceAt = log.scheduledOccurrenceAt
                }
                context.delete(log)
            }
            didDeleteAny = true
        }

        guard didDeleteAny else { return false }
        try context.save()
        return true
    }

    static func backfillMissingLastDoneLogs(in context: ModelContext) throws -> Bool {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        var didInsertAny = false

        for task in tasks {
            guard let lastDone = task.lastDone else { continue }
            let hasMatchingLog = logs.contains { log in
                log.taskID == task.id
                    && log.kind.resolvesDoneDate
                    && isSameCompletion(log.timestamp, as: lastDone, for: task, calendar: .current)
            }

            guard !hasMatchingLog else { continue }
            context.insert(
                RoutineLog(
                    timestamp: lastDone,
                    scheduledOccurrenceAt: task.lastSatisfiedScheduledOccurrenceAt,
                    taskID: task.id,
                    kind: .completed
                ))
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
            let lastDone = task.lastDone
        else {
            return false
        }

        let logDescriptor = FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == taskID
            }
        )
        let logs = try context.fetch(logDescriptor)
        let hasMatchingLog = logs.contains { log in
            log.kind.resolvesDoneDate
                && isSameCompletion(log.timestamp, as: lastDone, for: task, calendar: .current)
        }

        guard !hasMatchingLog else { return false }
        context.insert(
            RoutineLog(
                timestamp: lastDone,
                scheduledOccurrenceAt: task.lastSatisfiedScheduledOccurrenceAt,
                taskID: taskID,
                kind: .completed
            ))
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

    static func isSameCompletion(
        _ lhs: Date?,
        as rhs: Date,
        for task: RoutineTask,
        calendar: Calendar
    ) -> Bool {
        guard let lhs else { return false }
        return RoutineOccurrenceIdentity.matches(lhs, rhs, for: task, calendar: calendar)
    }

    static func taskTitle(_ task: RoutineTask) -> String {
        RoutineTask.trimmedName(task.name) ?? "Untitled task"
    }

    static func deleteNonCompletionResolutionLogs(
        on completedAt: Date,
        for task: RoutineTask,
        from logs: [RoutineLog],
        context: ModelContext,
        calendar: Calendar
    ) {
        deleteResolutionLogs(
            on: completedAt,
            matchingKinds: [.missed, .canceled],
            from: logs,
            context: context,
            calendar: calendar,
            matchesExactOccurrence: RoutineOccurrenceIdentity.isTimestampScoped(for: task)
        )
    }

    static func deleteResolutionLogs(
        on date: Date,
        matchingKinds: [RoutineLogKind],
        from logs: [RoutineLog],
        context: ModelContext,
        calendar: Calendar,
        matchesExactOccurrence: Bool = false
    ) {
        for log in logs {
            guard matchingKinds.contains(log.kind), let timestamp = log.timestamp else { continue }
            let matchesDate = RoutineOccurrenceIdentity.matches(
                timestamp,
                date,
                timestampScoped: matchesExactOccurrence,
                calendar: calendar
            )
            guard matchesDate else { continue }
            context.delete(log)
        }
    }

}

private struct RoutineLogDeduplicationKey: Hashable {
    var taskID: UUID
    var kind: RoutineLogKind
    var sourceTaskID: UUID?
    var resolutionDate: Date
}
