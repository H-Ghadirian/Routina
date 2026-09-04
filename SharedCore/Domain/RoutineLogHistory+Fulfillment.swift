import Foundation
import SwiftData

extension RoutineLogHistory {
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
    static func fulfillManuallySelectedLinkedTasks(
        fromSourceTaskID sourceTaskID: UUID,
        targetTaskIDs: Set<UUID>,
        completedAt: Date,
        context: ModelContext,
        calendar: Calendar = .current,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws {
        guard !targetTaskIDs.isEmpty else { return }
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == sourceTaskID
            }
        )
        guard let sourceTask = try context.fetch(descriptor).first else { return }
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let targets = manualFulfillmentTargets(
            for: sourceTask,
            selectedTargetIDs: targetTaskIDs,
            in: tasks,
            completedAt: completedAt,
            calendar: calendar
        )
        try recordFulfillments(
            from: sourceTask,
            targets: targets,
            completedAt: completedAt,
            context: context,
            calendar: calendar,
            sourceDevice: sourceDevice
        )
    }

    @MainActor
    static func fulfillLinkedTasks(
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
        try recordFulfillments(
            from: sourceTask,
            targets: targets,
            completedAt: completedAt,
            context: context,
            calendar: calendar,
            sourceDevice: sourceDevice
        )
    }

    @MainActor
    private static func recordFulfillments(
        from sourceTask: RoutineTask,
        targets: [RoutineTask],
        completedAt: Date,
        context: ModelContext,
        calendar: Calendar,
        sourceDevice: RoutinaDeviceActivitySource?
    ) throws {
        guard !targets.isEmpty else { return }

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        for target in targets {
            let targetLogs = logs.filter { $0.taskID == target.id }
            let fulfillmentDate: Date
            if target.recurrenceRule.usesAdvancedModel {
                let due = RoutineDateMath.dueDate(
                    for: target,
                    referenceDate: completedAt,
                    calendar: calendar
                )
                guard due != .distantFuture, due <= completedAt else { continue }
                fulfillmentDate = due
            } else {
                fulfillmentDate = completedAt
            }
            let alreadyCompleted = targetLogs.contains { log in
                log.kind == .completed
                    && isSameCompletion(
                        log.timestamp,
                        as: fulfillmentDate,
                        for: target,
                        calendar: calendar
                    )
            }
            guard !alreadyCompleted else { continue }

            let alreadyFulfilledBySource = targetLogs.contains { log in
                return log.kind == .fulfilled
                    && log.sourceTaskID == sourceTask.id
                    && isSameCompletion(
                        log.timestamp,
                        as: fulfillmentDate,
                        for: target,
                        calendar: calendar
                    )
            }
            guard !alreadyFulfilledBySource else { continue }

            let alreadyResolved = targetLogs.contains { log in
                return log.kind.resolvesDoneDate
                    && isSameCompletion(
                        log.timestamp,
                        as: fulfillmentDate,
                        for: target,
                        calendar: calendar
                    )
            }
            if !alreadyResolved {
                guard target.recordFulfillment(at: fulfillmentDate, calendar: calendar) else { continue }
            }

            deleteNonCompletionResolutionLogs(
                on: fulfillmentDate,
                for: target,
                from: targetLogs,
                context: context,
                calendar: calendar
            )
            context.insert(
                RoutineLog(
                    timestamp: fulfillmentDate,
                    scheduledOccurrenceAt: target.lastSatisfiedScheduledOccurrenceAt,
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
                at: fulfillmentDate,
                in: context
            )
        }
    }

    private static func manualFulfillmentTargets(
        for sourceTask: RoutineTask,
        selectedTargetIDs: Set<UUID>,
        in tasks: [RoutineTask],
        completedAt: Date,
        calendar: Calendar
    ) -> [RoutineTask] {
        tasks.filter { candidate in
            guard selectedTargetIDs.contains(candidate.id),
                candidate.id != sourceTask.id,
                candidate.canBeFulfilledByLinkedTask(referenceDate: completedAt, calendar: calendar)
            else {
                return false
            }

            let candidateCanBeCompletedBySource = candidate.relationships.contains { relationship in
                relationship.targetTaskID == sourceTask.id
                    && relationship.kind == .canBeCompletedBy
            }
            let sourceCanCompleteCandidate = sourceTask.relationships.contains { relationship in
                relationship.targetTaskID == candidate.id
                    && relationship.kind == .canComplete
            }
            return candidateCanBeCompletedBySource || sourceCanCompleteCandidate
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
    static func removeFulfillmentsSourcedBy(
        taskID sourceTaskID: UUID,
        on date: Date,
        context: ModelContext,
        calendar: Calendar
    ) throws {
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        let matchingFulfillments = logs.filter { log in
            guard log.kind == .fulfilled,
                log.sourceTaskID == sourceTaskID,
                let timestamp = log.timestamp
            else {
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
        let remainingLogsByTaskID = Dictionary(
            grouping: logs.filter { log in
                affectedTaskIDs.contains(log.taskID) && !removedLogIDs.contains(log.id)
            }, by: \.taskID)
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
            .filter { affectedTaskIDs.contains($0.id) }

        for task in tasks {
            let removedTaskFulfillments = matchingFulfillments.filter { $0.taskID == task.id }
            let removedMatchesLastDone =
                task.lastDone.map { lastDone in
                    removedTaskFulfillments.contains { log in
                        guard let timestamp = log.timestamp else { return false }
                        return calendar.isDate(timestamp, inSameDayAs: lastDone)
                    }
                } ?? false
            guard removedMatchesLastDone else { continue }

            let remainingLatestLog = remainingLogsByTaskID[task.id, default: []]
                .filter { $0.kind.resolvesDoneDate }
                .max { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
            let remainingLatestCompletion = remainingLatestLog?.timestamp
            task.lastDone = remainingLatestCompletion
            task.lastSatisfiedScheduledOccurrenceAt = remainingLatestLog?.scheduledOccurrenceAt
            task.refreshScheduleAnchorAfterRemovingLatestCompletion(
                remainingLatestCompletion: remainingLatestCompletion
            )
            task.resetStepProgress()
            task.resetChecklistProgress()
        }
    }
}
