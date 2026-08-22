import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct BacklogFeature {
    private enum CancelID: Hashable {
        case load
        case automaticRefresh
        case taskDetail(UUID)
    }

    @ObservableState
    struct State: Equatable {
        var tasks: [RoutineTask] = []
        var customSections: [HomeCustomTaskSection] = []
        var flagRules: [RoutineFlagRule] = []
        var presentation = BacklogTaskListPresentation.empty
        var searchText = ""
        var selectedTaskID: UUID?
        var taskDetailState: TaskDetailFeature.State?
        var isLoading = false
        var errorMessage: String?
    }

    enum Action: Equatable {
        case onAppear
        case onDisappear
        case workspaceDeactivated
        case refresh
        case routineDataChanged
        case automaticRefresh
        case tasksLoaded([RoutineTask], [HomeCustomTaskSection], [RoutineFlagRule])
        case loadFailed(String)
        case customSectionsChanged([HomeCustomTaskSection])
        case customSectionsDeleted([HomeCustomTaskSection], Set<UUID>)
        case searchTextChanged(String)
        case taskSelected(UUID)
        case taskDetail(TaskDetailFeature.Action)
        case moveTask(UUID, to: UUID?)
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

            case .workspaceDeactivated:
                let selectedTaskID = state.selectedTaskID
                state.selectedTaskID = nil
                state.taskDetailState = nil
                return selectedTaskID.map { .cancel(id: CancelID.taskDetail($0)) } ?? .none

            case .refresh:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                return loadTasks()

            case .routineDataChanged:
                return .run { send in
                    try await continuousClock.sleep(for: .milliseconds(450))
                    await send(.automaticRefresh)
                }
                .cancellable(id: CancelID.automaticRefresh, cancelInFlight: true)

            case .automaticRefresh:
                guard !state.isLoading else { return .none }
                return loadTasks()

            case let .tasksLoaded(tasks, customSections, flagRules):
                state.isLoading = false
                state.tasks = tasks
                state.customSections = customSections
                state.flagRules = RoutineFlagRules.sanitized(flagRules)
                state.errorMessage = nil
                rebuildPresentation(&state)

                if let selectedTaskID = state.selectedTaskID,
                   !tasks.contains(where: { $0.id == selectedTaskID }) {
                    state.selectedTaskID = nil
                    state.taskDetailState = nil
                }
                return .none

            case let .loadFailed(message):
                state.isLoading = false
                state.errorMessage = message
                return .none

            case let .customSectionsChanged(customSections):
                state.customSections = HomeCustomTaskSectionStorage.sanitized(customSections)
                rebuildPresentation(&state)
                return .none

            case let .customSectionsDeleted(customSections, removedSectionIDs):
                state.customSections = HomeCustomTaskSectionStorage.sanitized(customSections)
                rebuildPresentation(&state)
                guard !removedSectionIDs.isEmpty else { return .none }
                return clearDeletedSectionAssignments(removedSectionIDs)

            case let .searchTextChanged(searchText):
                guard state.searchText != searchText else { return .none }
                state.searchText = searchText
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

            case let .moveTask(taskID, destinationSectionID):
                return moveTask(taskID, to: destinationSectionID)
            }
        }
    }

    private func rebuildPresentation(_ state: inout State) {
        state.presentation = BacklogTaskListPresentation.make(
            tasks: state.tasks,
            customSections: state.customSections,
            flagRules: state.flagRules,
            searchText: state.searchText,
            referenceDate: now,
            calendar: calendar
        )
    }

    private func loadTasks() -> Effect<Action> {
        .run { @MainActor send in
            do {
                let tasks = try modelContext().fetch(FetchDescriptor<RoutineTask>())
                send(
                    .tasksLoaded(
                        tasks,
                        appSettingsClient.customTaskSections(),
                        appSettingsClient.flagRules()
                    )
                )
            } catch {
                send(.loadFailed("Couldn’t load the backlog. \(error.localizedDescription)"))
            }
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }

    private func moveTask(_ taskID: UUID, to destinationSectionID: UUID?) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                guard let task = try context.fetch(FetchDescriptor<RoutineTask>()).first(where: {
                    $0.id == taskID
                }) else {
                    return
                }
                task.customTaskSectionID = destinationSectionID
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
                send(.refresh)
            } catch {
                send(.loadFailed("Couldn’t move the task. \(error.localizedDescription)"))
            }
        }
    }

    private func clearDeletedSectionAssignments(_ sectionIDs: Set<UUID>) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext())
                let manualOrderKeys = Set(sectionIDs.map(HomeCustomTaskSectionStorage.manualOrderSectionKey(for:)))
                for task in try context.fetch(FetchDescriptor<RoutineTask>()) {
                    if task.customTaskSectionID.map(sectionIDs.contains) == true {
                        task.customTaskSectionID = nil
                    }
                    var manualOrders = task.manualSectionOrders
                    for key in manualOrderKeys {
                        manualOrders.removeValue(forKey: key)
                    }
                    task.manualSectionOrders = manualOrders
                }
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
                send(.refresh)
            } catch {
                send(.loadFailed("Couldn’t update tasks after deleting the section. \(error.localizedDescription)"))
            }
        }
    }
}
