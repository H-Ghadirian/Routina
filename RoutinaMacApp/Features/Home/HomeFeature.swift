import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct HomeFeature {
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

    typealias MoveDirection = HomeTaskMoveDirection

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
        var isSoftIntervalRoutine: Bool
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
        var isOngoing: Bool
        var ongoingSince: Date?
        var hasPassedSoftThreshold: Bool
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
        var relatedTagRules: [RoutineRelatedTagRule] = []

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
            selectedTags: Set<String> = [],
            includeTagMatchMode: RoutineTagMatchMode = .all,
            excludedTags: Set<String> = [],
            excludeTagMatchMode: RoutineTagMatchMode = .any,
            selectedManualPlaceFilterID: UUID? = nil,
            selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
            selectedTodoStateFilter: TodoState? = nil,
            taskListViewMode: HomeTaskListViewMode = .all,
            tabFilterSnapshots: [String: TabFilterStateManager.Snapshot] = [:],
            isFilterSheetPresented: Bool = false,
            selectedTimelineRange: TimelineRange = .all,
            selectedTimelineFilterType: TimelineFilterType = .all,
            selectedTimelineTag: String? = nil,
            selectedTimelineTags: Set<String> = [],
            selectedTimelineIncludeTagMatchMode: RoutineTagMatchMode = .all,
            selectedTimelineExcludedTags: Set<String> = [],
            selectedTimelineExcludeTagMatchMode: RoutineTagMatchMode = .any,
            selectedTimelineImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
            statsSelectedRange: DoneChartRange = .week,
            statsSelectedTag: String? = nil,
            statsSelectedTags: Set<String> = [],
            statsIncludeTagMatchMode: RoutineTagMatchMode = .all,
            macSidebarMode: MacSidebarMode = .routines,
            macSidebarSelection: MacSidebarSelection? = nil,
            selectedSettingsSection: SettingsMacSection? = .notifications,
            selectedBoardScope: BoardScope = .backlog,
            relatedTagRules: [RoutineRelatedTagRule] = []
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
                selectedTags: selectedTags.isEmpty ? selectedTag.map { [$0] } ?? [] : selectedTags,
                includeTagMatchMode: includeTagMatchMode,
                excludedTags: excludedTags,
                excludeTagMatchMode: excludeTagMatchMode,
                selectedManualPlaceFilterID: selectedManualPlaceFilterID,
                selectedImportanceUrgencyFilter: selectedImportanceUrgencyFilter,
                selectedTodoStateFilter: selectedTodoStateFilter,
                taskListViewMode: taskListViewMode,
                tabFilterSnapshots: tabFilterSnapshots,
                isFilterSheetPresented: isFilterSheetPresented
            )
            self.timelineFilters = HomeTimelineFiltersState(
                selectedRange: selectedTimelineRange,
                selectedFilterType: selectedTimelineFilterType,
                selectedTag: selectedTimelineTag,
                selectedTags: selectedTimelineTags.isEmpty ? selectedTimelineTag.map { [$0] } ?? [] : selectedTimelineTags,
                includeTagMatchMode: selectedTimelineIncludeTagMatchMode,
                selectedExcludedTags: selectedTimelineExcludedTags,
                excludeTagMatchMode: selectedTimelineExcludeTagMatchMode,
                selectedImportanceUrgencyFilter: selectedTimelineImportanceUrgencyFilter
            )
            self.statsFilters = HomeStatsFiltersState(
                selectedRange: statsSelectedRange,
                selectedTag: statsSelectedTag,
                selectedTags: statsSelectedTags.isEmpty ? statsSelectedTag.map { [$0] } ?? [] : statsSelectedTags,
                includeTagMatchMode: statsIncludeTagMatchMode
            )
            self.navigation = HomeMacNavigationState(
                sidebarMode: macSidebarMode,
                sidebarSelection: macSidebarSelection,
                selectedSettingsSection: selectedSettingsSection
            )
            self.relatedTagRules = relatedTagRules
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
            set { taskFilters.setSelectedTag(newValue) }
        }

        var selectedTags: Set<String> {
            get { taskFilters.effectiveSelectedTags }
            set { taskFilters.setSelectedTags(newValue) }
        }

        var includeTagMatchMode: RoutineTagMatchMode {
            get { taskFilters.includeTagMatchMode }
            set { taskFilters.includeTagMatchMode = newValue }
        }

        var excludedTags: Set<String> {
            get { taskFilters.excludedTags }
            set { taskFilters.excludedTags = newValue }
        }

        var excludeTagMatchMode: RoutineTagMatchMode {
            get { taskFilters.excludeTagMatchMode }
            set { taskFilters.excludeTagMatchMode = newValue }
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

        var taskListViewMode: HomeTaskListViewMode {
            get { taskFilters.taskListViewMode }
            set { taskFilters.taskListViewMode = newValue }
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
            set { timelineFilters.setSelectedTag(newValue) }
        }

        var selectedTimelineTags: Set<String> {
            get { timelineFilters.effectiveSelectedTags }
            set { timelineFilters.setSelectedTags(newValue) }
        }

        var selectedTimelineIncludeTagMatchMode: RoutineTagMatchMode {
            get { timelineFilters.includeTagMatchMode }
            set { timelineFilters.includeTagMatchMode = newValue }
        }

        var selectedTimelineExcludedTags: Set<String> {
            get { timelineFilters.selectedExcludedTags }
            set { timelineFilters.selectedExcludedTags = newValue }
        }

        var selectedTimelineExcludeTagMatchMode: RoutineTagMatchMode {
            get { timelineFilters.excludeTagMatchMode }
            set { timelineFilters.excludeTagMatchMode = newValue }
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
            set { statsFilters.setSelectedTag(newValue) }
        }

        var statsSelectedTags: Set<String> {
            get { statsFilters.effectiveSelectedTags }
            set { statsFilters.setSelectedTags(newValue) }
        }

        var statsIncludeTagMatchMode: RoutineTagMatchMode {
            get { statsFilters.includeTagMatchMode }
            set { statsFilters.includeTagMatchMode = newValue }
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

        var creatingSprintTitle: String? {
            get { board.creatingSprintTitle }
            set { board.creatingSprintTitle = newValue }
        }

        var renamingSprintID: UUID? {
            get { board.renamingSprintID }
            set { board.renamingSprintID = newValue }
        }

        var renamingSprintTitle: String {
            get { board.renamingSprintTitle }
            set { board.renamingSprintTitle = newValue }
        }

        var deletingSprintID: UUID? {
            get { board.deletingSprintID }
            set { board.deletingSprintID = newValue }
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
        case createSprintTitleChanged(String)
        case createSprintConfirmed
        case createSprintCanceled
        case startSprintTapped(UUID)
        case finishSprintTapped(UUID)
        case assignTodoToSprint(taskID: UUID, sprintID: UUID?)
        case renameSprintTapped(UUID)
        case renamingSprintTitleChanged(String)
        case renameSprintConfirmed
        case renameSprintCanceled
        case deleteSprintTapped(UUID)
        case deleteSprintConfirmed(UUID)
        case deleteSprintCanceled
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
        case selectedTagsChanged(Set<String>)
        case includeTagMatchModeChanged(RoutineTagMatchMode)
        case excludedTagsChanged(Set<String>)
        case excludeTagMatchModeChanged(RoutineTagMatchMode)
        case selectedManualPlaceFilterIDChanged(UUID?)
        case selectedImportanceUrgencyFilterChanged(ImportanceUrgencyFilterCell?)
        case selectedTodoStateFilterChanged(TodoState?)
        case taskListViewModeChanged(HomeTaskListViewMode)
        case isFilterSheetPresentedChanged(Bool)
        case clearOptionalFilters

        // Timeline filter actions
        case selectedTimelineRangeChanged(TimelineRange)
        case selectedTimelineFilterTypeChanged(TimelineFilterType)
        case selectedTimelineTagChanged(String?)
        case selectedTimelineTagsChanged(Set<String>)
        case selectedTimelineIncludeTagMatchModeChanged(RoutineTagMatchMode)
        case selectedTimelineExcludedTagsChanged(Set<String>)
        case selectedTimelineExcludeTagMatchModeChanged(RoutineTagMatchMode)
        case selectedTimelineImportanceUrgencyFilterChanged(ImportanceUrgencyFilterCell?)

        // Stats filter actions
        case statsSelectedRangeChanged(DoneChartRange)
        case statsSelectedTagChanged(String?)
        case statsSelectedTagsChanged(Set<String>)
        case statsIncludeTagMatchModeChanged(RoutineTagMatchMode)

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
                let snapshot = HomeTaskLoadSupport.makeSnapshot(
                    tasks: tasks,
                    places: places,
                    logs: logs,
                    doneStats: doneStats,
                    selectedTaskID: state.selection.selectedTaskID,
                    detailTask: state.selection.taskDetailState?.task,
                    selectedTaskReloadGuard: state.selection.selectedTaskReloadGuard,
                    persistedRelatedTagRules: appSettingsClient.relatedTagRules()
                )
                state.relatedTagRules = snapshot.relatedTagRules
                state.selection.selectedTaskReloadGuard = snapshot.selectedTaskReloadGuard
                state.routineTasks = snapshot.tasks
                state.routinePlaces = snapshot.places
                state.timelineLogs = snapshot.timelineLogs
                state.doneStats = snapshot.doneStats
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)
                validateFilterState(&state)
                persistTemporaryViewState(state)
                let detailRefreshEffect = refreshSelectedTaskDetailEffect(for: state)
                guard state.presentation.addRoutineState != nil else { return detailRefreshEffect }
                return .merge(
                    detailRefreshEffect,
                    .send(.addRoutineSheet(.existingRoutineNamesChanged(existingRoutineNames(from: snapshot.tasks)))),
                    .send(.addRoutineSheet(.availableTagSummariesChanged(
                        RoutineTag.summaries(
                            from: snapshot.tasks,
                            countsByTaskID: doneStats.countsByTaskID
                        )
                    ))),
                    .send(.addRoutineSheet(.availablePlacesChanged(RoutinePlace.summaries(from: snapshot.places, linkedTo: snapshot.tasks)))),
                    .send(.addRoutineSheet(.availableRelationshipTasksChanged(RoutineTaskRelationshipCandidate.from(snapshot.tasks))))
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
                let routineTasks = state.routineTasks
                _ = HomeSelectionEditor.selectTask(
                    taskID: taskID,
                    tasks: routineTasks,
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
                        tagCounterDisplayMode: appSettingsClient.tagCounterDisplayMode(),
                        relatedTagRules: appSettingsClient.relatedTagRules()
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
                let routineTasks = state.routineTasks
                HomeDetailSelectionSupport.clearSelectionIfNeededForTaskListMode(
                    selection: &state.selection,
                    tasks: routineTasks,
                    modeRawValue: mode.rawValue
                )
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
                return applyTaskFilterMutation(.selectedFilter(filter), state: &state)

            case let .selectedTagChanged(tag):
                return applyTaskFilterMutation(.selectedTag(tag), state: &state)

            case let .selectedTagsChanged(tags):
                return applyTaskFilterMutation(.selectedTags(tags), state: &state)

            case let .includeTagMatchModeChanged(mode):
                return applyTaskFilterMutation(.includeTagMatchMode(mode), state: &state)

            case let .excludedTagsChanged(tags):
                return applyTaskFilterMutation(.excludedTags(tags), state: &state)

            case let .excludeTagMatchModeChanged(mode):
                return applyTaskFilterMutation(.excludeTagMatchMode(mode), state: &state)

            case let .selectedManualPlaceFilterIDChanged(id):
                return applyTaskFilterMutation(.selectedManualPlaceFilterID(id), state: &state)

            case let .selectedImportanceUrgencyFilterChanged(filter):
                return applyTaskFilterMutation(.selectedImportanceUrgencyFilter(filter), state: &state)

            case let .selectedTodoStateFilterChanged(filter):
                return applyTaskFilterMutation(.selectedTodoStateFilter(filter), state: &state)

            case let .taskListViewModeChanged(mode):
                return applyTaskFilterMutation(.taskListViewMode(mode), state: &state)

            case let .isFilterSheetPresentedChanged(isPresented):
                return applyTaskFilterMutation(.isFilterSheetPresented(isPresented), state: &state)

            case .clearOptionalFilters:
                return applyTaskFilterMutation(.clearOptionalFilters, state: &state)

            // MARK: - Timeline filter actions

            case let .selectedTimelineRangeChanged(range):
                return applyTimelineFilterMutation(.selectedRange(range), state: &state)

            case let .selectedTimelineFilterTypeChanged(filterType):
                return applyTimelineFilterMutation(.selectedFilterType(filterType), state: &state)

            case let .selectedTimelineTagChanged(tag):
                return applyTimelineFilterMutation(.selectedTag(tag), state: &state)

            case let .selectedTimelineTagsChanged(tags):
                return applyTimelineFilterMutation(.selectedTags(tags), state: &state)

            case let .selectedTimelineIncludeTagMatchModeChanged(mode):
                return applyTimelineFilterMutation(.includeTagMatchMode(mode), state: &state)

            case let .selectedTimelineExcludedTagsChanged(tags):
                return applyTimelineFilterMutation(.selectedExcludedTags(tags), state: &state)

            case let .selectedTimelineExcludeTagMatchModeChanged(mode):
                return applyTimelineFilterMutation(.excludeTagMatchMode(mode), state: &state)

            case let .selectedTimelineImportanceUrgencyFilterChanged(filter):
                return applyTimelineFilterMutation(.selectedImportanceUrgencyFilter(filter), state: &state)

            // MARK: - Stats filter actions

            case let .statsSelectedRangeChanged(range):
                return applyStatsFilterMutation(.selectedRange(range), state: &state)

            case let .statsSelectedTagChanged(tag):
                return applyStatsFilterMutation(.selectedTag(tag), state: &state)

            case let .statsSelectedTagsChanged(tags):
                return applyStatsFilterMutation(.selectedTags(tags), state: &state)

            case let .statsIncludeTagMatchModeChanged(mode):
                return applyStatsFilterMutation(.includeTagMatchMode(mode), state: &state)

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
                            var taskFilters = state.taskFilters
                            var hideUnavailableRoutines = state.hideUnavailableRoutines
                            let didResetHideUnavailableRoutines = HomeFilterEditor.transitionTaskListMode(
                                from: oldMode.rawValue,
                                to: newMode.rawValue,
                                taskFilters: &taskFilters,
                                hideUnavailableRoutines: &hideUnavailableRoutines
                            )
                            state.taskFilters = taskFilters
                            state.hideUnavailableRoutines = hideUnavailableRoutines
                            if didResetHideUnavailableRoutines {
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
                state.creatingSprintTitle = ""
                return .none

            case let .createSprintTitleChanged(title):
                state.creatingSprintTitle = title
                return .none

            case .createSprintConfirmed:
                let title = state.creatingSprintTitle ?? ""
                return handleCreateSprintConfirmed(title: title, state: &state)

            case .createSprintCanceled:
                state.creatingSprintTitle = nil
                return .none

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

            case let .renameSprintTapped(id):
                let currentTitle = state.sprintBoardData.sprints.first(where: { $0.id == id })?.title ?? ""
                state.renamingSprintID = id
                state.renamingSprintTitle = currentTitle
                return .none

            case let .renamingSprintTitleChanged(title):
                state.renamingSprintTitle = title
                return .none

            case .renameSprintConfirmed:
                guard let id = state.renamingSprintID else { return .none }
                return handleRenameSprint(id: id, title: state.renamingSprintTitle, state: &state)

            case .renameSprintCanceled:
                state.renamingSprintID = nil
                state.renamingSprintTitle = ""
                return .none

            case let .deleteSprintTapped(id):
                state.deletingSprintID = id
                return .none

            case let .deleteSprintConfirmed(id):
                return handleDeleteSprint(id: id, state: &state)

            case .deleteSprintCanceled:
                state.deletingSprintID = nil
                return .none

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
                    cancelNotification: { identifier in
                        await self.notificationClient.cancel(identifier)
                    },
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
                    cancelNotification: { identifier in
                        await self.notificationClient.cancel(identifier)
                    },
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

            case let .addRoutineSheet(.delegate(.didSave(request))):
                return HomeAddRoutineSupport.saveRoutine(
                    from: request,
                    scheduleAnchor: { self.now },
                    modelContext: { self.modelContext() },
                    savedAction: { .routineSavedSuccessfully($0) },
                    failedAction: { .routineSaveFailed }
                )

            case let .routineSavedSuccessfully(task):
                state.routineTasks.append(task.detachedCopy())
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)
                state.presentation.isAddRoutineSheetPresented = false
                state.presentation.addRoutineState = nil
                NotificationCenter.default.postRoutineDidUpdate()
                guard NotificationCoordinator.shouldScheduleNotification(for: task, referenceDate: now, calendar: calendar) else {
                    return .none
                }
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
                HomeDetailSelectionSupport.updatePendingChecklistReloadGuard(
                    for: itemID,
                    selection: &state.selection,
                    now: now,
                    calendar: calendar
                )
                return .none

            case let .taskDetail(.markChecklistItemCompleted(itemID)):
                HomeDetailSelectionSupport.updatePendingChecklistReloadGuard(
                    for: itemID,
                    selection: &state.selection,
                    now: now,
                    calendar: calendar
                )
                return .none

            case .taskDetail(.undoSelectedDateCompletion):
                HomeDetailSelectionSupport.updatePendingChecklistUndoReloadGuard(selection: &state.selection)
                return .none

            case .taskDetail(.logsLoaded):
                syncSelectedTaskFromTaskDetail(&state)
                return .none

            case let .taskDetail(.openLinkedTask(taskID)):
                let routineTasks = state.routineTasks
                guard HomeSelectionEditor.selectTask(
                    taskID: taskID,
                    tasks: routineTasks,
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
                    relatedTagRules: appSettingsClient.relatedTagRules(),
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
                onSave: { request in
                    .send(.delegate(.didSave(request)))
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

    private func applyTaskFilterMutation(
        _ mutation: HomeTaskFilterMutation,
        state: inout State
    ) -> Effect<Action> {
        var taskFilters = state.taskFilters
        var hideUnavailableRoutines = state.hideUnavailableRoutines
        let result = HomeFilterEditor.apply(
            mutation,
            taskFilters: &taskFilters,
            hideUnavailableRoutines: &hideUnavailableRoutines
        )
        state.taskFilters = taskFilters
        state.hideUnavailableRoutines = hideUnavailableRoutines
        if result.didResetHideUnavailableRoutines {
            appSettingsClient.setHideUnavailableRoutines(false)
        }
        if result.shouldPersistTemporaryViewState {
            persistTemporaryViewState(state)
        }
        return .none
    }

    private func applyTimelineFilterMutation(
        _ mutation: HomeTimelineFilterMutation,
        state: inout State
    ) -> Effect<Action> {
        HomeFilterEditor.apply(mutation, timelineFilters: &state.timelineFilters)
        persistTemporaryViewState(state)
        return .none
    }

    private func applyStatsFilterMutation(
        _ mutation: HomeStatsFilterMutation,
        state: inout State
    ) -> Effect<Action> {
        HomeFilterEditor.apply(mutation, statsFilters: &state.statsFilters)
        persistTemporaryViewState(state)
        return .none
    }

    private func handleDeleteTasks(_ ids: [UUID], state: inout State) -> Effect<Action> {
        var routineTasks = state.routineTasks
        var doneStats = state.doneStats
        guard let update = HomeTaskDeletionSupport.prepareDeleteTasks(
            ids: ids,
            tasks: &routineTasks,
            doneStats: &doneStats
        ) else { return .none }
        state.routineTasks = routineTasks
        state.doneStats = doneStats
        var sprintBoardData = state.sprintBoardData
        HomeTaskDeletionSupport.removeSprintAssignments(
            targeting: update.uniqueIDs,
            from: &sprintBoardData
        )
        state.sprintBoardData = sprintBoardData
        refreshDisplays(&state)
        syncSelectedTaskDetailState(&state)

        let deleteEffect: Effect<Action> = HomeTaskDeletionSupport.deleteTasks(
            update,
            sprintBoardData: sprintBoardData,
            modelContext: { self.modelContext() },
            saveSprintBoardData: { sprintBoardData in
                try? await self.sprintBoardClient.save(sprintBoardData)
            },
            cancelNotification: { identifier in
                await self.notificationClient.cancel(identifier)
            }
        )
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
        guard let update = HomeTaskOrderingSupport.moveTaskInSection(
            taskID: taskID,
            sectionKey: sectionKey,
            orderedTaskIDs: orderedTaskIDs,
            direction: direction,
            tasks: &state.routineTasks
        ) else { return .none }
        refreshDisplays(&state)
        syncSelectedTaskDetailState(&state)

        return HomeTaskOrderingSupport.persistTaskOrder(
            update,
            failureMessage: "Failed to persist manual section order",
            modelContext: { self.modelContext() }
        )
    }

    private func setTaskOrderInSection(
        sectionKey: String,
        orderedTaskIDs: [UUID],
        state: inout State
    ) -> Effect<Action> {
        guard let update = HomeTaskOrderingSupport.setTaskOrderInSection(
            sectionKey: sectionKey,
            orderedTaskIDs: orderedTaskIDs,
            tasks: &state.routineTasks
        ) else { return .none }
        refreshDisplays(&state)
        syncSelectedTaskDetailState(&state)

        return HomeTaskOrderingSupport.persistTaskOrder(
            update,
            failureMessage: "Failed to persist board section order",
            modelContext: { self.modelContext() }
        )
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
        let routineTasks = state.routineTasks
        HomeDetailSelectionSupport.refreshSelectedTaskDetailState(
            selection: &state.selection,
            tasks: routineTasks,
            now: now,
            calendar: calendar,
            makeTaskDetailState: makeTaskDetailState(for:)
        )
    }

    private func refreshSelectedTaskDetailEffect(for state: State) -> Effect<Action> {
        guard state.selection.taskDetailState != nil else { return .none }
        return .send(.taskDetail(.onAppear))
    }

    private func syncSelectedTaskFromTaskDetail(_ state: inout State) {
        var selection = state.selection
        var routineTasks = state.routineTasks
        if HomeDetailSelectionSupport.syncSelectedTaskFromDetail(
            selection: &selection,
            tasks: &routineTasks
        ) {
            state.selection = selection
            state.routineTasks = routineTasks
            refreshDisplays(&state)
        }
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

    static func matchesSelectedTags(
        _ selectedTags: Set<String>,
        mode: RoutineTagMatchMode,
        in tags: [String]
    ) -> Bool {
        HomeDisplayFilterSupport.matchesSelectedTags(selectedTags, mode: mode, in: tags)
    }

    static func matchesExcludedTags(_ excludedTags: Set<String>, in tags: [String]) -> Bool {
        HomeDisplayFilterSupport.matchesExcludedTags(excludedTags, in: tags)
    }

    static func matchesExcludedTags(
        _ excludedTags: Set<String>,
        mode: RoutineTagMatchMode,
        in tags: [String]
    ) -> Bool {
        HomeDisplayFilterSupport.matchesExcludedTags(excludedTags, mode: mode, in: tags)
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
