import Foundation
import SwiftData

extension RoutineLogHistory {
    @MainActor
    static func advanceTask(
        taskID: UUID,
        completedAt: Date,
        referenceDate: Date? = nil,
        allowEarlyScheduledCompletion: Bool = false,
        actualDurationMinutes: Int? = nil,
        hasSpecificWorkTime: Bool? = nil,
        isConfirmedAssumedDone: Bool = false,
        context: ModelContext,
        calendar: Calendar = .current,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> (task: RoutineTask, result: RoutineAdvanceResult)? {
        guard let task = try fetchTask(taskID: taskID, context: context) else {
            return nil
        }
        guard !task.blocksManualCompletionForIncompleteChecklist else {
            return nil
        }

        let sanitizedDuration = RoutineLog.sanitizedActualDurationMinutes(actualDurationMinutes)
        let rejectsEarlyCompletion =
            RoutineDateMath.canCompleteScheduledOccurrenceEarly(
                for: task,
                completedAt: completedAt,
                calendar: calendar
            ) && !allowEarlyScheduledCompletion
        guard !rejectsEarlyCompletion else {
            return (task, .ignoredAlreadyCompletedToday)
        }
        guard
            let resolvedCompletedAt = resolvedCompletionDate(
                for: task,
                completedAt: completedAt,
                allowEarlyScheduledCompletion: allowEarlyScheduledCompletion,
                calendar: calendar
            )
        else {
            return (task, .ignoredAlreadyCompletedToday)
        }

        let allTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let existingLogs = detailLogs(taskID: taskID, context: context)
        if hasRecordedCompletion(
            at: resolvedCompletedAt,
            for: task,
            in: existingLogs,
            calendar: calendar
        ) {
            if BatteryRoutineService.dismissCompletedLowBatteryPrompt(
                for: task,
                at: resolvedCompletedAt
            ) {
                try context.save()
            }
            return (task, .ignoredAlreadyCompletedToday)
        }

        if let referenceDate {
            task.preserveCurrentScheduleAnchorForBackfill(
                completedAt: resolvedCompletedAt,
                referenceDate: referenceDate
            )
        }

        let result = task.advance(completedAt: resolvedCompletedAt, calendar: calendar)
        switch result {
        case .ignoredPaused, .ignoredAlreadyCompletedToday:
            return (task, result)

        case .advancedStep, .advancedChecklist:
            try recordAdvancedProgress(
                for: task,
                completedAt: resolvedCompletedAt,
                sourceDevice: sourceDevice,
                context: context
            )
            return (task, result)

        case .completedRoutine:
            try recordCompletedRoutine(
                RoutineAdvanceCompletionContext(
                    task: task,
                    completedAt: resolvedCompletedAt,
                    actualDurationMinutes: sanitizedDuration,
                    hasSpecificWorkTime: hasSpecificWorkTime,
                    isConfirmedAssumedDone: isConfirmedAssumedDone,
                    existingLogs: existingLogs,
                    allTasks: allTasks,
                    context: context,
                    calendar: calendar,
                    sourceDevice: sourceDevice
                )
            )
            return (task, result)
        }
    }

    @MainActor
    private static func fetchTask(
        taskID: UUID,
        context: ModelContext
    ) throws -> RoutineTask? {
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )
        return try context.fetch(descriptor).first
    }

    private static func resolvedCompletionDate(
        for task: RoutineTask,
        completedAt: Date,
        allowEarlyScheduledCompletion: Bool,
        calendar: Calendar
    ) -> Date? {
        guard task.usesEffectiveRoutineCadence, task.recurrenceRule.usesAdvancedModel else {
            return completedAt
        }

        let matchesExactTimedOccurrence =
            RoutineDateMath.usesExactTimedOccurrences(for: task)
            && RoutineDateMath.scheduledOccurrences(
                for: task,
                on: completedAt,
                calendar: calendar
            ).contains {
                RoutineOccurrenceIdentity.matches(
                    $0,
                    completedAt,
                    for: task,
                    calendar: calendar
                )
            }
        if matchesExactTimedOccurrence {
            return completedAt
        }

        let due = RoutineDateMath.dueDate(
            for: task,
            referenceDate: completedAt,
            calendar: calendar
        )
        guard due != .distantFuture else {
            return nil
        }
        if due <= completedAt {
            return due
        }
        guard
            allowEarlyScheduledCompletion,
            RoutineDateMath.supportsEarlyScheduledCompletion(for: task)
        else {
            return nil
        }
        return completedAt
    }

    private static func hasRecordedCompletion(
        at completedAt: Date,
        for task: RoutineTask,
        in logs: [RoutineLog],
        calendar: Calendar
    ) -> Bool {
        logs.contains { log in
            guard let timestamp = log.timestamp, log.kind.resolvesDoneDate else {
                return false
            }
            return RoutineOccurrenceIdentity.matches(
                timestamp,
                completedAt,
                for: task,
                calendar: calendar
            )
        }
    }

    @MainActor
    private static func recordAdvancedProgress(
        for task: RoutineTask,
        completedAt: Date,
        sourceDevice: RoutinaDeviceActivitySource?,
        context: ModelContext
    ) throws {
        DeviceActivityRecorder.recordAction(
            .updated,
            entity: .task,
            entityID: task.id,
            entityTitle: taskTitle(task),
            details: "Advanced task progress",
            sourceDevice: sourceDevice,
            at: completedAt,
            in: context
        )
        try context.save()
    }

    @MainActor
    private static func recordCompletedRoutine(
        _ completion: RoutineAdvanceCompletionContext
    ) throws {
        let task = completion.task
        if task.isOneOffTask, let actualDurationMinutes = completion.actualDurationMinutes {
            task.actualDurationMinutes = RoutineTask.sanitizedActualDurationMinutes(
                actualDurationMinutes
            )
        }
        deleteNonCompletionResolutionLogs(
            on: completion.completedAt,
            for: task,
            from: completion.existingLogs,
            context: completion.context,
            calendar: completion.calendar
        )
        completion.context.insert(
            RoutineLog(
                timestamp: completion.completedAt,
                scheduledOccurrenceAt: task.lastSatisfiedScheduledOccurrenceAt,
                taskID: task.id,
                kind: .completed,
                actualDurationMinutes: completion.actualDurationMinutes,
                hasSpecificWorkTime: completion.actualDurationMinutes == nil
                    ? nil
                    : completion.hasSpecificWorkTime,
                isConfirmedAssumedDone: completion.isConfirmedAssumedDone
            )
        )
        try fulfillLinkedTasks(
            from: task,
            completedAt: completion.completedAt,
            tasks: completion.allTasks,
            context: completion.context,
            calendar: completion.calendar,
            sourceDevice: completion.sourceDevice
        )
        _ = BatteryRoutineService.dismissCompletedLowBatteryPrompt(
            for: task,
            at: completion.completedAt
        )
        DeviceActivityRecorder.recordAction(
            .completed,
            entity: .task,
            entityID: task.id,
            entityTitle: taskTitle(task),
            sourceDevice: completion.sourceDevice,
            at: completion.completedAt,
            in: completion.context
        )
        try completion.context.save()
    }

}

private struct RoutineAdvanceCompletionContext {
    let task: RoutineTask
    let completedAt: Date
    let actualDurationMinutes: Int?
    let hasSpecificWorkTime: Bool?
    let isConfirmedAssumedDone: Bool
    let existingLogs: [RoutineLog]
    let allTasks: [RoutineTask]
    let context: ModelContext
    let calendar: Calendar
    let sourceDevice: RoutinaDeviceActivitySource?
}
