import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct MissingPressureDataFeature {
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
        case pressureSelected(taskID: UUID, pressure: RoutineTaskPressure)
        case pressureSaved(taskID: UUID)
        case pressureSaveFailed
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

            case let .pressureSelected(taskID, pressure):
                guard pressure != .none,
                      !state.isSaving,
                      state.currentTask?.id == taskID else {
                    return .none
                }
                state.isSaving = true
                state.errorMessage = nil
                return savePressure(pressure, for: taskID)

            case let .pressureSaved(taskID):
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

            case .pressureSaveFailed:
                state.isSaving = false
                state.errorMessage = "Couldn’t save pressure. Try again."
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
                let pressureRawValue = RoutineTaskPressure.none.rawValue
                let oneOffScheduleModeRawValue = RoutineScheduleMode.oneOff.rawValue
                let descriptor = FetchDescriptor<RoutineTask>(
                    predicate: #Predicate { task in
                        task.pressureRawValue == pressureRawValue
                            && (
                                task.scheduleModeRawValue != oneOffScheduleModeRawValue
                                    || (task.lastDone == nil && task.canceledAt == nil)
                            )
                    },
                    sortBy: [SortDescriptor(\RoutineTask.name)]
                )
                let tasks = try modelContext().fetch(descriptor)
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

    private func savePressure(
        _ pressure: RoutineTaskPressure,
        for taskID: UUID
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                guard let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first,
                      isEligible(task)
                else {
                    send(.pressureSaved(taskID: taskID))
                    return
                }

                task.pressure = pressure
                DeviceActivityRecorder.recordAction(
                    .updated,
                    entity: .task,
                    entityID: taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    details: "Updated pressure",
                    in: context
                )
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
                send(.pressureSaved(taskID: taskID))
            } catch {
                send(.pressureSaveFailed)
            }
        }
    }

    private func isEligible(_ task: RoutineTask) -> Bool {
        task.pressure == .none
            && (!task.isOneOffTask || (task.lastDone == nil && task.canceledAt == nil))
    }
}
