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

        var tasks: [Task] = []
        var totalTaskCount = 0
        var completedTaskCount = 0
        var currentTaskIndex = 0
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
    }

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case tasksLoaded([State.Task])
        case tasksLoadFailed
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

            case .pressureSaveFailed:
                state.isSaving = false
                state.errorMessage = "Couldn’t save pressure. Try again."
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
                let customTaskSections = appSettingsClient.customTaskSections()
                let referenceDate = now
                let tasks = try modelContext().fetch(descriptor).map { task in
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
