import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct MissingPriorityDataFeature {
    @ObservableState
    struct State: Equatable {
        typealias Task = MissingPressureDataFeature.State.Task

        var tasks: [Task] = []
        var totalTaskCount = 0
        var completedTaskCount = 0
        var currentTaskIndex = 0
        var selectedImportance: RoutineTaskImportance = .level2
        var selectedUrgency: RoutineTaskUrgency = .level2
        var hasLoadedTasks = false
        var isLoading = false
        var isSaving = false
        var errorMessage: String?

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

        mutating func resetSelections() {
            selectedImportance = .level2
            selectedUrgency = .level2
        }
    }

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case tasksLoaded([State.Task])
        case tasksLoadFailed
        case importanceSelected(RoutineTaskImportance)
        case urgencySelected(RoutineTaskUrgency)
        case saveSelected(taskID: UUID)
        case valuesSaved(taskID: UUID)
        case valuesSaveFailed
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
                state.resetSelections()
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

            case let .importanceSelected(importance):
                guard !state.isSaving, state.currentTask != nil else { return .none }
                state.selectedImportance = importance
                return .none

            case let .urgencySelected(urgency):
                guard !state.isSaving, state.currentTask != nil else { return .none }
                state.selectedUrgency = urgency
                return .none

            case let .saveSelected(taskID):
                guard !state.isSaving, state.currentTask?.id == taskID else { return .none }
                state.isSaving = true
                state.errorMessage = nil
                return savePriority(
                    importance: state.selectedImportance,
                    urgency: state.selectedUrgency,
                    for: taskID
                )

            case let .valuesSaved(taskID):
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
                state.resetSelections()
                state.isSaving = false
                return .none

            case .valuesSaveFailed:
                state.isSaving = false
                state.errorMessage = "Couldn’t save priority. Try again."
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
                state.resetSelections()
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

    private func savePriority(
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        for taskID: UUID
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first,
                      isEligible(task)
                else {
                    send(.valuesSaved(taskID: taskID))
                    return
                }

                task.importance = importance
                task.urgency = urgency
                task.priority = task.derivedPriorityFromMatrix
                task.showsTaskDetailPriority = true
                DeviceActivityRecorder.recordAction(
                    .updated,
                    entity: .task,
                    entityID: taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    details: "Reviewed importance and urgency",
                    in: context
                )
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
                send(.valuesSaved(taskID: taskID))
            } catch {
                send(.valuesSaveFailed)
            }
        }
    }

    private func isEligible(_ task: RoutineTask) -> Bool {
        !TaskDetailOptionalControlVisibility.showsPriority(for: task)
            && (!task.isOneOffTask || (task.lastDone == nil && task.canceledAt == nil))
    }
}
