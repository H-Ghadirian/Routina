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
        typealias Task = MissingPressureDataFeature.State.Task

        let field: GuidedTaskMetadataField
        var tasks: [Task] = []
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

        var currentTask: Task? {
            tasks.first
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
        case tasksLoaded([State.Task])
        case tasksLoadFailed
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

            case let .tasksLoaded(tasks):
                state.tasks = tasks
                state.totalTaskCount = tasks.count
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
                guard state.tasks.contains(where: { $0.id == taskID }) else {
                    state.isSaving = false
                    return .none
                }
                state.tasks.removeAll { $0.id == taskID }
                state.completedTaskCount += 1
                if state.tasks.isEmpty {
                    state.currentTaskIndex = 0
                } else {
                    state.currentTaskIndex = (state.currentTaskIndex + 1) % state.totalTaskCount
                }
                state.isSaving = false
                return .none

            case .valueSaveFailed:
                state.isSaving = false
                state.errorMessage = field.saveFailureMessage
                return .none

            case let .skipTask(taskID):
                guard !state.isSaving,
                      state.tasks.count > 1,
                      state.currentTask?.id == taskID
                else {
                    return .none
                }
                let skippedTask = state.tasks.removeFirst()
                state.tasks.append(skippedTask)
                state.currentTaskIndex = (state.currentTaskIndex + 1) % state.totalTaskCount
                state.errorMessage = nil
                return .none

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
                let oneOffScheduleModeRawValue = RoutineScheduleMode.oneOff.rawValue
                let descriptor = FetchDescriptor<RoutineTask>(
                    predicate: #Predicate { task in
                        task.scheduleModeRawValue != oneOffScheduleModeRawValue
                            || (task.lastDone == nil && task.canceledAt == nil)
                    },
                    sortBy: [SortDescriptor(\RoutineTask.name)]
                )
                let customTaskSections = appSettingsClient.customTaskSections()
                let referenceDate = now
                let tasks = try modelContext().fetch(descriptor)
                    .filter(isEligible)
                    .map { task in
                        State.Task(
                            task: task,
                            customTaskSections: customTaskSections,
                            referenceDate: referenceDate,
                            calendar: calendar
                        )
                    }
                send(.tasksLoaded(tasks))
            } catch {
                send(.tasksLoadFailed)
            }
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
