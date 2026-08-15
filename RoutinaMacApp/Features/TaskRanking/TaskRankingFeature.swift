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
        var metric: TaskRankingMetric = .pressure
        var reversedMetrics: Set<TaskRankingMetric> = []
        var presentation = TaskRankingPresentation.empty()
        var selectedTaskID: UUID?
        var taskDetailState: TaskDetailFeature.State?
        var isLoading = false
        var errorMessage: String?

        var isReversed: Bool {
            reversedMetrics.contains(metric)
        }
    }

    enum Action: Equatable {
        case onAppear
        case onDisappear
        case refresh
        case routineDataChanged
        case tasksLoaded([RoutineTask], [RoutineFlagRule])
        case flagRulesChanged
        case loadFailed(String)
        case errorDismissed
        case reversedMetricsChanged(Set<TaskRankingMetric>)
        case metricChanged(TaskRankingMetric)
        case directionToggled
        case taskSelected(UUID)
        case moveTask(UUID, TaskRankingMoveDirection)
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

            case let .tasksLoaded(tasks, flagRules):
                state.tasks = tasks
                state.flagRules = RoutineFlagRules.sanitized(flagRules)
                state.isLoading = false
                state.errorMessage = nil
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
                state.selectedTaskID = taskID
                state.taskDetailState = HomeTaskSupport.makeTaskDetailState(
                    for: task,
                    now: now,
                    calendar: calendar
                )
                return .send(.taskDetail(.onAppear))

            case let .moveTask(taskID, direction):
                guard let update = TaskRankingOrderingSupport.moveTask(
                    taskID: taskID,
                    direction: direction,
                    in: state.presentation
                ) else {
                    return .none
                }
                TaskRankingOrderingSupport.apply(update, to: &state.tasks)
                rebuildPresentation(&state)
                return persist(update)

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
            flagRules: state.flagRules,
            metric: state.metric,
            isReversed: state.isReversed,
            referenceDate: now,
            calendar: calendar
        )
    }

    private func loadTasks() -> Effect<Action> {
        .run { @MainActor send in
            do {
                let tasks = try modelContext().fetch(FetchDescriptor<RoutineTask>())
                await send(.tasksLoaded(tasks, appSettingsClient.flagRules()))
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
                TaskRankingOrderingSupport.apply(update, to: &tasks)
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                await send(.loadFailed("Couldn’t update task ranking. \(error.localizedDescription)"))
            }
        }
    }
}
