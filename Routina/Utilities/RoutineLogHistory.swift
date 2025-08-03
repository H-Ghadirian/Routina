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
                log.taskID == task.id && isSameCompletion(log.timestamp, as: lastDone)
            }

            guard !hasMatchingLog else { continue }
            context.insert(RoutineLog(timestamp: lastDone, taskID: task.id))
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
            isSameCompletion(log.timestamp, as: lastDone)
        }

        guard !hasMatchingLog else { return false }
        context.insert(RoutineLog(timestamp: lastDone, taskID: taskID))
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
            return calendar.isDate(timestamp, inSameDayAs: completedAt)
        }
        if hasMatchingLog {
            return (task, .ignoredAlreadyCompletedToday)
        }

        let result = task.advance(completedAt: completedAt, calendar: calendar)
        switch result {
        case .ignoredPaused, .ignoredAlreadyCompletedToday:
            return (task, result)

        case .advancedStep:
            try context.save()
            return (task, result)

        case .completedRoutine:
            context.insert(RoutineLog(timestamp: completedAt, taskID: taskID))
            try context.save()
            return (task, result)
        }
    }

    private static func isSameCompletion(_ lhs: Date?, as rhs: Date) -> Bool {
        guard let lhs else { return false }
        return Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }
}
