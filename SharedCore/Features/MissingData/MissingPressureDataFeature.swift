import ComposableArchitecture
import Foundation
import SwiftData

enum GuidedMissingTaskDataField: Equatable, Sendable {
    case pressure
    case thinkingNeeded

    var navigationTitle: String {
        switch self {
        case .pressure:
            return "Add missing Pressure"
        case .thinkingNeeded:
            return "Add missing Thinking needed"
        }
    }

    var question: String {
        switch self {
        case .pressure:
            return "How much pressure does this task create?"
        case .thinkingNeeded:
            return "How much thinking does this task need?"
        }
    }

    var instruction: String {
        switch self {
        case .pressure:
            return "Pressure is how much a task stays on your mind, even when it is not the most urgent."
        case .thinkingNeeded:
            return "Thinking needed is the concentration, understanding, or decision-making this task requires."
        }
    }

    var completionMessage: String {
        switch self {
        case .pressure:
            return "Every eligible task has pressure data."
        case .thinkingNeeded:
            return "Every eligible task has thinking needed data."
        }
    }

    var saveFailureMessage: String {
        switch self {
        case .pressure:
            return "Couldn’t save pressure. Try again."
        case .thinkingNeeded:
            return "Couldn’t save thinking needed. Try again."
        }
    }

    var activityDetails: String {
        switch self {
        case .pressure:
            return "Updated pressure"
        case .thinkingNeeded:
            return "Updated thinking needed"
        }
    }

    var values: [GuidedMissingTaskDataValue] {
        switch self {
        case .pressure:
            return RoutineTaskPressure.allCases
                .filter { $0 != .none }
                .map(GuidedMissingTaskDataValue.pressure)
        case .thinkingNeeded:
            return RoutineTaskThinkingNeeded.allCases
                .filter { $0 != .none }
                .map(GuidedMissingTaskDataValue.thinkingNeeded)
        }
    }

    var missingValue: GuidedMissingTaskDataValue {
        switch self {
        case .pressure:
            return .pressure(.none)
        case .thinkingNeeded:
            return .thinkingNeeded(.none)
        }
    }

    func isEligible(_ task: RoutineTask) -> Bool {
        let hasMissingValue: Bool
        switch self {
        case .pressure:
            hasMissingValue = task.pressure == .none
        case .thinkingNeeded:
            hasMissingValue = task.thinkingNeeded == .none
        }

        return hasMissingValue
            && (!task.isOneOffTask || (task.lastDone == nil && task.canceledAt == nil))
    }

    func apply(_ value: GuidedMissingTaskDataValue, to task: RoutineTask) -> Bool {
        switch (self, value) {
        case let (.pressure, .pressure(pressure)) where pressure != .none:
            task.pressure = pressure
            return true
        case let (.thinkingNeeded, .thinkingNeeded(thinkingNeeded)) where thinkingNeeded != .none:
            task.thinkingNeeded = thinkingNeeded
            return true
        default:
            return false
        }
    }
}

enum GuidedMissingTaskDataValue: Hashable, Sendable {
    case pressure(RoutineTaskPressure)
    case thinkingNeeded(RoutineTaskThinkingNeeded)

    var field: GuidedMissingTaskDataField {
        switch self {
        case .pressure:
            return .pressure
        case .thinkingNeeded:
            return .thinkingNeeded
        }
    }

    var title: String {
        switch self {
        case let .pressure(pressure):
            return pressure.title
        case let .thinkingNeeded(thinkingNeeded):
            return thinkingNeeded.title
        }
    }

    var isMissing: Bool {
        switch self {
        case let .pressure(pressure):
            return pressure == .none
        case let .thinkingNeeded(thinkingNeeded):
            return thinkingNeeded == .none
        }
    }
}

@Reducer
struct MissingTaskDataFeature {
    @ObservableState
    struct State: Equatable {
        struct Task: Identifiable, Equatable {
            let id: UUID
            let title: String
            let tags: [String]
            let additionalTagCount: Int
            let path: [String]
            let labels: [MissingPressureDataTaskPresentation.Label]

            init(
                task: RoutineTask,
                customTaskSections: [HomeCustomTaskSection] = [],
                referenceDate: Date = Date(),
                calendar: Calendar = .current
            ) {
                id = task.id
                title = RoutineTask.trimmedName(task.name) ?? "Untitled task"
                let context = MissingPressureDataTaskPresentation.context(
                    for: task,
                    customTaskSections: customTaskSections,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
                tags = context.tags
                additionalTagCount = context.additionalTagCount
                path = context.path
                labels = context.labels
            }
        }

        var field: GuidedMissingTaskDataField = .pressure
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
        case valueSelected(taskID: UUID, value: GuidedMissingTaskDataValue)
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

    @Dependency(\.modelContext) private var modelContext
    @Dependency(\.appSettingsClient) private var appSettingsClient
    @Dependency(\.date.now) private var now
    @Dependency(\.calendar) private var calendar

    let field: GuidedMissingTaskDataField

    init(field: GuidedMissingTaskDataField = .pressure) {
        self.field = field
    }

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
                      !value.isMissing,
                      !state.isSaving,
                      state.currentTask?.id == taskID else {
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
                guard !state.isSaving, state.currentTask?.id == taskID else {
                    return .none
                }
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

        switch field {
        case .pressure:
            let missingRawValue = RoutineTaskPressure.none.rawValue
            return FetchDescriptor<RoutineTask>(
                predicate: #Predicate { task in
                    task.pressureRawValue == missingRawValue
                        && (
                            task.scheduleModeRawValue != oneOffScheduleModeRawValue
                                || (task.lastDone == nil && task.canceledAt == nil)
                        )
                },
                sortBy: [SortDescriptor(\RoutineTask.name)]
            )
        case .thinkingNeeded:
            let missingRawValue = RoutineTaskThinkingNeeded.none.rawValue
            return FetchDescriptor<RoutineTask>(
                predicate: #Predicate { task in
                    task.thinkingNeededRawValue == missingRawValue
                        && (
                            task.scheduleModeRawValue != oneOffScheduleModeRawValue
                                || (task.lastDone == nil && task.canceledAt == nil)
                        )
                },
                sortBy: [SortDescriptor(\RoutineTask.name)]
            )
        }
    }

    private func save(
        _ value: GuidedMissingTaskDataValue,
        for taskID: UUID
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first,
                      field.isEligible(task),
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
        field.isEligible(task)
    }
}

typealias MissingPressureDataFeature = MissingTaskDataFeature
typealias MissingThinkingNeededDataFeature = MissingTaskDataFeature
