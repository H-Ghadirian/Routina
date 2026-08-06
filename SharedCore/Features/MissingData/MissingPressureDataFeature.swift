import ComposableArchitecture
import Foundation
import SwiftData

enum GuidedMissingTaskDataField: Equatable, Sendable {
    case pressure
    case thinkingNeeded
    case estimatedDuration

    var navigationTitle: String {
        switch self {
        case .pressure:
            return "Add missing Pressure"
        case .thinkingNeeded:
            return "Add missing Thinking needed"
        case .estimatedDuration:
            return "Add missing time estimates"
        }
    }

    var question: String {
        switch self {
        case .pressure:
            return "How much pressure does this task create?"
        case .thinkingNeeded:
            return "How much thinking does this task need?"
        case .estimatedDuration:
            return "How long will this task take?"
        }
    }

    var instruction: String {
        switch self {
        case .pressure:
            return "Pressure is how much a task stays on your mind, even when it is not the most urgent."
        case .thinkingNeeded:
            return "Thinking needed is the concentration, understanding, or decision-making this task requires."
        case .estimatedDuration:
            return "Choose the closest estimate. You can fine-tune it in task details."
        }
    }

    var completionMessage: String {
        switch self {
        case .pressure:
            return "Every eligible task has pressure data."
        case .thinkingNeeded:
            return "Every eligible task has thinking needed data."
        case .estimatedDuration:
            return "Every eligible task has a time estimate."
        }
    }

    var saveFailureMessage: String {
        switch self {
        case .pressure:
            return "Couldn’t save pressure. Try again."
        case .thinkingNeeded:
            return "Couldn’t save thinking needed. Try again."
        case .estimatedDuration:
            return "Couldn’t save the time estimate. Try again."
        }
    }

    var activityDetails: String {
        switch self {
        case .pressure:
            return "Updated pressure"
        case .thinkingNeeded:
            return "Updated thinking needed"
        case .estimatedDuration:
            return "Updated time estimate"
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
        case .estimatedDuration:
            return [15, 30, 60, 120, 240, 480, 1_200]
                .map(GuidedMissingTaskDataValue.estimatedDuration)
        }
    }

    var missingValue: GuidedMissingTaskDataValue {
        switch self {
        case .pressure:
            return .pressure(.none)
        case .thinkingNeeded:
            return .thinkingNeeded(.none)
        case .estimatedDuration:
            return .estimatedDuration(0)
        }
    }

    var maximumSegmentsPerRow: Int? {
        switch self {
        case .estimatedDuration:
            return 4
        case .pressure, .thinkingNeeded:
            return nil
        }
    }

    func isEligible(_ task: RoutineTask) -> Bool {
        let hasMissingValue: Bool
        switch self {
        case .pressure:
            hasMissingValue = task.pressure == .none
        case .thinkingNeeded:
            hasMissingValue = task.thinkingNeeded == .none
        case .estimatedDuration:
            hasMissingValue = task.estimatedDurationMinutes == nil
        }

        return task.pausedAt == nil
            && hasMissingValue
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
        case let (.estimatedDuration, .estimatedDuration(minutes)):
            guard let sanitizedMinutes = RoutineTask.sanitizedEstimatedDurationMinutes(minutes) else {
                return false
            }
            task.estimatedDurationMinutes = sanitizedMinutes
            return true
        default:
            return false
        }
    }
}

enum GuidedMissingTaskDataValue: Hashable, Sendable {
    case pressure(RoutineTaskPressure)
    case thinkingNeeded(RoutineTaskThinkingNeeded)
    case estimatedDuration(Int)

    var field: GuidedMissingTaskDataField {
        switch self {
        case .pressure:
            return .pressure
        case .thinkingNeeded:
            return .thinkingNeeded
        case .estimatedDuration:
            return .estimatedDuration
        }
    }

    var title: String {
        switch self {
        case let .pressure(pressure):
            return pressure.title
        case let .thinkingNeeded(thinkingNeeded):
            return thinkingNeeded.title
        case let .estimatedDuration(minutes):
            return estimatedDurationTitle(for: minutes)
        }
    }

    var isMissing: Bool {
        switch self {
        case let .pressure(pressure):
            return pressure == .none
        case let .thinkingNeeded(thinkingNeeded):
            return thinkingNeeded == .none
        case let .estimatedDuration(minutes):
            return minutes <= 0
        }
    }

    private func estimatedDurationTitle(for minutes: Int) -> String {
        switch minutes {
        case 15: return "15m"
        case 30: return "30m"
        case 60: return "1h"
        case 120: return "2h"
        case 240: return "4h"
        case 480: return "8h"
        case 1_200: return "20h"
        default: return "\(minutes)m"
        }
    }
}

@Reducer
struct MissingTaskDataFeature {
    @ObservableState
    struct State: Equatable {
        enum TimeEstimateSelection: Equatable {
            case preset(Int)
            case custom(hours: String, minutes: String)

            var minutes: Int? {
                switch self {
                case let .preset(minutes):
                    return (5...10_080).contains(minutes) ? minutes : nil
                case let .custom(hours, minutes):
                    guard !hours.isEmpty || !minutes.isEmpty,
                          let hours = Int(hours.isEmpty ? "0" : hours), hours >= 0,
                          let minutes = Int(minutes.isEmpty ? "0" : minutes), (0...59).contains(minutes)
                    else {
                        return nil
                    }
                    let totalMinutes = (hours * 60) + minutes
                    return (5...10_080).contains(totalMinutes) ? totalMinutes : nil
                }
            }

            var customHours: String {
                guard case let .custom(hours, _) = self else { return "" }
                return hours
            }

            var customMinutes: String {
                guard case let .custom(_, minutes) = self else { return "" }
                return minutes
            }
        }

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
        /// A duration draft is intentionally separate from persisted task data until Save & next is tapped.
        var timeEstimateSelection: TimeEstimateSelection?

        var currentTaskNumber: Int {
            guard currentTask != nil else { return 0 }
            return currentTaskIndex + 1
        }

        var progressValue: Double {
            guard totalTaskCount > 0 else { return 0 }
            return Double(completedTaskCount) / Double(totalTaskCount)
        }

        var selectedTimeEstimateMinutes: Int? {
            timeEstimateSelection?.minutes
        }

        var selectedTimeEstimateTitle: String? {
            selectedTimeEstimateMinutes.map(Self.estimatedDurationTitle)
        }

        var selectedTimeEstimateValue: GuidedMissingTaskDataValue {
            guard let selectedTimeEstimateMinutes else {
                return .estimatedDuration(0)
            }
            return .estimatedDuration(selectedTimeEstimateMinutes)
        }

        var customTimeEstimateHours: String {
            timeEstimateSelection?.customHours ?? ""
        }

        var customTimeEstimateMinutes: String {
            timeEstimateSelection?.customMinutes ?? ""
        }

        var timeEstimateValidationMessage: String? {
            guard case let .custom(hours, minutes) = timeEstimateSelection,
                  !hours.isEmpty || !minutes.isEmpty,
                  selectedTimeEstimateMinutes == nil
            else {
                return nil
            }
            return "Enter 5 minutes to 7 days. Minutes must be 0–59."
        }

        private static func estimatedDurationTitle(for minutes: Int) -> String {
            let hours = minutes / 60
            let remainder = minutes % 60
            switch (hours, remainder) {
            case (0, let remainder):
                return "\(remainder) min"
            case (let hours, 0):
                return hours == 1 ? "1 hour" : "\(hours) hours"
            default:
                return "\(hours)h \(remainder)m"
            }
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
        case customTimeEstimateChanged(hours: String, minutes: String)
        case saveSelectedTimeEstimate(taskID: UUID)
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
                state.timeEstimateSelection = nil
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
                state.timeEstimateSelection = nil
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
                state.timeEstimateSelection = nil
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

                if field == .estimatedDuration {
                    guard case let .estimatedDuration(minutes) = value else { return .none }
                    state.timeEstimateSelection = .preset(minutes)
                    state.errorMessage = nil
                    return .none
                }

                state.isSaving = true
                state.errorMessage = nil
                return save(value, for: taskID)

            case let .customTimeEstimateChanged(hours, minutes):
                guard field == .estimatedDuration,
                      !state.isSaving,
                      state.currentTask != nil else {
                    return .none
                }
                state.timeEstimateSelection = .custom(
                    hours: Self.sanitizedTimeEstimateText(hours, maximumLength: 3),
                    minutes: Self.sanitizedTimeEstimateText(minutes, maximumLength: 2)
                )
                state.errorMessage = nil
                return .none

            case let .saveSelectedTimeEstimate(taskID):
                guard field == .estimatedDuration,
                      !state.isSaving,
                      state.currentTask?.id == taskID,
                      let minutes = state.selectedTimeEstimateMinutes
                else {
                    return .none
                }
                state.isSaving = true
                state.errorMessage = nil
                return save(.estimatedDuration(minutes), for: taskID)

            case let .valueSaved(taskID):
                guard state.taskIDs.first == taskID else {
                    state.isSaving = false
                    return .none
                }
                state.taskIDs.removeFirst()
                state.currentTask = nil
                state.completedTaskCount += 1
                state.timeEstimateSelection = nil
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
                state.timeEstimateSelection = nil
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
                let tasks = try modelContext().fetch(taskDescriptor()).filter(isEligible)
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
        case .estimatedDuration:
            return FetchDescriptor<RoutineTask>(
                predicate: #Predicate { task in
                    task.scheduleModeRawValue != oneOffScheduleModeRawValue
                        || (task.lastDone == nil && task.canceledAt == nil)
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

    private static func sanitizedTimeEstimateText(_ value: String, maximumLength: Int) -> String {
        String(value.filter(\.isNumber).prefix(maximumLength))
    }
}

typealias MissingPressureDataFeature = MissingTaskDataFeature
typealias MissingThinkingNeededDataFeature = MissingTaskDataFeature
typealias MissingEstimatedDurationDataFeature = MissingTaskDataFeature
