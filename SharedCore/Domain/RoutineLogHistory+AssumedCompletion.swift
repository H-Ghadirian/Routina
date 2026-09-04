import Foundation
import SwiftData

extension RoutineLogHistory {
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
                context.insert(
                    RoutineLog(
                        timestamp: completionDate,
                        scheduledOccurrenceAt: task.lastSatisfiedScheduledOccurrenceAt,
                        taskID: taskID,
                        kind: .completed,
                        isConfirmedAssumedDone: true
                    ))
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
        guard
            RoutineAssumedCompletion.isAssumedDone(
                for: task,
                on: day,
                referenceDate: referenceDate,
                logs: existingLogs,
                calendar: calendar
            )
        else {
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

}
