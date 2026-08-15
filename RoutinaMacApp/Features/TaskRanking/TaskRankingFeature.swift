import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct TaskRankingFeature {
    private enum CancelID: Hashable {
        case load
        case automaticRefresh
        case taskDetail(UUID)
    }

    @ObservableState
    struct State: Equatable {
        var tasks: [RoutineTask] = []
        var flagRules: [RoutineFlagRule] = []
        var organization = TaskLadderOrganization()
        var metric: TaskRankingMetric = .pressure
        var reversedMetrics: Set<TaskRankingMetric> = []
        var scopePath: [UUID] = []
        var presentation = TaskRankingPresentation.empty()
        var selectedTaskID: UUID?
        var taskDetailState: TaskDetailFeature.State?
        var isLoading = false
        var errorMessage: String?

        var isReversed: Bool {
            reversedMetrics.contains(metric)
        }

        var scopeParentTask: RoutineTask? {
            guard let scopeParentTaskID = scopePath.last else { return nil }
            guard organization.group(id: scopeParentTaskID) == nil else { return nil }
            return tasks.first(where: { $0.id == scopeParentTaskID })
        }

        var scopeParentGroup: TaskLadderGroup? {
            guard let scopeParentID = scopePath.last else { return nil }
            return organization.group(id: scopeParentID)
        }

        var scopeParentName: String? {
            scopeParentGroup?.displayName ?? scopeParentTask?.name
        }
    }

    enum Action: Equatable {
        case onAppear
        case onDisappear
        case refresh
        case routineDataChanged
        case tasksLoaded([RoutineTask], [RoutineFlagRule], TaskLadderOrganization)
        case flagRulesChanged
        case organizationChanged
        case loadFailed(String)
        case errorDismissed
        case reversedMetricsChanged(Set<TaskRankingMetric>)
        case metricChanged(TaskRankingMetric)
        case directionToggled
        case taskSelected(UUID)
        case childLadderOpened(UUID)
        case scopeBackTapped
        case moveTask(UUID, TaskRankingMoveDirection)
        case groupSaved(TaskLadderGroup)
        case groupDeleted(UUID)
        case taskPlacementSaved(UUID, TaskLadderNodeID?, TaskLadderCompletionBehavior)
        case taskDetail(TaskDetailFeature.Action)
    }

    @Dependency(\.appSettingsClient) private var appSettingsClient
    @Dependency(\.calendar) private var calendar
    @Dependency(\.continuousClock) private var continuousClock
    @Dependency(\.date.now) private var now
    @Dependency(\.modelContext) private var modelContext

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.tasks.isEmpty, !state.isLoading else { return .none }
                state.isLoading = true
                return loadTasks()

            case .onDisappear:
                return .merge(
                    .cancel(id: CancelID.load),
                    .cancel(id: CancelID.automaticRefresh),
                    state.selectedTaskID.map { .cancel(id: CancelID.taskDetail($0)) } ?? .none
                )

            case .refresh:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                return loadTasks()

            case .routineDataChanged:
                return .run { send in
                    try await continuousClock.sleep(for: .milliseconds(450))
                    await send(.refresh)
                }
                .cancellable(id: CancelID.automaticRefresh, cancelInFlight: true)

            case let .tasksLoaded(tasks, flagRules, organization):
                state.tasks = tasks
                state.flagRules = RoutineFlagRules.sanitized(flagRules)
                state.organization = organization.sanitized(validTaskIDs: Set(tasks.map(\.id)))
                state.isLoading = false
                state.errorMessage = nil
                let loadedNodeIDs = Set(tasks.map(\.id)).union(state.organization.groups.map(\.id))
                if state.scopePath.contains(where: { !loadedNodeIDs.contains($0) }) {
                    state.scopePath = []
                }
                rebuildPresentation(&state)
                if let selectedTaskID = state.selectedTaskID,
                   !tasks.contains(where: { $0.id == selectedTaskID }) {
                    state.selectedTaskID = nil
                    state.taskDetailState = nil
                }
                return .none

            case .flagRulesChanged:
                state.flagRules = RoutineFlagRules.sanitized(appSettingsClient.flagRules())
                rebuildPresentation(&state)
                return .none

            case .organizationChanged:
                state.organization = appSettingsClient.taskLadderOrganization()
                    .sanitized(validTaskIDs: Set(state.tasks.map(\.id)))
                rebuildPresentation(&state)
                return .none

            case let .loadFailed(message):
                state.isLoading = false
                state.errorMessage = message
                return .none

            case .errorDismissed:
                state.errorMessage = nil
                return .none

            case let .reversedMetricsChanged(metrics):
                state.reversedMetrics = metrics
                rebuildPresentation(&state)
                return .none

            case let .metricChanged(metric):
                guard state.metric != metric else { return .none }
                state.metric = metric
                rebuildPresentation(&state)
                return .none

            case .directionToggled:
                if state.reversedMetrics.contains(state.metric) {
                    state.reversedMetrics.remove(state.metric)
                } else {
                    state.reversedMetrics.insert(state.metric)
                }
                rebuildPresentation(&state)
                return .none

            case let .taskSelected(taskID):
                guard let task = state.tasks.first(where: { $0.id == taskID }) else { return .none }
                selectTask(task, state: &state)
                return .send(.taskDetail(.onAppear))

            case let .childLadderOpened(nodeID):
                guard !state.scopePath.contains(nodeID),
                      let metadata = state.presentation.rowMetadataByTaskID[nodeID],
                      metadata.childCount > 0 || metadata.isGroup else {
                    return .none
                }
                state.scopePath.append(nodeID)
                if let task = state.tasks.first(where: { $0.id == nodeID }) {
                    selectTask(task, state: &state)
                } else {
                    state.selectedTaskID = nil
                    state.taskDetailState = nil
                }
                rebuildPresentation(&state)
                return state.taskDetailState == nil ? .none : .send(.taskDetail(.onAppear))

            case .scopeBackTapped:
                guard !state.scopePath.isEmpty else { return .none }
                state.scopePath.removeLast()
                rebuildPresentation(&state)
                return .none

            case let .moveTask(taskID, direction):
                guard let update = TaskRankingOrderingSupport.moveTask(
                    taskID: taskID,
                    direction: direction,
                    in: state.presentation
                ) else {
                    return .none
                }
                var tasks = state.tasks
                var organization = state.organization
                TaskRankingOrderingSupport.apply(
                    update,
                    to: &tasks,
                    organization: &organization
                )
                state.tasks = tasks
                state.organization = organization
                rebuildPresentation(&state)
                return persist(update)

            case let .groupSaved(group):
                state.organization.upsert(group)
                state.organization = state.organization.sanitized(validTaskIDs: Set(state.tasks.map(\.id)))
                rebuildPresentation(&state)
                appSettingsClient.setTaskLadderOrganization(state.organization)
                return .none

            case let .groupDeleted(groupID):
                state.organization.deleteGroup(id: groupID)
                if state.scopePath.contains(groupID) {
                    state.scopePath = []
                }
                rebuildPresentation(&state)
                appSettingsClient.setTaskLadderOrganization(state.organization)
                return .none

            case let .taskPlacementSaved(taskID, parent, behavior):
                let validTaskIDs = Set(state.tasks.map(\.id))
                guard state.organization.place(
                    taskID: taskID,
                    inside: parent,
                    validTaskIDs: validTaskIDs
                ) else {
                    state.errorMessage = "That placement would create an invalid Task Ladder hierarchy."
                    return .none
                }
                if case let .task(parentTaskID)? = parent {
                    updateCompletionBehavior(
                        behavior,
                        sourceTaskID: taskID,
                        parentTaskID: parentTaskID,
                        tasks: &state.tasks
                    )
                }
                rebuildPresentation(&state)
                let organization = state.organization
                appSettingsClient.setTaskLadderOrganization(organization)
                return persistPlacement(
                    taskID: taskID,
                    parent: parent,
                    behavior: behavior
                )

            case let .taskDetail(taskDetailAction):
                guard var taskDetailState = state.taskDetailState else { return .none }
                let taskID = taskDetailState.task.id
                let effect = TaskDetailFeature()
                    .reduce(into: &taskDetailState, action: taskDetailAction)
                    .map(Action.taskDetail)
                    .cancellable(id: CancelID.taskDetail(taskID))
                state.taskDetailState = taskDetailState
                if let taskIndex = state.tasks.firstIndex(where: { $0.id == taskID }) {
                    state.tasks[taskIndex] = taskDetailState.task.detachedCopy()
                    rebuildPresentation(&state)
                }
                return effect
            }
        }
    }

    private func rebuildPresentation(_ state: inout State) {
        state.presentation = TaskRankingPresentation.make(
            tasks: state.tasks,
            organization: state.organization,
            flagRules: state.flagRules,
            metric: state.metric,
            isReversed: state.isReversed,
            referenceDate: now,
            calendar: calendar,
            scopePath: state.scopePath
        )
    }

    private func selectTask(_ task: RoutineTask, state: inout State) {
        state.selectedTaskID = task.id
        state.taskDetailState = HomeTaskSupport.makeTaskDetailState(
            for: task,
            now: now,
            calendar: calendar
        )
    }

    private func loadTasks() -> Effect<Action> {
        .run { @MainActor send in
            do {
                let tasks = try modelContext().fetch(FetchDescriptor<RoutineTask>())
                await send(.tasksLoaded(
                    tasks,
                    appSettingsClient.flagRules(),
                    appSettingsClient.taskLadderOrganization()
                ))
            } catch {
                await send(.loadFailed("Couldn’t load task ranking. \(error.localizedDescription)"))
            }
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }

    private func persist(_ update: TaskRankingOrderUpdate) -> Effect<Action> {
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
                await send(.loadFailed("Couldn’t update task ranking. \(error.localizedDescription)"))
            }
        }
    }

    private func persistPlacement(
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
                await send(.loadFailed("Couldn’t update completion behavior. \(error.localizedDescription)"))
            }
        }
    }

    private func updateCompletionBehavior(
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
