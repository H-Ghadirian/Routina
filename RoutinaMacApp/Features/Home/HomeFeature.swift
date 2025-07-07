import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct HomeFeature {
    enum MoveDirection: String, Equatable {
        case up
        case down
    }

    enum TaskListMode: String, CaseIterable, Equatable, Identifiable {
        case all = "All"
        case routines = "Routines"
        case todos = "Todos"

        var id: Self { self }

        var systemImage: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .routines: return "repeat"
            case .todos: return "checklist"
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .all: return "Show all tasks"
            case .routines: return "Show routines"
            case .todos: return "Show todos"
            }
        }
    }

    typealias SelectedTaskReloadGuard = HomeSelectedTaskReloadGuard

    typealias DoneStats = HomeDoneStats

    struct RoutineDisplay: Equatable, Identifiable {
        let taskID: UUID
        var id: UUID { taskID }
        var name: String
        var emoji: String
        var notes: String?
        var hasImage: Bool
        var placeID: UUID?
        var placeName: String?
        var locationAvailability: RoutineLocationAvailability
        var tags: [String]
        var steps: [String]
        var interval: Int
        var recurrenceRule: RoutineRecurrenceRule
        var scheduleMode: RoutineScheduleMode
        var lastDone: Date?
        var canceledAt: Date?
        var dueDate: Date?
        var priority: RoutineTaskPriority
        var importance: RoutineTaskImportance
        var urgency: RoutineTaskUrgency
        var scheduleAnchor: Date?
        var pausedAt: Date?
        var snoozedUntil: Date?
        var pinnedAt: Date?
        var daysUntilDue: Int
        var isOneOffTask: Bool
        var isCompletedOneOff: Bool
        var isCanceledOneOff: Bool
        var isDoneToday: Bool
        var isAssumedDoneToday: Bool = false
        var isPaused: Bool
        var isSnoozed: Bool
        var isPinned: Bool
        var completedStepCount: Int
        var isInProgress: Bool
        var nextStepTitle: String?
        var checklistItemCount: Int
        var completedChecklistItemCount: Int
        var dueChecklistItemCount: Int
        var nextPendingChecklistItemTitle: String?
        var nextDueChecklistItemTitle: String?
        var doneCount: Int
        var manualSectionOrders: [String: Int] = [:]
        var color: RoutineTaskColor = .none
        var todoState: TodoState? = nil
        var assignedSprintID: UUID? = nil
        var assignedSprintTitle: String? = nil
    }

    enum MacSidebarSelection: Hashable, Equatable {
        case task(UUID)
        case timelineEntry(UUID)
    }

    enum MacSidebarMode: String, CaseIterable, Identifiable, Equatable {
        case routines = "Routines"
        case board = "Board"
        case timeline = "Timeline"
        case stats    = "Stats"
        case settings = "Settings"
        case addTask  = "Add Task"

        var id: Self { self }
    }

    enum BoardScope: Equatable, Sendable {
        case backlog
        case currentSprint
        case sprint(UUID)
    }

    @ObservableState
    struct State: Equatable {
        var routineTasks: [RoutineTask] = []
        var routinePlaces: [RoutinePlace] = []
        var timelineLogs: [RoutineLog] = []
        var routineDisplays: [RoutineDisplay] = []
        var awayRoutineDisplays: [RoutineDisplay] = []
        var archivedRoutineDisplays: [RoutineDisplay] = []
        var board = HomeBoardState()
        var doneStats: DoneStats = DoneStats()
        var selection = HomeSelectionState()
        var presentation = HomePresentationState()
        var locationSnapshot = LocationSnapshot(
            authorizationStatus: .notDetermined,
            coordinate: nil,
            horizontalAccuracy: nil,
            timestamp: nil
        )
        var hideUnavailableRoutines: Bool = false
        var taskListMode: TaskListMode = .todos
        var taskFilters = HomeTaskFiltersState()
        var timelineFilters = HomeTimelineFiltersState()
        var statsFilters = HomeStatsFiltersState()
        var navigation = HomeMacNavigationState()

        init(
            routineTasks: [RoutineTask] = [],
            routinePlaces: [RoutinePlace] = [],
            timelineLogs: [RoutineLog] = [],
            routineDisplays: [RoutineDisplay] = [],
            awayRoutineDisplays: [RoutineDisplay] = [],
            archivedRoutineDisplays: [RoutineDisplay] = [],
            boardTodoDisplays: [RoutineDisplay] = [],
            sprintBoardData: SprintBoardData = SprintBoardData(),
            doneStats: DoneStats = DoneStats(),
            selectedTaskID: UUID? = nil,
            isAddRoutineSheetPresented: Bool = false,
            locationSnapshot: LocationSnapshot = LocationSnapshot(
                authorizationStatus: .notDetermined,
                coordinate: nil,
                horizontalAccuracy: nil,
                timestamp: nil
            ),
            hideUnavailableRoutines: Bool = false,
            addRoutineState: AddRoutineFeature.State? = nil,
            taskDetailState: TaskDetailFeature.State? = nil,
            selectedTaskReloadGuard: SelectedTaskReloadGuard? = nil,
            pendingSelectedChecklistReloadGuardTaskID: UUID? = nil,
            pendingDeleteTaskIDs: [UUID] = [],
            isDeleteConfirmationPresented: Bool = false,
            isMacFilterDetailPresented: Bool = false,
            taskListMode: TaskListMode = .todos,
            selectedFilter: RoutineListFilter = .all,
            selectedTag: String? = nil,
            excludedTags: Set<String> = [],
            selectedManualPlaceFilterID: UUID? = nil,
            selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
            selectedTodoStateFilter: TodoState? = nil,
            tabFilterSnapshots: [String: TabFilterStateManager.Snapshot] = [:],
            isFilterSheetPresented: Bool = false,
            selectedTimelineRange: TimelineRange = .all,
            selectedTimelineFilterType: TimelineFilterType = .all,
            selectedTimelineTag: String? = nil,
            selectedTimelineExcludedTags: Set<String> = [],
            selectedTimelineImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
            statsSelectedRange: DoneChartRange = .week,
            statsSelectedTag: String? = nil,
            macSidebarMode: MacSidebarMode = .routines,
            macSidebarSelection: MacSidebarSelection? = nil,
            selectedSettingsSection: SettingsMacSection? = .notifications,
            selectedBoardScope: BoardScope = .backlog
        ) {
            self.routineTasks = routineTasks
            self.routinePlaces = routinePlaces
            self.timelineLogs = timelineLogs
            self.routineDisplays = routineDisplays
            self.awayRoutineDisplays = awayRoutineDisplays
            self.archivedRoutineDisplays = archivedRoutineDisplays
            self.board = HomeBoardState(
                todoDisplays: boardTodoDisplays,
                sprintBoardData: sprintBoardData,
                selectedScope: selectedBoardScope
            )
            self.doneStats = doneStats
            self.selection = HomeSelectionState(
                selectedTaskID: selectedTaskID,
                taskDetailState: taskDetailState,
                selectedTaskReloadGuard: selectedTaskReloadGuard,
                pendingSelectedChecklistReloadGuardTaskID: pendingSelectedChecklistReloadGuardTaskID
            )
            self.presentation = HomePresentationState(
                isAddRoutineSheetPresented: isAddRoutineSheetPresented,
                addRoutineState: addRoutineState,
                pendingDeleteTaskIDs: pendingDeleteTaskIDs,
                isDeleteConfirmationPresented: isDeleteConfirmationPresented,
                isMacFilterDetailPresented: isMacFilterDetailPresented
            )
            self.locationSnapshot = locationSnapshot
            self.hideUnavailableRoutines = hideUnavailableRoutines
            self.taskListMode = taskListMode
            self.taskFilters = HomeTaskFiltersState(
                selectedFilter: selectedFilter,
                selectedTag: selectedTag,
                excludedTags: excludedTags,
                selectedManualPlaceFilterID: selectedManualPlaceFilterID,
                selectedImportanceUrgencyFilter: selectedImportanceUrgencyFilter,
                selectedTodoStateFilter: selectedTodoStateFilter,
                tabFilterSnapshots: tabFilterSnapshots,
                isFilterSheetPresented: isFilterSheetPresented
            )
            self.timelineFilters = HomeTimelineFiltersState(
                selectedRange: selectedTimelineRange,
                selectedFilterType: selectedTimelineFilterType,
                selectedTag: selectedTimelineTag,
                selectedExcludedTags: selectedTimelineExcludedTags,
                selectedImportanceUrgencyFilter: selectedTimelineImportanceUrgencyFilter
            )
            self.statsFilters = HomeStatsFiltersState(
                selectedRange: statsSelectedRange,
                selectedTag: statsSelectedTag
            )
            self.navigation = HomeMacNavigationState(
                sidebarMode: macSidebarMode,
                sidebarSelection: macSidebarSelection,
                selectedSettingsSection: selectedSettingsSection
            )
        }

        var selectedTaskID: UUID? {
            get { selection.selectedTaskID }
            set { selection.selectedTaskID = newValue }
        }

        var taskDetailState: TaskDetailFeature.State? {
            get { selection.taskDetailState }
            set { selection.taskDetailState = newValue }
        }

        var selectedTaskReloadGuard: SelectedTaskReloadGuard? {
            get { selection.selectedTaskReloadGuard }
            set { selection.selectedTaskReloadGuard = newValue }
        }

        var pendingSelectedChecklistReloadGuardTaskID: UUID? {
            get { selection.pendingSelectedChecklistReloadGuardTaskID }
            set { selection.pendingSelectedChecklistReloadGuardTaskID = newValue }
        }

        var isAddRoutineSheetPresented: Bool {
            get { presentation.isAddRoutineSheetPresented }
            set { presentation.isAddRoutineSheetPresented = newValue }
        }

        var addRoutineState: AddRoutineFeature.State? {
            get { presentation.addRoutineState }
            set { presentation.addRoutineState = newValue }
        }

        var pendingDeleteTaskIDs: [UUID] {
            get { presentation.pendingDeleteTaskIDs }
            set { presentation.pendingDeleteTaskIDs = newValue }
        }

        var isDeleteConfirmationPresented: Bool {
            get { presentation.isDeleteConfirmationPresented }
            set { presentation.isDeleteConfirmationPresented = newValue }
        }

        var isMacFilterDetailPresented: Bool {
            get { presentation.isMacFilterDetailPresented }
            set { presentation.isMacFilterDetailPresented = newValue }
        }

        var boardTodoDisplays: [RoutineDisplay] {
            get { board.todoDisplays }
            set { board.todoDisplays = newValue }
        }

        var sprintBoardData: SprintBoardData {
            get { board.sprintBoardData }
            set { board.sprintBoardData = newValue }
        }

        var selectedFilter: RoutineListFilter {
            get { taskFilters.selectedFilter }
            set { taskFilters.selectedFilter = newValue }
        }

        var selectedTag: String? {
            get { taskFilters.selectedTag }
            set { taskFilters.selectedTag = newValue }
        }

        var excludedTags: Set<String> {
            get { taskFilters.excludedTags }
            set { taskFilters.excludedTags = newValue }
        }

        var selectedManualPlaceFilterID: UUID? {
            get { taskFilters.selectedManualPlaceFilterID }
            set { taskFilters.selectedManualPlaceFilterID = newValue }
        }

        var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? {
            get { taskFilters.selectedImportanceUrgencyFilter }
            set { taskFilters.selectedImportanceUrgencyFilter = newValue }
        }

        var selectedTodoStateFilter: TodoState? {
            get { taskFilters.selectedTodoStateFilter }
            set { taskFilters.selectedTodoStateFilter = newValue }
        }

        var tabFilterSnapshots: [String: TabFilterStateManager.Snapshot] {
            get { taskFilters.tabFilterSnapshots }
            set { taskFilters.tabFilterSnapshots = newValue }
        }

        var isFilterSheetPresented: Bool {
            get { taskFilters.isFilterSheetPresented }
            set { taskFilters.isFilterSheetPresented = newValue }
        }

        var selectedTimelineRange: TimelineRange {
            get { timelineFilters.selectedRange }
            set { timelineFilters.selectedRange = newValue }
        }

        var selectedTimelineFilterType: TimelineFilterType {
            get { timelineFilters.selectedFilterType }
            set { timelineFilters.selectedFilterType = newValue }
        }

        var selectedTimelineTag: String? {
            get { timelineFilters.selectedTag }
            set { timelineFilters.selectedTag = newValue }
        }

        var selectedTimelineExcludedTags: Set<String> {
            get { timelineFilters.selectedExcludedTags }
            set { timelineFilters.selectedExcludedTags = newValue }
        }

        var selectedTimelineImportanceUrgencyFilter: ImportanceUrgencyFilterCell? {
            get { timelineFilters.selectedImportanceUrgencyFilter }
            set { timelineFilters.selectedImportanceUrgencyFilter = newValue }
        }

        var statsSelectedRange: DoneChartRange {
            get { statsFilters.selectedRange }
            set { statsFilters.selectedRange = newValue }
        }

        var statsSelectedTag: String? {
            get { statsFilters.selectedTag }
            set { statsFilters.selectedTag = newValue }
        }

        var macSidebarMode: MacSidebarMode {
            get { navigation.sidebarMode }
            set { navigation.sidebarMode = newValue }
        }

        var macSidebarSelection: MacSidebarSelection? {
            get { navigation.sidebarSelection }
            set { navigation.sidebarSelection = newValue }
        }

        var selectedSettingsSection: SettingsMacSection? {
            get { navigation.selectedSettingsSection }
            set { navigation.selectedSettingsSection = newValue }
        }

        var selectedBoardScope: BoardScope {
            get { board.selectedScope }
            set { board.selectedScope = newValue }
        }
    }

    enum Action: Equatable {
        case onAppear
        case manualRefreshRequested
        case tasksLoadedSuccessfully([RoutineTask], [RoutinePlace], [RoutineLog], DoneStats)
        case sprintBoardLoaded(SprintBoardData)
        case tasksLoadFailed
        case locationSnapshotUpdated(LocationSnapshot)
        case hideUnavailableRoutinesChanged(Bool)
        case setSelectedTask(UUID?)

        case setAddRoutineSheet(Bool)
        case deleteTasksTapped([UUID])
        case setDeleteConfirmation(Bool)
        case setMacFilterDetailPresented(Bool)
        case taskListModeChanged(TaskListMode)
        case deleteTasksConfirmed
        case deleteTasks([UUID])
        case markTaskDone(UUID)
        case moveTodoToState(UUID, TodoState)
        case moveTodoOnBoard(taskID: UUID, targetState: TodoState, orderedTaskIDs: [UUID])
        case selectedBoardScopeChanged(BoardScope)
        case createSprintTapped
        case startSprintTapped(UUID)
        case finishSprintTapped(UUID)
        case assignTodoToSprint(taskID: UUID, sprintID: UUID?)
        case notTodayTask(UUID)
        case pauseTask(UUID)
        case resumeTask(UUID)
        case pinTask(UUID)
        case unpinTask(UUID)
        case moveTaskInSection(taskID: UUID, sectionKey: String, orderedTaskIDs: [UUID], direction: MoveDirection)
        case setTaskOrderInSection(sectionKey: String, orderedTaskIDs: [UUID])

        // Filter actions
        case selectedFilterChanged(RoutineListFilter)
        case selectedTagChanged(String?)
        case excludedTagsChanged(Set<String>)
        case selectedManualPlaceFilterIDChanged(UUID?)
        case selectedImportanceUrgencyFilterChanged(ImportanceUrgencyFilterCell?)
        case selectedTodoStateFilterChanged(TodoState?)
        case isFilterSheetPresentedChanged(Bool)
        case clearOptionalFilters

        // Timeline filter actions
        case selectedTimelineRangeChanged(TimelineRange)
        case selectedTimelineFilterTypeChanged(TimelineFilterType)
        case selectedTimelineTagChanged(String?)
        case selectedTimelineExcludedTagsChanged(Set<String>)
        case selectedTimelineImportanceUrgencyFilterChanged(ImportanceUrgencyFilterCell?)

        // Stats filter actions
        case statsSelectedRangeChanged(DoneChartRange)
        case statsSelectedTagChanged(String?)

        // macOS navigation actions
        case macSidebarModeChanged(MacSidebarMode)
        case macSidebarSelectionChanged(MacSidebarSelection?)
        case selectedSettingsSectionChanged(SettingsMacSection?)

        case addRoutineSheet(AddRoutineFeature.Action)
        case taskDetail(TaskDetailFeature.Action)
        case routineSavedSuccessfully(RoutineTask)
        case routineSaveFailed
    }

    private enum CancelID {
        case loadTasks
    }

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.modelContext) var modelContext
    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now
    @Dependency(\.locationClient) var locationClient
    @Dependency(\.cloudSyncClient) var cloudSyncClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.appSettingsClient) var appSettingsClient
    @Dependency(\.sprintBoardClient) var sprintBoardClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                applyTemporaryViewState(appSettingsClient.temporaryViewState(), to: &state)
                return .concatenate(
                    loadTasksEffect(),
                    loadSprintBoardEffect(),
                    .run { @MainActor send in
                        let snapshot = await self.locationClient.snapshot(false)
                        send(.locationSnapshotUpdated(snapshot))
                    }
                )

            case .manualRefreshRequested:
                return .run { @MainActor send in
                    let context = self.modelContext()
                    if context.hasChanges {
                        try? context.save()
                    }

                    try? await self.cloudSyncClient.pullLatestIntoLocalStore(context)
                    send(.onAppear)

                    // CloudKit imports are asynchronous; do a second pass shortly after manual refresh.
                    try? await self.clock.sleep(for: .seconds(2))
                    send(.onAppear)
                }

            case let .tasksLoadedSuccessfully(tasks, places, logs, doneStats):
                let detachedTasks = detachedTasks(from: tasks)
                let detachedPlaces = detachedPlaces(from: places)
                let reconciliation = HomeReloadGuardSupport.reconcileSelectedDetailTask(
                    detachedTasks,
                    selectedTaskID: state.selection.selectedTaskID,
                    detailTask: state.selection.taskDetailState?.task,
                    selectedTaskReloadGuard: state.selection.selectedTaskReloadGuard
                )
                let reconciledTasks = reconciliation.tasks
                state.selection.selectedTaskReloadGuard = reconciliation.selectedTaskReloadGuard
                state.routineTasks = reconciledTasks
                state.routinePlaces = detachedPlaces
                state.timelineLogs = logs.sorted {
                    let lhs = $0.timestamp ?? .distantPast
                    let rhs = $1.timestamp ?? .distantPast
                    return lhs > rhs
                }
                state.doneStats = doneStats
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)
                validateFilterState(&state)
                persistTemporaryViewState(state)
                let detailRefreshEffect = refreshSelectedTaskDetailEffect(for: state)
                guard state.presentation.addRoutineState != nil else { return detailRefreshEffect }
                return .merge(
                    detailRefreshEffect,
                    .send(.addRoutineSheet(.existingRoutineNamesChanged(existingRoutineNames(from: reconciledTasks)))),
                    .send(.addRoutineSheet(.availableTagSummariesChanged(
                        RoutineTag.summaries(
                            from: reconciledTasks,
                            countsByTaskID: doneStats.countsByTaskID
                        )
                    ))),
                    .send(.addRoutineSheet(.availablePlacesChanged(RoutinePlace.summaries(from: detachedPlaces, linkedTo: reconciledTasks)))),
                    .send(.addRoutineSheet(.availableRelationshipTasksChanged(RoutineTaskRelationshipCandidate.from(reconciledTasks))))
                )

            case let .sprintBoardLoaded(sprintBoardData):
                state.sprintBoardData = sprintBoardData
                if case .currentSprint = state.selectedBoardScope,
                   sprintBoardData.activeSprint == nil {
                    state.selectedBoardScope = .backlog
                } else if case let .sprint(sprintID) = state.selectedBoardScope,
                          !sprintBoardData.sprints.contains(where: { $0.id == sprintID }) {
                    state.selectedBoardScope = .backlog
                }
                refreshDisplays(&state)
                return .none

            case .tasksLoadFailed:
                print("Failed to load tasks.")
                return .none

            case let .locationSnapshotUpdated(snapshot):
                state.locationSnapshot = snapshot
                refreshDisplays(&state)
                return .none

            case let .hideUnavailableRoutinesChanged(isHidden):
                state.hideUnavailableRoutines = isHidden
                appSettingsClient.setHideUnavailableRoutines(isHidden)
                persistTemporaryViewState(state)
                return .none

            case let .setSelectedTask(taskID):
                if let taskID,
                   state.selectedTaskID == taskID,
                   state.taskDetailState?.task.id == taskID {
                    state.presentation.isMacFilterDetailPresented = false
                    return .none
                }
                state.selection.selectedTaskID = taskID
                if taskID != nil {
                    state.presentation.isMacFilterDetailPresented = false
                }
                // Keep macSidebarSelection in sync when in routines mode
                if state.macSidebarMode == .routines || state.macSidebarMode == .board {
                    state.macSidebarSelection = taskID.map(MacSidebarSelection.task)
                }
                _ = HomeSelectionEditor.selectTask(
                    taskID: taskID,
                    tasks: state.routineTasks,
                    selection: &state.selection,
                    makeTaskDetailState: makeTaskDetailState(for:)
                )
                return refreshSelectedTaskDetailEffect(for: state)

            case let .setAddRoutineSheet(isPresented):
                state.presentation.isAddRoutineSheetPresented = isPresented
                if isPresented {
                    state.presentation.isMacFilterDetailPresented = false
                    state.presentation.addRoutineState = HomeAddRoutineSupport.makeAddRoutineState(
                        tasks: state.routineTasks,
                        places: state.routinePlaces,
                        doneStats: state.doneStats,
                        tagCounterDisplayMode: appSettingsClient.tagCounterDisplayMode()
                    )
                } else {
                    state.presentation.addRoutineState = nil
                }
                return .none

            case let .deleteTasksTapped(ids):
                let uniqueIDs = uniqueTaskIDs(ids)
                guard !uniqueIDs.isEmpty else { return .none }
                state.presentation.pendingDeleteTaskIDs = uniqueIDs
                state.presentation.isDeleteConfirmationPresented = true
                return .none

            case let .setDeleteConfirmation(isPresented):
                state.presentation.isDeleteConfirmationPresented = isPresented
                if !isPresented {
                    state.presentation.pendingDeleteTaskIDs = []
                }
                return .none

            case let .taskListModeChanged(mode):
                let oldMode = state.taskListMode
                var taskFilters = state.taskFilters
                var hideUnavailableRoutines = state.hideUnavailableRoutines
                let didResetHideUnavailableRoutines = HomeFilterEditor.transitionTaskListMode(
                    from: oldMode.rawValue,
                    to: mode.rawValue,
                    taskFilters: &taskFilters,
                    hideUnavailableRoutines: &hideUnavailableRoutines
                )
                state.taskFilters = taskFilters
                state.hideUnavailableRoutines = hideUnavailableRoutines
                if didResetHideUnavailableRoutines {
                    appSettingsClient.setHideUnavailableRoutines(false)
                }
                state.taskListMode = mode
                state.presentation.isMacFilterDetailPresented = false
                // Clear task selection if the selected task doesn't match the new mode
                if let selectedTaskID = state.selection.selectedTaskID,
                   let task = state.routineTasks.first(where: { $0.id == selectedTaskID }) {
                    let keepSelection: Bool
                    switch mode {
                    case .all:
                        keepSelection = true
                    case .routines:
                        keepSelection = !task.isOneOffTask
                    case .todos:
                        keepSelection = task.isOneOffTask
                    }
                    if !keepSelection {
                        state.selection.selectedTaskID = nil
                        state.selection.taskDetailState = nil
                    }
                }
                if state.selection.selectedTaskID == nil {
                    state.macSidebarSelection = nil
                }
                persistTemporaryViewState(state)
                return .none

            case let .setMacFilterDetailPresented(isPresented):
                state.presentation.isMacFilterDetailPresented = isPresented
                if isPresented {
                    state.presentation.isAddRoutineSheetPresented = false
                    state.presentation.addRoutineState = nil
                    // Clear list selection so re-clicking the same routine
                    // triggers a fresh selection change on macOS.
                    state.selection.selectedTaskID = nil
                }
                return .none

            // MARK: - Filter actions

            case let .selectedFilterChanged(filter):
                state.selectedFilter = filter
                persistTemporaryViewState(state)
                return .none

            case let .selectedTagChanged(tag):
                state.selectedTag = tag
                persistTemporaryViewState(state)
                return .none

            case let .excludedTagsChanged(tags):
                state.excludedTags = tags
                persistTemporaryViewState(state)
                return .none

            case let .selectedManualPlaceFilterIDChanged(id):
                state.selectedManualPlaceFilterID = id
                persistTemporaryViewState(state)
                return .none

            case let .selectedImportanceUrgencyFilterChanged(filter):
                state.selectedImportanceUrgencyFilter = filter
                persistTemporaryViewState(state)
                return .none

            case let .selectedTodoStateFilterChanged(filter):
                state.selectedTodoStateFilter = filter
                persistTemporaryViewState(state)
                return .none

            case let .isFilterSheetPresentedChanged(isPresented):
                state.isFilterSheetPresented = isPresented
                return .none

            case .clearOptionalFilters:
                var taskFilters = state.taskFilters
                var hideUnavailableRoutines = state.hideUnavailableRoutines
                let didResetHideUnavailableRoutines = HomeFilterEditor.clearOptionalFilters(
                    taskFilters: &taskFilters,
                    hideUnavailableRoutines: &hideUnavailableRoutines
                )
                state.taskFilters = taskFilters
                state.hideUnavailableRoutines = hideUnavailableRoutines
                if didResetHideUnavailableRoutines {
                    appSettingsClient.setHideUnavailableRoutines(false)
                }
                persistTemporaryViewState(state)
                return .none

            // MARK: - Timeline filter actions

            case let .selectedTimelineRangeChanged(range):
                state.selectedTimelineRange = range
                persistTemporaryViewState(state)
                return .none

            case let .selectedTimelineFilterTypeChanged(filterType):
                state.selectedTimelineFilterType = filterType
                persistTemporaryViewState(state)
                return .none

            case let .selectedTimelineTagChanged(tag):
                state.selectedTimelineTag = tag
                persistTemporaryViewState(state)
                return .none

            case let .selectedTimelineExcludedTagsChanged(tags):
                state.selectedTimelineExcludedTags = tags
                persistTemporaryViewState(state)
                return .none

            case let .selectedTimelineImportanceUrgencyFilterChanged(filter):
                state.selectedTimelineImportanceUrgencyFilter = filter
                persistTemporaryViewState(state)
                return .none

            // MARK: - Stats filter actions

            case let .statsSelectedRangeChanged(range):
                state.statsSelectedRange = range
                persistTemporaryViewState(state)
                return .none

            case let .statsSelectedTagChanged(tag):
                state.statsSelectedTag = tag
                persistTemporaryViewState(state)
                return .none

            // MARK: - macOS navigation actions

            case let .macSidebarModeChanged(mode):
                state.macSidebarMode = mode
                state.presentation.isMacFilterDetailPresented = false
                switch mode {
                case .routines:
                    // Close add sheet; selection/taskListMode sync happens via setSelectedTask
                    if state.presentation.isAddRoutineSheetPresented {
                        state.presentation.isAddRoutineSheetPresented = false
                        state.presentation.addRoutineState = nil
                    }
                    // Restore macSidebarSelection to reflect selectedTaskID
                    state.macSidebarSelection = state.selection.selectedTaskID.map(MacSidebarSelection.task)
                    // Sync taskListMode to the currently selected task (if any)
                    if let taskID = state.selection.selectedTaskID,
                       let task = state.routineTasks.first(where: { $0.id == taskID }) {
                        let newMode: TaskListMode = task.isOneOffTask ? .todos : .routines
                        if newMode != state.taskListMode {
                            return .send(.taskListModeChanged(newMode))
                        }
                    }
                case .board:
                    if state.presentation.isAddRoutineSheetPresented {
                        state.presentation.isAddRoutineSheetPresented = false
                        state.presentation.addRoutineState = nil
                    }
                    if let taskID = state.selection.selectedTaskID,
                       let task = state.routineTasks.first(where: { $0.id == taskID }),
                       task.isOneOffTask {
                        state.macSidebarSelection = .task(taskID)
                    } else {
                        state.macSidebarSelection = nil
                        HomeSelectionEditor.clearTaskSelection(&state.selection)
                    }
                    if state.taskListMode != .todos {
                        return .send(.taskListModeChanged(.todos))
                    }
                case .timeline, .stats, .settings:
                    if state.presentation.isAddRoutineSheetPresented {
                        state.presentation.isAddRoutineSheetPresented = false
                        state.presentation.addRoutineState = nil
                    }
                    state.macSidebarSelection = nil
                    HomeSelectionEditor.clearTaskSelection(&state.selection)
                    if mode == .settings && state.selectedSettingsSection == nil {
                        state.selectedSettingsSection = .notifications
                    }
                case .addTask:
                    state.macSidebarSelection = nil
                    if state.presentation.isAddRoutineSheetPresented {
                        state.presentation.isAddRoutineSheetPresented = false
                        state.presentation.addRoutineState = nil
                    }
                }
                persistTemporaryViewState(state)
                return .none

            case let .macSidebarSelectionChanged(selection):
                state.macSidebarSelection = selection
                state.presentation.isAddRoutineSheetPresented = false
                state.presentation.addRoutineState = nil
                state.presentation.isMacFilterDetailPresented = false
                switch selection {
                case let .task(taskID):
                    if state.macSidebarMode != .board {
                        state.macSidebarMode = .routines
                    }
                    // Sync taskListMode and save/restore filter snapshots inline
                    if let task = state.routineTasks.first(where: { $0.id == taskID }) {
                        let newMode: TaskListMode = task.isOneOffTask ? .todos : .routines
                        if newMode != state.taskListMode {
                            let oldMode = state.taskListMode
                            state.tabFilterSnapshots[oldMode.rawValue] = TabFilterStateManager.Snapshot(
                                selectedTag: state.selectedTag,
                                excludedTags: state.excludedTags,
                                selectedFilter: state.selectedFilter,
                                selectedManualPlaceFilterID: state.selectedManualPlaceFilterID,
                                selectedImportanceUrgencyFilter: state.selectedImportanceUrgencyFilter
                            )
                            let savedSnapshot = state.tabFilterSnapshots[newMode.rawValue]
                            let snapshot = savedSnapshot ?? .default
                            state.selectedTag = snapshot.selectedTag
                            state.excludedTags = snapshot.excludedTags
                            state.selectedFilter = snapshot.selectedFilter
                            state.selectedManualPlaceFilterID = snapshot.selectedManualPlaceFilterID
                            state.selectedImportanceUrgencyFilter = snapshot.selectedImportanceUrgencyFilter
                            if savedSnapshot == nil && state.hideUnavailableRoutines {
                                state.hideUnavailableRoutines = false
                                appSettingsClient.setHideUnavailableRoutines(false)
                            }
                            state.taskListMode = newMode
                            persistTemporaryViewState(state)
                        }
                    }
                    return .send(.setSelectedTask(taskID))
                case .timelineEntry:
                    state.macSidebarMode = .timeline
                    // Task resolution requires @Query data — handled by view sending .setSelectedTask
                    return .none
                case nil:
                    if state.macSidebarMode == .routines {
                        return .send(.setSelectedTask(nil))
                    }
                    return .none
                }

            case let .selectedSettingsSectionChanged(section):
                state.selectedSettingsSection = section
                persistTemporaryViewState(state)
                return .none

            case .deleteTasksConfirmed:
                let ids = state.presentation.pendingDeleteTaskIDs
                state.presentation.pendingDeleteTaskIDs = []
                state.presentation.isDeleteConfirmationPresented = false
                return handleDeleteTasks(ids, state: &state)

            case let .deleteTasks(ids):
                return handleDeleteTasks(ids, state: &state)

            case let .markTaskDone(id):
                var routineTasks = state.routineTasks
                var doneStats = state.doneStats
                guard let update = HomeTaskLifecycleSupport.markTaskDone(
                    taskID: id,
                    referenceDate: now,
                    calendar: calendar,
                    tasks: &routineTasks,
                    doneStats: &doneStats
                ) else {
                    return .none
                }
                state.routineTasks = routineTasks
                state.doneStats = doneStats
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)

                switch update {
                case let .checklist(checklistUpdate):
                    return HomeTaskLifecycleExecutionSupport.markChecklistItemsPurchased(
                        checklistUpdate,
                        calendar: calendar,
                        modelContext: { self.modelContext() },
                        scheduleNotification: { payload in
                            await self.notificationClient.schedule(payload)
                        }
                    )

                case let .advance(advanceUpdate):
                    return HomeTaskLifecycleExecutionSupport.advanceTask(
                        advanceUpdate,
                        calendar: calendar,
                        modelContext: { self.modelContext() },
                        cancelNotification: { identifier in
                            await self.notificationClient.cancel(identifier)
                        },
                        scheduleNotification: { payload in
                            await self.notificationClient.schedule(payload)
                        }
                    )
                }

            case let .moveTodoToState(id, newState):
                return handleMoveTodoToState(
                    id,
                    newState: newState,
                    state: &state
                )

            case let .moveTodoOnBoard(taskID, targetState, orderedTaskIDs):
                return handleMoveTodoOnBoard(
                    taskID: taskID,
                    targetState: targetState,
                    orderedTaskIDs: orderedTaskIDs,
                    state: &state
                )

            case let .selectedBoardScopeChanged(scope):
                state.selectedBoardScope = scope
                return .none

            case .createSprintTapped:
                return handleCreateSprint(state: &state)

            case let .startSprintTapped(sprintID):
                return handleStartSprint(
                    sprintID,
                    state: &state
                )

            case let .finishSprintTapped(sprintID):
                return handleFinishSprint(
                    sprintID,
                    state: &state
                )

            case let .assignTodoToSprint(taskID, sprintID):
                return handleAssignTodoToSprint(
                    taskID: taskID,
                    sprintID: sprintID,
                    state: &state
                )

            case let .pauseTask(id):
                guard let update = HomeTaskLifecycleSupport.pauseTask(
                    taskID: id,
                    pauseDate: now,
                    calendar: calendar,
                    tasks: &state.routineTasks
                ) else {
                    return .none
                }
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)

                return HomeTaskLifecycleExecutionSupport.pauseTask(
                    update,
                    modelContext: { self.modelContext() },
                    cancelNotification: { identifier in
                        await self.notificationClient.cancel(identifier)
                    }
                )

            case let .resumeTask(id):
                guard let update = HomeTaskLifecycleSupport.resumeTask(
                    taskID: id,
                    resumeDate: now,
                    calendar: calendar,
                    tasks: &state.routineTasks
                ) else {
                    return .none
                }
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)

                return HomeTaskLifecycleExecutionSupport.resumeTask(
                    update,
                    calendar: calendar,
                    modelContext: { self.modelContext() },
                    scheduleNotification: { payload in
                        await self.notificationClient.schedule(payload)
                    }
                )

            case let .notTodayTask(id):
                guard let update = HomeTaskLifecycleSupport.notTodayTask(
                    taskID: id,
                    referenceDate: now,
                    calendar: calendar,
                    tasks: &state.routineTasks
                ) else {
                    return .none
                }
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)

                return HomeTaskLifecycleExecutionSupport.notTodayTask(
                    update,
                    calendar: calendar,
                    modelContext: { self.modelContext() },
                    scheduleNotification: { payload in
                        await self.notificationClient.schedule(payload)
                    }
                )

            case let .pinTask(id):
                guard let update = HomeTaskLifecycleSupport.pinTask(
                    taskID: id,
                    pinnedAt: now,
                    tasks: &state.routineTasks
                ) else {
                    return .none
                }
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)

                return HomeTaskLifecycleExecutionSupport.pinTask(
                    update,
                    modelContext: { self.modelContext() }
                )

            case let .unpinTask(id):
                guard let update = HomeTaskLifecycleSupport.unpinTask(
                    taskID: id,
                    tasks: &state.routineTasks
                ) else {
                    return .none
                }
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)

                return HomeTaskLifecycleExecutionSupport.unpinTask(
                    update,
                    modelContext: { self.modelContext() }
                )

            case let .moveTaskInSection(taskID, sectionKey, orderedTaskIDs, direction):
                return moveTaskInSection(
                    taskID: taskID,
                    sectionKey: sectionKey,
                    orderedTaskIDs: orderedTaskIDs,
                    direction: direction,
                    state: &state
                )

            case let .setTaskOrderInSection(sectionKey, orderedTaskIDs):
                return setTaskOrderInSection(
                    sectionKey: sectionKey,
                    orderedTaskIDs: orderedTaskIDs,
                    state: &state
                )

            case .addRoutineSheet(.delegate(.didCancel)):
                state.presentation.isAddRoutineSheetPresented = false
                state.presentation.addRoutineState = nil
                return .none

            case let .addRoutineSheet(.delegate(.didSave(name, freq, recurrenceRule, emoji, notes, link, deadline, priority, importance, urgency, imageData, placeID, tags, relationships, steps, scheduleMode, checklistItems, attachments, color, autoAssumeDailyDone))):
                return .run { @MainActor send in
                    do {
                        let context = self.modelContext()
                        guard let trimmedName = RoutineTask.trimmedName(name), !trimmedName.isEmpty else {
                            send(.routineSaveFailed)
                            return
                        }

                        if try HomeDeduplicationSupport.hasDuplicateRoutineName(trimmedName, in: context) {
                            send(.routineSaveFailed)
                            return
                        }

                        let newRoutine = RoutineTask(
                            name: trimmedName,
                            emoji: emoji,
                            notes: notes,
                            link: link,
                            deadline: deadline,
                            priority: priority,
                            importance: importance,
                            urgency: urgency,
                            imageData: imageData,
                            placeID: placeID,
                            tags: tags,
                            relationships: relationships,
                            steps: steps,
                            checklistItems: checklistItems,
                            scheduleMode: scheduleMode,
                            interval: Int16(freq),
                            recurrenceRule: recurrenceRule,
                            lastDone: nil,
                            scheduleAnchor: scheduleMode == .oneOff ? nil : self.now,
                            color: color,
                            autoAssumeDailyDone: autoAssumeDailyDone
                        )
                        context.insert(newRoutine)
                        for item in attachments {
                            let att = RoutineAttachment(id: item.id, taskID: newRoutine.id, fileName: item.fileName, data: item.data)
                            context.insert(att)
                        }
                        try context.save()
                        send(.routineSavedSuccessfully(newRoutine))
                    } catch {
                        send(.routineSaveFailed)
                    }
                }

            case let .routineSavedSuccessfully(task):
                state.routineTasks.append(task.detachedCopy())
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)
                state.presentation.isAddRoutineSheetPresented = false
                state.presentation.addRoutineState = nil
                NotificationCenter.default.postRoutineDidUpdate()
                guard !task.isOneOffTask else { return .none }
                let payload = makeNotificationPayload(for: task, referenceDate: now)
                return .run { _ in
                    await self.notificationClient.schedule(payload)
                }

            case .routineSaveFailed:
                print("Failed to save routine.")
                return .none

            case .taskDetail(.routineDeleted):
                HomeSelectionEditor.clearTaskSelection(&state.selection)
                return .none

            case let .taskDetail(.toggleChecklistItemCompletion(itemID)):
                state.selection.pendingSelectedChecklistReloadGuardTaskID = HomeReloadGuardSupport
                    .pendingChecklistReloadGuardTaskID(
                        for: itemID,
                        selectedTaskID: state.selection.selectedTaskID,
                        detailState: state.selection.taskDetailState,
                        now: now,
                        calendar: calendar
                    )
                return .none

            case let .taskDetail(.markChecklistItemCompleted(itemID)):
                state.selection.pendingSelectedChecklistReloadGuardTaskID = HomeReloadGuardSupport
                    .pendingChecklistReloadGuardTaskID(
                        for: itemID,
                        selectedTaskID: state.selection.selectedTaskID,
                        detailState: state.selection.taskDetailState,
                        now: now,
                        calendar: calendar
                    )
                return .none

            case .taskDetail(.undoSelectedDateCompletion):
                state.selection.pendingSelectedChecklistReloadGuardTaskID = HomeReloadGuardSupport
                    .pendingChecklistUndoReloadGuardTaskID(
                        selectedTaskID: state.selection.selectedTaskID,
                        detailState: state.selection.taskDetailState
                    )
                return .none

            case .taskDetail(.logsLoaded):
                syncSelectedTaskFromTaskDetail(&state)
                return .none

            case let .taskDetail(.openLinkedTask(taskID)):
                guard HomeSelectionEditor.selectTask(
                    taskID: taskID,
                    tasks: state.routineTasks,
                    selection: &state.selection,
                    makeTaskDetailState: makeTaskDetailState(for:)
                ) else {
                    return .none
                }
                return refreshSelectedTaskDetailEffect(for: state)

            case .taskDetail(.openAddLinkedTask):
                guard let currentTaskID = state.selection.taskDetailState?.task.id,
                      let kind = state.selection.taskDetailState?.addLinkedTaskRelationshipKind else { return .none }
                state.presentation.isAddRoutineSheetPresented = true
                state.presentation.isMacFilterDetailPresented = false
                state.presentation.addRoutineState = HomeAddRoutineSupport.makeAddRoutineState(
                    tasks: state.routineTasks,
                    places: state.routinePlaces,
                    doneStats: state.doneStats,
                    tagCounterDisplayMode: appSettingsClient.tagCounterDisplayMode(),
                    preselectedRelationships: [
                        RoutineTaskRelationship(targetTaskID: currentTaskID, kind: kind.inverse)
                    ],
                    excludingRelationshipTaskID: currentTaskID
                )
                return .none

            case .taskDetail:
                return .none

            case .addRoutineSheet:
                return .none
            }
        }
        .ifLet(\.addRoutineState, action: \.addRoutineSheet) {
            AddRoutineFeature(
                onSave: { name, freq, recurrenceRule, emoji, notes, link, deadline, priority, importance, urgency, imageData, placeID, tags, relationships, steps, scheduleMode, checklistItems, attachments, color, autoAssumeDailyDone in
                    .send(.delegate(.didSave(name, freq, recurrenceRule, emoji, notes, link, deadline, priority, importance, urgency, imageData, placeID, tags, relationships, steps, scheduleMode, checklistItems, attachments, color, autoAssumeDailyDone)))
                },
                onCancel: { .send(.delegate(.didCancel)) }
            )
        }
        .ifLet(\.taskDetailState, action: \.taskDetail) {
            TaskDetailFeature()
        }
    }

    /// Prunes stale filter state after the task/place list is refreshed.
    private func validateFilterState(_ state: inout State) {
        HomeDisplayFilterSupport.validateTaskFilters(
            taskFilters: &state.taskFilters,
            routineDisplays: state.routineDisplays,
            awayRoutineDisplays: state.awayRoutineDisplays,
            archivedRoutineDisplays: state.archivedRoutineDisplays,
            routinePlaces: state.routinePlaces,
            tags: \.tags
        )
    }

    private func handleDeleteTasks(_ ids: [UUID], state: inout State) -> Effect<Action> {
        let uniqueIDs = uniqueTaskIDs(ids)
        guard !uniqueIDs.isEmpty else { return .none }

        let idSet = Set(uniqueIDs)
        RoutineTask.removeRelationships(targeting: idSet, from: state.routineTasks)
        state.routineTasks.removeAll { idSet.contains($0.id) }
        var removedDoneCount = 0
        var removedCanceledCount = 0
        for id in uniqueIDs {
            removedDoneCount += state.doneStats.countsByTaskID[id, default: 0]
            removedCanceledCount += state.doneStats.canceledCountsByTaskID[id, default: 0]
            state.doneStats.countsByTaskID.removeValue(forKey: id)
            state.doneStats.canceledCountsByTaskID.removeValue(forKey: id)
        }
        state.sprintBoardData.assignments.removeAll { assignment in
            idSet.contains(assignment.todoID)
        }
        state.doneStats.totalCount = max(state.doneStats.totalCount - removedDoneCount, 0)
        state.doneStats.canceledTotalCount = max(state.doneStats.canceledTotalCount - removedCanceledCount, 0)
        refreshDisplays(&state)
        syncSelectedTaskDetailState(&state)

        let deleteEffect: Effect<Action> = .run { @MainActor [uniqueIDs, sprintBoardData = state.sprintBoardData] _ in
            let context = self.modelContext()
            let allTasks = (try? context.fetch(FetchDescriptor<RoutineTask>())) ?? []
            RoutineTask.removeRelationships(targeting: idSet, from: allTasks)
            for id in uniqueIDs {
                let descriptor = FetchDescriptor<RoutineTask>(
                    predicate: #Predicate { task in
                        task.id == id
                    }
                )
                if let task = try context.fetch(descriptor).first {
                    context.delete(task)
                }
                let logs = try context.fetch(logsDescriptor(for: id))
                for log in logs {
                    context.delete(log)
                }
                await self.notificationClient.cancel(id.uuidString)
            }
            try? context.save()
            try? await self.sprintBoardClient.save(sprintBoardData)
            NotificationCenter.default.postRoutineDidUpdate()
        }
        guard state.presentation.addRoutineState != nil else { return deleteEffect }
        return .merge(
            deleteEffect,
            .send(.addRoutineSheet(.existingRoutineNamesChanged(existingRoutineNames(from: state.routineTasks)))),
            .send(.addRoutineSheet(.availableTagSummariesChanged(
                RoutineTag.summaries(
                    from: state.routineTasks,
                    countsByTaskID: state.doneStats.countsByTaskID
                )
            ))),
            .send(.addRoutineSheet(.availablePlacesChanged(RoutinePlace.summaries(from: state.routinePlaces, linkedTo: state.routineTasks)))),
            .send(.addRoutineSheet(.availableRelationshipTasksChanged(RoutineTaskRelationshipCandidate.from(state.routineTasks))))
        )
    }

    private func moveTaskInSection(
        taskID: UUID,
        sectionKey: String,
        orderedTaskIDs: [UUID],
        direction: MoveDirection,
        state: inout State
    ) -> Effect<Action> {
        let existingTaskIDs = Set(state.routineTasks.map(\.id))
        var seen: Set<UUID> = []
        var normalizedIDs: [UUID] = []
        normalizedIDs.reserveCapacity(orderedTaskIDs.count)
        for id in orderedTaskIDs where existingTaskIDs.contains(id) {
            if seen.insert(id).inserted {
                normalizedIDs.append(id)
            }
        }

        guard normalizedIDs.count > 1,
              let currentIndex = normalizedIDs.firstIndex(of: taskID) else {
            return .none
        }

        let targetIndex: Int
        switch direction {
        case .up:
            targetIndex = currentIndex - 1
        case .down:
            targetIndex = currentIndex + 1
        }
        guard normalizedIDs.indices.contains(targetIndex) else { return .none }

        normalizedIDs.swapAt(currentIndex, targetIndex)

        for (order, id) in normalizedIDs.enumerated() {
            guard let index = state.routineTasks.firstIndex(where: { $0.id == id }) else { continue }
            state.routineTasks[index].setManualSectionOrder(order, for: sectionKey)
        }
        refreshDisplays(&state)
        syncSelectedTaskDetailState(&state)

        return .run { @MainActor [normalizedIDs, sectionKey] _ in
            do {
                let context = self.modelContext()
                let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                let tasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
                for (order, id) in normalizedIDs.enumerated() {
                    tasksByID[id]?.setManualSectionOrder(order, for: sectionKey)
                }
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Failed to persist manual section order: \(error)")
            }
        }
    }

    private func setTaskOrderInSection(
        sectionKey: String,
        orderedTaskIDs: [UUID],
        state: inout State
    ) -> Effect<Action> {
        let existingTaskIDs = Set(state.routineTasks.map(\.id))
        var seen: Set<UUID> = []
        var normalizedIDs: [UUID] = []
        normalizedIDs.reserveCapacity(orderedTaskIDs.count)

        for id in orderedTaskIDs where existingTaskIDs.contains(id) {
            if seen.insert(id).inserted {
                normalizedIDs.append(id)
            }
        }

        guard !normalizedIDs.isEmpty else { return .none }

        for (order, id) in normalizedIDs.enumerated() {
            guard let index = state.routineTasks.firstIndex(where: { $0.id == id }) else { continue }
            state.routineTasks[index].setManualSectionOrder(order, for: sectionKey)
        }
        refreshDisplays(&state)
        syncSelectedTaskDetailState(&state)

        return .run { @MainActor [normalizedIDs, sectionKey] _ in
            do {
                let context = self.modelContext()
                let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                let tasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
                for (order, id) in normalizedIDs.enumerated() {
                    tasksByID[id]?.setManualSectionOrder(order, for: sectionKey)
                }
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Failed to persist board section order: \(error)")
            }
        }
    }

    func taskDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineTask> {
        HomeTaskSupport.taskDescriptor(for: taskID)
    }

    func logsDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineLog> {
        HomeTaskSupport.logsDescriptor(for: taskID)
    }

    private func makeNotificationPayload(
        for task: RoutineTask,
        referenceDate: Date
    ) -> NotificationPayload {
        NotificationCoordinator.notificationPayload(for: task, referenceDate: referenceDate, calendar: calendar)
    }

    static func boardSectionKey(for state: TodoState) -> String {
        switch state {
        case .ready, .paused:
            return "todoBoard.ready"
        case .inProgress:
            return "todoBoard.inProgress"
        case .blocked:
            return "todoBoard.blocked"
        case .done:
            return "todoBoard.done"
        }
    }

    func nextManualOrder(in sectionKey: String, tasks: [RoutineTask]) -> Int {
        let maxOrder = tasks.compactMap { $0.manualSectionOrders[sectionKey] }.max() ?? -1
        return maxOrder + 1
    }

    private func loadSprintBoardEffect() -> Effect<Action> {
        .run { send in
            do {
                let sprintBoardData = try await sprintBoardClient.load()
                await send(.sprintBoardLoaded(sprintBoardData))
            } catch {
                print("Failed to load sprint board data: \(error)")
                await send(.sprintBoardLoaded(SprintBoardData()))
            }
        }
    }

    func saveSprintBoardEffect(_ sprintBoardData: SprintBoardData) -> Effect<Action> {
        .run { _ in
            do {
                try await sprintBoardClient.save(sprintBoardData)
            } catch {
                print("Failed to save sprint board data: \(error)")
            }
        }
    }

    private func loadTasksEffect() -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = ModelContext(self.modelContext().container)
                try HomeDeduplicationSupport.enforceUniqueRoutineNames(in: context)
                try HomeDeduplicationSupport.enforceUniquePlaceNames(in: context)
                _ = try RoutineLogHistory.backfillMissingLastDoneLogs(in: context)
                let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                let places = try context.fetch(FetchDescriptor<RoutinePlace>())
                let logs = try context.fetch(FetchDescriptor<RoutineLog>())
                send(.tasksLoadedSuccessfully(tasks, places, logs, self.makeDoneStats(tasks: tasks, logs: logs)))
            } catch {
                send(.tasksLoadFailed)
            }
        }
        .cancellable(id: CancelID.loadTasks, cancelInFlight: true)
    }

    func syncSelectedTaskDetailState(_ state: inout State) {
        guard let selectedTaskID = state.selection.selectedTaskID else {
            HomeSelectionEditor.clearTaskSelection(&state.selection)
            return
        }

        guard let task = state.routineTasks.first(where: { $0.id == selectedTaskID }) else {
            HomeSelectionEditor.clearTaskSelection(&state.selection)
            return
        }

        if var detailState = state.selection.taskDetailState {
            detailState.task = task.detachedCopy()
            detailState.taskRefreshID &+= 1
            detailState.daysSinceLastRoutine = RoutineDateMath.elapsedDaysSinceLastDone(
                from: detailState.task.lastDone,
                referenceDate: now
            )
            detailState.overdueDays = detailState.task.isArchived(referenceDate: now, calendar: calendar)
                ? 0
                : RoutineDateMath.overdueDays(for: detailState.task, referenceDate: now, calendar: calendar)
            detailState.isDoneToday = detailState.task.lastDone.map { calendar.isDate($0, inSameDayAs: now) } ?? false
            detailState.isAssumedDoneToday = RoutineAssumedCompletion.isAssumedDone(
                for: detailState.task,
                on: now,
                logs: detailState.logs
            )
            state.selection.taskDetailState = detailState
        } else {
            state.selection.taskDetailState = makeTaskDetailState(for: task)
        }
    }

    private func refreshSelectedTaskDetailEffect(for state: State) -> Effect<Action> {
        guard state.selection.taskDetailState != nil else { return .none }
        return .send(.taskDetail(.onAppear))
    }

    private func syncSelectedTaskFromTaskDetail(_ state: inout State) {
        guard let detailTask = state.selection.taskDetailState?.task else { return }
        guard let index = state.routineTasks.firstIndex(where: { $0.id == detailTask.id }) else { return }
        let syncedTask = detailTask.detachedCopy()
        state.routineTasks[index] = syncedTask
        if state.selection.pendingSelectedChecklistReloadGuardTaskID == syncedTask.id,
           syncedTask.isChecklistCompletionRoutine,
           state.selection.selectedTaskID == detailTask.id {
            state.selection.selectedTaskReloadGuard = HomeReloadGuardSupport.makeSelectedTaskReloadGuard(for: syncedTask)
        }
        state.selection.pendingSelectedChecklistReloadGuardTaskID = nil
        refreshDisplays(&state)
    }

    private func detachedTasks(from tasks: [RoutineTask]) -> [RoutineTask] {
        tasks.map { $0.detachedCopy() }
    }

    private func detachedPlaces(from places: [RoutinePlace]) -> [RoutinePlace] {
        places.map { $0.detachedCopy() }
    }

    private func applyTemporaryViewState(_ persistedState: TemporaryViewState?, to state: inout State) {
        let restoredState = HomeTemporaryViewStateMapper.restore(
            from: persistedState,
            defaultHideUnavailableRoutines: appSettingsClient.hideUnavailableRoutines()
        )
        state.hideUnavailableRoutines = restoredState.hideUnavailableRoutines
        state.taskFilters = restoredState.taskFilters
        state.timelineFilters = restoredState.timelineFilters
        state.statsFilters = restoredState.statsFilters

        if let rawValue = restoredState.macSidebarModeRawValue,
           let mode = MacSidebarMode(rawValue: rawValue) {
            state.macSidebarMode = mode
        }
        if let rawValue = restoredState.macSelectedSettingsSectionRawValue {
            state.selectedSettingsSection = SettingsMacSection(rawValue: rawValue)
        }

        if let rawValue = restoredState.taskListModeRawValue,
           let mode = TaskListMode(rawValue: rawValue) {
            state.taskListMode = mode
        }
    }

    private func persistTemporaryViewState(_ state: State) {
        appSettingsClient.setTemporaryViewState(
            HomeTemporaryViewStateMapper.makeTemporaryViewState(
                existing: appSettingsClient.temporaryViewState(),
                values: HomeTemporaryViewStateValues(
                    hideUnavailableRoutines: state.hideUnavailableRoutines,
                    taskListModeRawValue: state.taskListMode.rawValue,
                    taskFilters: state.taskFilters,
                    timelineFilters: state.timelineFilters,
                    statsFilters: state.statsFilters,
                    macSidebarModeRawValue: state.macSidebarMode.rawValue,
                    macSelectedSettingsSectionRawValue: state.selectedSettingsSection?.rawValue
                )
            )
        )
    }

}

extension HomeFeature {
    @MainActor
    static func detailLogs(taskID: UUID, context: ModelContext) -> [RoutineLog] {
        RoutineLogHistory.detailLogs(taskID: taskID, context: context)
    }

    static func availableTags(from routineDisplays: [RoutineDisplay]) -> [String] {
        tagSummaries(from: routineDisplays).map(\.name)
    }

    static func tagSummaries(from routineDisplays: [RoutineDisplay]) -> [RoutineTagSummary] {
        HomeDisplayFilterSupport.tagSummaries(from: routineDisplays, tags: \.tags)
    }

    static func matchesSelectedTag(_ selectedTag: String?, in tags: [String]) -> Bool {
        HomeDisplayFilterSupport.matchesSelectedTag(selectedTag, in: tags)
    }

    static func matchesExcludedTags(_ excludedTags: Set<String>, in tags: [String]) -> Bool {
        HomeDisplayFilterSupport.matchesExcludedTags(excludedTags, in: tags)
    }

    static func matchesImportanceUrgencyFilter(
        _ selectedFilter: ImportanceUrgencyFilterCell?,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency
    ) -> Bool {
        HomeDisplayFilterSupport.matchesImportanceUrgencyFilter(
            selectedFilter,
            importance: importance,
            urgency: urgency
        )
    }

    static func matchesTodoStateFilter(_ filter: TodoState?, task: RoutineDisplay) -> Bool {
        HomeDisplayFilterSupport.matchesTodoStateFilter(
            filter,
            isOneOffTask: task.isOneOffTask,
            todoState: task.todoState
        )
    }
}
