import ComposableArchitecture
import Foundation
import SwiftData

enum GuidedTaskMetadataField: String, Equatable, Sendable {
    case importance
    case urgency

    var navigationTitle: String {
        switch self {
        case .importance:
            return "Review Importance"
        case .urgency:
            return "Review Urgency"
        }
    }

    var question: String {
        switch self {
        case .importance:
            return "How important is this task?"
        case .urgency:
            return "How urgent is this task?"
        }
    }

    var instruction: String {
        switch self {
        case .importance:
            return "Choose one value to save it and continue."
        case .urgency:
            return "Choose one value to save it and continue."
        }
    }

    var completionMessage: String {
        switch self {
        case .importance:
            return "Every eligible task has an explicit importance value."
        case .urgency:
            return "Every eligible task has an explicit urgency value."
        }
    }

    var saveFailureMessage: String {
        switch self {
        case .importance:
            return "Couldn’t save importance. Try again."
        case .urgency:
            return "Couldn’t save urgency. Try again."
        }
    }

    var activityDetails: String {
        switch self {
        case .importance:
            return "Reviewed importance"
        case .urgency:
            return "Reviewed urgency"
        }
    }

    var defaultValue: GuidedTaskMetadataValue {
        switch self {
        case .importance:
            return .importance(.level2)
        case .urgency:
            return .urgency(.level2)
        }
    }

    var values: [GuidedTaskMetadataValue] {
        switch self {
        case .importance:
            return RoutineTaskImportance.allCases.map(GuidedTaskMetadataValue.importance)
        case .urgency:
            return RoutineTaskUrgency.allCases.map(GuidedTaskMetadataValue.urgency)
        }
    }

    func isExplicit(for task: RoutineTask) -> Bool {
        switch self {
        case .importance:
            return TaskDetailOptionalControlVisibility.showsImportance(for: task)
        case .urgency:
            return TaskDetailOptionalControlVisibility.showsUrgency(for: task)
        }
    }

    func apply(_ value: GuidedTaskMetadataValue, to task: RoutineTask) -> Bool {
        switch (self, value) {
        case let (.importance, .importance(importance)):
            task.importance = importance
            task.hasExplicitImportance = true
            task.priority = task.derivedPriorityFromMatrix
            return true
        case let (.urgency, .urgency(urgency)):
            task.urgency = urgency
            task.hasExplicitUrgency = true
            task.priority = task.derivedPriorityFromMatrix
            return true
        default:
            return false
        }
    }
}

enum GuidedTaskMetadataValue: Hashable, Sendable {
    case importance(RoutineTaskImportance)
    case urgency(RoutineTaskUrgency)

    var field: GuidedTaskMetadataField {
        switch self {
        case .importance:
            return .importance
        case .urgency:
            return .urgency
        }
    }

    var title: String {
        switch self {
        case let .importance(importance):
            return importance.title
        case let .urgency(urgency):
            return urgency.title
        }
    }
}

@Reducer
struct MissingTaskMetadataFeature {
    @ObservableState
    struct State: Equatable {
        typealias Task = MissingTaskDataFeature.State.Task

        let field: GuidedTaskMetadataField
        /// Ordered ids keep Skip deterministic without retaining presentation data for every card.
        var taskIDs: [UUID] = []
        var currentTask: Task?
        var totalTaskCount = 0
        var completedTaskCount = 0
        var currentTaskIndex = 0
        var hasLoadedTasks = false
        var isLoading = false
        var isSaving = false
        var errorMessage: String?

        init(field: GuidedTaskMetadataField) {
            self.field = field
        }

        var currentTaskNumber: Int {
            guard currentTask != nil else { return 0 }
            return currentTaskIndex + 1
        }

        var progressValue: Double {
            guard totalTaskCount > 0 else { return 0 }
            return Double(completedTaskCount) / Double(totalTaskCount)
        }
    }

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case tasksLoaded(taskIDs: [UUID], currentTask: State.Task?)
        case tasksLoadFailed
        case currentTaskLoaded(taskID: UUID, task: State.Task?)
        case currentTaskUnavailable(UUID)
        case currentTaskLoadFailed
        case valueSelected(taskID: UUID, value: GuidedTaskMetadataValue)
        case valueSaved(taskID: UUID)
        case valueSaveFailed
        case skipTask(taskID: UUID)
        case taskDetailsTapped(taskID: UUID)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case taskDetailsRequested(UUID)
        }
    }

    let field: GuidedTaskMetadataField

    @Dependency(\.modelContext) private var modelContext
    @Dependency(\.appSettingsClient) private var appSettingsClient
    @Dependency(\.date.now) private var now
    @Dependency(\.calendar) private var calendar

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.hasLoadedTasks = false
                state.isLoading = true
                state.isSaving = false
                state.errorMessage = nil
                return loadTasks()

            case let .tasksLoaded(taskIDs, currentTask):
                state.taskIDs = taskIDs
                state.currentTask = currentTask
                state.totalTaskCount = taskIDs.count
                state.completedTaskCount = 0
                state.currentTaskIndex = 0
                state.hasLoadedTasks = true
                state.isLoading = false
                state.isSaving = false
                state.errorMessage = nil
                return .none

            case .tasksLoadFailed:
                state.hasLoadedTasks = false
                state.isLoading = false
                state.errorMessage = "Couldn’t load tasks. Try again."
                return .none

            case let .currentTaskLoaded(taskID, task):
                guard state.taskIDs.first == taskID else { return .none }
                state.currentTask = task
                state.isSaving = false
                state.errorMessage = nil
                return .none

            case let .currentTaskUnavailable(taskID):
                guard state.taskIDs.first == taskID else { return .none }
                state.taskIDs.removeFirst()
                state.currentTask = nil
                state.completedTaskCount += 1
                if state.taskIDs.isEmpty {
                    state.currentTaskIndex = 0
                    state.isSaving = false
                    return .none
                }
                state.currentTaskIndex = (state.currentTaskIndex + 1) % state.totalTaskCount
                return loadCurrentTask(taskID: state.taskIDs[0])

            case .currentTaskLoadFailed:
                state.isSaving = false
                state.errorMessage = "Couldn’t load the next task. Try again."
                return .none

            case let .valueSelected(taskID, value):
                guard value.field == field,
                      !state.isSaving,
                      state.currentTask?.id == taskID
                else {
                    return .none
                }
                state.isSaving = true
                state.errorMessage = nil
                return save(value, for: taskID)

            case let .valueSaved(taskID):
                guard state.taskIDs.first == taskID else {
                    state.isSaving = false
                    return .none
                }
                state.taskIDs.removeFirst()
                state.currentTask = nil
                state.completedTaskCount += 1
                if state.taskIDs.isEmpty {
                    state.currentTaskIndex = 0
                    state.isSaving = false
                } else {
                    state.currentTaskIndex = (state.currentTaskIndex + 1) % state.totalTaskCount
                    return loadCurrentTask(taskID: state.taskIDs[0])
                }
                return .none

            case .valueSaveFailed:
                state.isSaving = false
                state.errorMessage = field.saveFailureMessage
                return .none

            case let .skipTask(taskID):
                guard !state.isSaving,
                      state.taskIDs.count > 1,
                      state.currentTask?.id == taskID
                else {
                    return .none
                }
                let skippedTaskID = state.taskIDs.removeFirst()
                state.taskIDs.append(skippedTaskID)
                state.currentTaskIndex = (state.currentTaskIndex + 1) % state.totalTaskCount
                state.errorMessage = nil
                state.isSaving = true
                return loadCurrentTask(taskID: state.taskIDs[0])

            case let .taskDetailsTapped(taskID):
                guard !state.isSaving, state.currentTask?.id == taskID else { return .none }
                return .send(.delegate(.taskDetailsRequested(taskID)))

            case .delegate:
                return .none
            }
        }
    }

    private func loadTasks() -> Effect<Action> {
        .run { @MainActor send in
            do {
                let tasks = try modelContext().fetch(taskDescriptor())
                let taskIDs = tasks.map(\.id)
                let currentTask = tasks.first.map {
                    makePresentationTask(for: $0)
                }
                send(.tasksLoaded(taskIDs: taskIDs, currentTask: currentTask))
            } catch {
                send(.tasksLoadFailed)
            }
        }
    }

    private func loadCurrentTask(taskID: UUID) -> Effect<Action> {
        .run { @MainActor send in
            do {
                var descriptor = TaskDetailFetchDescriptors.task(for: taskID)
                descriptor.fetchLimit = 1
                guard let task = try modelContext().fetch(descriptor).first else {
                    send(.currentTaskUnavailable(taskID))
                    return
                }
                guard isEligible(task) else {
                    send(.currentTaskUnavailable(taskID))
                    return
                }
                send(.currentTaskLoaded(taskID: taskID, task: makePresentationTask(for: task)))
            } catch {
                send(.currentTaskLoadFailed)
            }
        }
    }

    private func makePresentationTask(for task: RoutineTask) -> State.Task {
        State.Task(
            task: task,
            customTaskSections: appSettingsClient.customTaskSections(),
            referenceDate: now,
            calendar: calendar
        )
    }

    private func taskDescriptor() -> FetchDescriptor<RoutineTask> {
        let oneOffScheduleModeRawValue = RoutineScheduleMode.oneOff.rawValue
        let mediumImportanceRawValue = RoutineTaskImportance.level2.rawValue
        let mediumUrgencyRawValue = RoutineTaskUrgency.level2.rawValue
        let noPriorityRawValue = RoutineTaskPriority.none.rawValue
        let mediumPriorityRawValue = RoutineTaskPriority.medium.rawValue

        switch field {
        case .importance:
            return FetchDescriptor<RoutineTask>(
                predicate: #Predicate { task in
                    task.importanceRawValue == mediumImportanceRawValue
                        && !task.hasExplicitImportance
                        && (
                            task.hasExplicitUrgency
                                || (
                                    !task.showsTaskDetailPriority
                                        && (task.priorityRawValue == noPriorityRawValue
                                            || task.priorityRawValue == mediumPriorityRawValue)
                                )
                        )
                        && (
                            task.scheduleModeRawValue != oneOffScheduleModeRawValue
                                || (task.lastDone == nil && task.canceledAt == nil)
                        )
                },
                sortBy: [SortDescriptor(\RoutineTask.name)]
            )
        case .urgency:
            return FetchDescriptor<RoutineTask>(
                predicate: #Predicate { task in
                    task.urgencyRawValue == mediumUrgencyRawValue
                        && !task.hasExplicitUrgency
                        && (
                            task.hasExplicitImportance
                                || (
                                    !task.showsTaskDetailPriority
                                        && (task.priorityRawValue == noPriorityRawValue
                                            || task.priorityRawValue == mediumPriorityRawValue)
                                )
                        )
                        && (
                            task.scheduleModeRawValue != oneOffScheduleModeRawValue
                                || (task.lastDone == nil && task.canceledAt == nil)
                        )
                },
                sortBy: [SortDescriptor(\RoutineTask.name)]
            )
        }
    }

    private func save(_ value: GuidedTaskMetadataValue, for taskID: UUID) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first,
                      isEligible(task),
                      field.apply(value, to: task)
                else {
                    send(.valueSaved(taskID: taskID))
                    return
                }

                DeviceActivityRecorder.recordAction(
                    .updated,
                    entity: .task,
                    entityID: taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    details: field.activityDetails,
                    in: context
                )
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
                send(.valueSaved(taskID: taskID))
            } catch {
                send(.valueSaveFailed)
            }
        }
    }

    private func isEligible(_ task: RoutineTask) -> Bool {
        !field.isExplicit(for: task)
            && (!task.isOneOffTask || (task.lastDone == nil && task.canceledAt == nil))
    }
}
