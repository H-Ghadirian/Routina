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
        var definedFlags: [String] = []
        var tagColors: [String: String] = [:]
        var fileAttachmentTaskIDs: Set<UUID> = []
        var filters = BacklogFilterState.default
        var presentation = BacklogTaskListPresentation.empty
        var searchText = ""
        var collapsedSuperSectionIDs: Set<UUID> = []
        var collapsedSubsectionIDs: Set<UUID> = []
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
        case tasksLoaded(
            [RoutineTask],
            [HomeCustomTaskSection],
            [RoutineFlagRule],
            Set<UUID>,
            [String],
            [String: String]
        )
        case loadFailed(String)
        case errorDismissed
        case customSectionsChanged([HomeCustomTaskSection])
        case customSectionsDeleted([HomeCustomTaskSection], Set<UUID>)
        case searchTextChanged(String)
        case filtersChanged(BacklogFilterState)
        case clearFilters
        case superSectionDisclosureToggled(UUID)
        case subsectionDisclosureToggled(UUID)
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
                guard !state.isLoading else { return .none }
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

            case let .tasksLoaded(
                tasks,
                customSections,
                flagRules,
                fileAttachmentTaskIDs,
                definedFlags,
                tagColors
            ):
                state.isLoading = false
                state.tasks = tasks
                state.customSections = customSections
                state.flagRules = RoutineFlagRules.sanitized(flagRules)
                state.fileAttachmentTaskIDs = fileAttachmentTaskIDs
                state.definedFlags = RoutineFlag.allFlags(from: [definedFlags])
                state.tagColors = tagColors
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

            case .errorDismissed:
                state.errorMessage = nil
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

            case let .filtersChanged(filters):
                guard state.filters != filters else { return .none }
                state.filters = filters
                rebuildPresentation(&state)
                return .none

            case .clearFilters:
                guard state.filters.hasNonDefaultOptions else { return .none }
                state.filters = .default
                rebuildPresentation(&state)
                return .none

            case let .superSectionDisclosureToggled(sectionID):
                guard HomeTaskSearchIndex.query(state.searchText) == nil else { return .none }
                state.collapsedSuperSectionIDs.toggleMembership(of: sectionID)
                return .none

            case let .subsectionDisclosureToggled(subsectionID):
                guard HomeTaskSearchIndex.query(state.searchText) == nil else { return .none }
                state.collapsedSubsectionIDs.toggleMembership(of: subsectionID)
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
            availableFlags: state.definedFlags,
            filters: state.filters,
            fileAttachmentTaskIDs: state.fileAttachmentTaskIDs,
            searchText: state.searchText,
            referenceDate: now,
            calendar: calendar
        )
    }

    private func loadTasks() -> Effect<Action> {
        .run { @MainActor send in
            do {
                let tasks = try modelContext().fetch(FetchDescriptor<RoutineTask>())
                let fileAttachmentTaskIDs = Set(
                    try modelContext().fetch(FetchDescriptor<RoutineAttachment>()).map(\.taskID)
                )
                send(
                    .tasksLoaded(
                        tasks,
                        appSettingsClient.customTaskSections(),
                        appSettingsClient.flagRules(),
                        fileAttachmentTaskIDs,
                        appSettingsClient.definedFlags(),
                        appSettingsClient.tagColors()
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

private extension Set {
    mutating func toggleMembership(of element: Element) {
        if contains(element) {
            remove(element)
        } else {
            insert(element)
        }
    }
}
