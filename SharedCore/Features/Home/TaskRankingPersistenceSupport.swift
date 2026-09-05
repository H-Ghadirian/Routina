import ComposableArchitecture
import Foundation
import SwiftData

extension TaskRankingFeature {
    func loadTasks() -> Effect<Action> {
        .run { @MainActor send in
            do {
                let tasks = try modelContext().fetch(FetchDescriptor<RoutineTask>())
                let logs = try modelContext().fetch(FetchDescriptor<RoutineLog>())
                let completionDatesByTaskID = HomeTaskSupport.makeDoneStats(
                    tasks: tasks,
                    logs: logs
                ).completedDatesByTaskID
                send(
                    .tasksLoaded(
                        tasks,
                        appSettingsClient.flagRules(),
                        appSettingsClient.taskLadderOrganization(),
                        completionDatesByTaskID
                    ))
            } catch {
                send(.loadFailed("Couldn’t load task ranking. \(error.localizedDescription)"))
            }
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }

    func persist(_ update: TaskRankingOrderUpdate) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                var tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                var organization = appSettingsClient.taskLadderOrganization()
                TaskRankingOrderingSupport.apply(
                    update,
                    to: &tasks,
                    organization: &organization
                )
                try context.save()
                appSettingsClient.setTaskLadderOrganization(organization)
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                send(.loadFailed("Couldn’t update task ranking. \(error.localizedDescription)"))
            }
        }
    }

    func persistPlacement(
        taskID: UUID,
        parent: TaskLadderNodeID?,
        behavior: TaskLadderCompletionBehavior
    ) -> Effect<Action> {
        .run { @MainActor send in
            guard case let .task(parentTaskID)? = parent else { return }
            do {
                _ = try RoutineTaskRelationshipMutationSupport.setCompletionBehavior(
                    sourceTaskID: taskID,
                    targetTaskID: parentTaskID,
                    behavior: behavior,
                    timestamp: now,
                    calendar: calendar,
                    context: modelContext()
                )
            } catch {
                send(.loadFailed("Couldn’t update completion behavior. \(error.localizedDescription)"))
            }
        }
    }

    func persistTemporalWeightRule(
        taskID: UUID,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        pressure: RoutineTaskPressure,
        rule: RoutineTaskTemporalWeightRule?
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                guard let task = tasks.first(where: { $0.id == taskID }) else {
                    send(.loadFailed("Couldn’t find that task to update its changes over time."))
                    return
                }
                task.importance = importance
                task.urgency = urgency
                task.pressure = pressure
                task.priority = AddRoutinePriorityMatrix.priority(
                    importance: importance,
                    urgency: urgency
                )
                task.temporalWeightRule = RoutineTaskTemporalWeightResolver.sanitizedRule(
                    rule,
                    for: task
                )
                task.hasExplicitImportance = true
                task.hasExplicitUrgency = true
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                send(.loadFailed("Couldn’t update changes over time. \(error.localizedDescription)"))
            }
        }
    }

    func updateCompletionBehavior(
        _ behavior: TaskLadderCompletionBehavior,
        sourceTaskID: UUID,
        parentTaskID: UUID,
        tasks: inout [RoutineTask]
    ) {
        guard let sourceIndex = tasks.firstIndex(where: { $0.id == sourceTaskID }) else { return }
        let candidates = RoutineTaskRelationshipCandidate.from(
            tasks,
            excluding: sourceTaskID,
            referenceDate: now,
            calendar: calendar
        )
        var relationships = RoutineTask.editableRelationships(
            for: tasks[sourceIndex],
            within: candidates
        )
        relationships.removeAll { relationship in
            relationship.targetTaskID == parentTaskID
                && (relationship.kind == .canComplete || relationship.kind == .completes)
        }
        if let kind = behavior.relationshipKind {
            relationships.removeAll { $0.targetTaskID == parentTaskID }
            relationships.append(RoutineTaskRelationship(targetTaskID: parentTaskID, kind: kind))
        }
        tasks[sourceIndex].replaceRelationships(relationships)
        RoutineTask.removeInverseRelationships(targeting: sourceTaskID, from: tasks)
    }
}
