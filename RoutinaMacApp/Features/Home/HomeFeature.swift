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
        var goalIDs: [UUID] = []
        var goalTitles: [String] = []
        var steps: [String]
        var interval: Int
        var recurrenceRule: RoutineRecurrenceRule
        var scheduleMode: RoutineScheduleMode
        var createdAt: Date?
        var isSoftIntervalRoutine: Bool
        var lastDone: Date?
        var canceledAt: Date?
        var dueDate: Date?
        var priority: RoutineTaskPriority
        var importance: RoutineTaskImportance
        var urgency: RoutineTaskUrgency
        var pressure: RoutineTaskPressure = .none
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
        var assignedBacklogID: UUID? = nil
        var assignedBacklogTitle: String? = nil
    }

    enum MacSidebarSelection: Hashable, Equatable {
        case task(UUID)
        case timelineEntry(UUID)
    }

    enum MacSidebarMode: String, CaseIterable, Identifiable, Equatable {
        case routines = "Routines"
        case board = "Board"
        case goals = "Goals"
        case timeline = "Timeline"
        case stats    = "Stats"
        case settings = "Settings"
        case addTask  = "Add Task"

        var id: Self { self }
    }

    enum BoardScope: Equatable, Sendable {
        case backlog
        case namedBacklog(UUID)
        case currentSprint
        case sprint(UUID)
    }

    @ObservableState
    struct State: Equatable, HomeFeatureFilterMutationState, HomeFeatureTaskLoadState, HomeFeaturePostMutationRefreshState, HomeFeatureSelectionRoutingState, HomeFeatureAddRoutinePresentationState, HomeFeaturePresentationRoutingState, HomeFeatureTaskListModeRoutingState, HomeFeatureTemporaryViewState {
        var routineTasks: [RoutineTask] = []
        var routinePlaces: [RoutinePlace] = []
        var routineGoals: [RoutineGoal] = []
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
        var tagColors: [String: String] = [:]

        init(
            routineTasks: [RoutineTask] = [],
            routinePlaces: [RoutinePlace] = [],
            routineGoals: [RoutineGoal] = [],
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
            selectedPressureFilter: RoutineTaskPressure? = nil,
            taskListViewMode: HomeTaskListViewMode = .all,
            taskListSortOrder: HomeTaskListSortOrder = .smart,
            createdDateFilter: HomeTaskCreatedDateFilter = .all,
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
            relatedTagRules: [RoutineRelatedTagRule] = [],
            tagColors: [String: String] = [:]
        ) {
            self.routineTasks = routineTasks
            self.routinePlaces = routinePlaces
            self.routineGoals = routineGoals
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
                selectedPressureFilter: selectedPressureFilter,
                taskListViewMode: taskListViewMode,
                taskListSortOrder: taskListSortOrder,
                createdDateFilter: createdDateFilter,
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
            self.tagColors = RoutineTagColors.sanitized(tagColors)
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

        var advancedQuery: String {
            get { taskFilters.advancedQuery }
            set { taskFilters.advancedQuery = newValue }
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

        var selectedPressureFilter: RoutineTaskPressure? {
            get { taskFilters.selectedPressureFilter }
            set { taskFilters.selectedPressureFilter = newValue }
        }

        var taskListViewMode: HomeTaskListViewMode {
            get { taskFilters.taskListViewMode }
            set { taskFilters.taskListViewMode = newValue }
        }

        var taskListSortOrder: HomeTaskListSortOrder {
            get { taskFilters.taskListSortOrder }
            set { taskFilters.taskListSortOrder = newValue }
        }

        var createdDateFilter: HomeTaskCreatedDateFilter {
            get { taskFilters.createdDateFilter }
            set { taskFilters.createdDateFilter = newValue }
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

        var creatingBacklogTitle: String? {
            get { board.creatingBacklogTitle }
            set { board.creatingBacklogTitle = newValue }
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
        case tasksLoadedSuccessfully([RoutineTask], [RoutinePlace], [RoutineGoal], [RoutineLog], DoneStats)
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
        case createBacklogTapped
        case createBacklogTitleChanged(String)
        case createBacklogConfirmed
        case createBacklogCanceled
        case createSprintTapped
        case createSprintTitleChanged(String)
        case createSprintConfirmed
        case createSprintCanceled
        case startSprintTapped(UUID)
        case finishSprintTapped(UUID)
        case assignTodoToBacklog(taskID: UUID, backlogID: UUID?)
        case assignTodosToBacklog(taskIDs: [UUID], backlogID: UUID?)
        case assignTodoToSprint(taskID: UUID, sprintID: UUID?)
        case assignTodosToSprint(taskIDs: [UUID], sprintID: UUID?)
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
        case advancedQueryChanged(String)
        case selectedTagChanged(String?)
        case selectedTagsChanged(Set<String>)
        case includeTagMatchModeChanged(RoutineTagMatchMode)
        case excludedTagsChanged(Set<String>)
        case excludeTagMatchModeChanged(RoutineTagMatchMode)
        case selectedManualPlaceFilterIDChanged(UUID?)
        case selectedImportanceUrgencyFilterChanged(ImportanceUrgencyFilterCell?)
        case selectedTodoStateFilterChanged(TodoState?)
        case selectedPressureFilterChanged(RoutineTaskPressure?)
        case taskListViewModeChanged(HomeTaskListViewMode)
        case taskListSortOrderChanged(HomeTaskListSortOrder)
        case createdDateFilterChanged(HomeTaskCreatedDateFilter)
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

    private func taskLifecycleCoordinator() -> HomeTaskLifecycleCoordinator<Action> {
        HomeTaskLifecycleCoordinator(
            referenceDate: { self.now },
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

    private func taskDeletionCoordinator() -> HomeTaskDeletionCoordinator<Action> {
        HomeTaskDeletionCoordinator(
            modelContext: { self.modelContext() },
            saveSprintBoardData: { sprintBoardData in
                try? await self.sprintBoardClient.save(sprintBoardData)
            },
            cancelNotification: { identifier in
                await self.notificationClient.cancel(identifier)
            }
        )
    }

    private func filterMutationHandler() -> HomeFeatureFilterMutationHandler<State, Action> {
        HomeFeatureFilterMutationHandler(
            setHideUnavailableRoutines: { isHidden in
                appSettingsClient.setHideUnavailableRoutines(isHidden)
            },
            persistTemporaryViewState: { state in
                persistTemporaryViewState(state)
            }
        )
    }

    private func taskLoadHandler() -> HomeFeatureTaskLoadHandler<State, Action> {
        HomeFeatureTaskLoadHandler(
            relatedTagRules: { appSettingsClient.relatedTagRules() },
            tagColors: { appSettingsClient.tagColors() },
            refreshDisplays: { state in refreshDisplays(&state) },
            syncSelectedTaskDetailState: { state in selectionRouter().refreshSelectedTaskDetailState(&state) },
            validateFilterState: { state in filterMutationHandler().validateFilterState(&state) },
            persistTemporaryViewState: { state in persistTemporaryViewState(state) },
            refreshSelectedTaskDetailEffect: { state in selectionRouter().refreshSelectedTaskDetailEffect(for: state) },
            addRoutineAction: { .addRoutineSheet($0) }
        )
    }

    private func taskLoadEffectFactory() -> HomeFeatureTaskLoadEffectFactory<Action, CancelID> {
        HomeFeatureTaskLoadEffectFactory(
            calendar: calendar,
            cancelID: CancelID.loadTasks,
            modelContext: { self.modelContext() },
            loadedAction: { .tasksLoadedSuccessfully($0, $1, $2, $3, $4) },
            failedAction: { .tasksLoadFailed }
        )
    }

    private func postMutationRefresher() -> HomeFeaturePostMutationRefresher<State, Action> {
        HomeFeaturePostMutationRefresher(
            refreshDisplays: { state in refreshDisplays(&state) },
            syncSelectedTaskDetailState: { state in selectionRouter().refreshSelectedTaskDetailState(&state) },
            addRoutineAction: { .addRoutineSheet($0) }
        )
    }

    private func selectionRouter() -> HomeFeatureSelectionRouter<State, Action> {
        HomeFeatureSelectionRouter(
            now: now,
            calendar: calendar,
            makeTaskDetailState: makeTaskDetailState(for:),
            refreshDisplays: { state in refreshDisplays(&state) },
            refreshTaskDetailAction: { .taskDetail(.onAppear) },
            synchronizePlatformSelection: { state, taskID in
                if state.macSidebarMode == .routines || state.macSidebarMode == .board {
                    state.macSidebarSelection = taskID.map(MacSidebarSelection.task)
                }
            }
        )
    }

    private func addRoutinePresentationRouter() -> HomeFeatureAddRoutinePresentationRouter<State> {
        HomeFeatureAddRoutinePresentationRouter(
            tagCounterDisplayMode: { appSettingsClient.tagCounterDisplayMode() },
            relatedTagRules: { appSettingsClient.relatedTagRules() }
        )
    }

    private func presentationRouter() -> HomeFeaturePresentationRouter<State> {
        HomeFeaturePresentationRouter()
    }

    private func taskListModeRouter() -> HomeFeatureTaskListModeRouter<State> {
        HomeFeatureTaskListModeRouter(
            setHideUnavailableRoutines: { isHidden in
                appSettingsClient.setHideUnavailableRoutines(isHidden)
            },
            persistTemporaryViewState: { state in
                persistTemporaryViewState(state)
            },
            synchronizePlatformSelectionAfterModeChange: { state in
                state.macSidebarSelection = nil
            }
        )
    }

    private func macNavigationRouter() -> HomeFeatureMacNavigationRouter {
        HomeFeatureMacNavigationRouter(
            setHideUnavailableRoutines: { isHidden in
                appSettingsClient.setHideUnavailableRoutines(isHidden)
            },
            persistTemporaryViewState: { state in
                persistTemporaryViewState(state)
            }
        )
    }

    private func macBoardCommandRouter() -> HomeFeatureMacBoardCommandRouter {
        HomeFeatureMacBoardCommandRouter(
            moveTodoToState: { id, newState, state in
                handleMoveTodoToState(id, newState: newState, state: &state)
            },
            moveTodoOnBoard: { taskID, targetState, orderedTaskIDs, state in
                handleMoveTodoOnBoard(
                    taskID: taskID,
                    targetState: targetState,
                    orderedTaskIDs: orderedTaskIDs,
                    state: &state
                )
            },
            createBacklog: { title, state in
                handleCreateBacklogConfirmed(title: title, state: &state)
            },
            createSprint: { title, state in
                handleCreateSprintConfirmed(title: title, state: &state)
            },
            startSprint: { sprintID, state in
                handleStartSprint(sprintID, state: &state)
            },
            finishSprint: { sprintID, state in
                handleFinishSprint(sprintID, state: &state)
            },
            assignTodoToBacklog: { taskID, backlogID, state in
                handleAssignTodoToBacklog(taskID: taskID, backlogID: backlogID, state: &state)
            },
            assignTodosToBacklog: { taskIDs, backlogID, state in
                handleAssignTodosToBacklog(taskIDs: taskIDs, backlogID: backlogID, state: &state)
            },
            assignTodoToSprint: { taskID, sprintID, state in
                handleAssignTodoToSprint(taskID: taskID, sprintID: sprintID, state: &state)
            },
            assignTodosToSprint: { taskIDs, sprintID, state in
                handleAssignTodosToSprint(taskIDs: taskIDs, sprintID: sprintID, state: &state)
            },
            renameSprint: { id, title, state in
                handleRenameSprint(id: id, title: title, state: &state)
            },
            deleteSprint: { id, state in
                handleDeleteSprint(id: id, state: &state)
            }
        )
    }

    private func taskLifecycleCommandRouter() -> HomeFeatureTaskLifecycleCommandRouter {
        HomeFeatureTaskLifecycleCommandRouter(
            pause: { id, tasks in
                taskLifecycleCoordinator().pauseTask(taskID: id, tasks: &tasks)
            },
            resume: { id, tasks in
                taskLifecycleCoordinator().resumeTask(taskID: id, tasks: &tasks)
            },
            notToday: { id, tasks in
                taskLifecycleCoordinator().notTodayTask(taskID: id, tasks: &tasks)
            },
            pin: { id, tasks in
                taskLifecycleCoordinator().pinTask(taskID: id, tasks: &tasks)
            },
            unpin: { id, tasks in
                taskLifecycleCoordinator().unpinTask(taskID: id, tasks: &tasks)
            },
            finishMutation: { effect, state in
                postMutationRefresher().finishMutation(effect, state: &state)
            }
        )
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                applyTemporaryViewState(appSettingsClient.temporaryViewState(), to: &state)
                state.tagColors = appSettingsClient.tagColors()
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

            case let .tasksLoadedSuccessfully(tasks, places, goals, logs, doneStats):
                return taskLoadHandler().applyLoadedTasks(
                    tasks: tasks,
                    places: places,
                    goals: goals,
                    logs: logs,
                    doneStats: doneStats,
                    state: &state
                )

            case let .sprintBoardLoaded(sprintBoardData):
                state.sprintBoardData = sprintBoardData
                if case .currentSprint = state.selectedBoardScope,
                   sprintBoardData.activeSprints.isEmpty {
                    state.selectedBoardScope = .backlog
                } else if case let .namedBacklog(backlogID) = state.selectedBoardScope,
                          !sprintBoardData.backlogs.contains(where: { $0.id == backlogID }) {
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
                return selectionRouter().setSelectedTask(taskID, state: &state)

            case let .setAddRoutineSheet(isPresented):
                addRoutinePresentationRouter().setSheet(isPresented, state: &state)
                return .none

            case let .deleteTasksTapped(ids):
                presentationRouter().requestDeleteTasks(ids, state: &state)
                return .none

            case let .setDeleteConfirmation(isPresented):
                presentationRouter().setDeleteConfirmation(isPresented, state: &state)
                return .none

            case let .taskListModeChanged(mode):
                taskListModeRouter().changeMode(mode, state: &state)
                return .none

            case let .setMacFilterDetailPresented(isPresented):
                presentationRouter().setFilterDetailPresented(isPresented, state: &state)
                return .none

            // MARK: - Filter actions

            case let .selectedFilterChanged(filter):
                return filterMutationHandler().applyTaskFilterMutation(.selectedFilter(filter), state: &state)

            case let .advancedQueryChanged(query):
                return filterMutationHandler().applyTaskFilterMutation(.advancedQuery(query), state: &state)

            case let .selectedTagChanged(tag):
                return filterMutationHandler().applyTaskFilterMutation(.selectedTag(tag), state: &state)

            case let .selectedTagsChanged(tags):
                return filterMutationHandler().applyTaskFilterMutation(.selectedTags(tags), state: &state)

            case let .includeTagMatchModeChanged(mode):
                return filterMutationHandler().applyTaskFilterMutation(.includeTagMatchMode(mode), state: &state)

            case let .excludedTagsChanged(tags):
                return filterMutationHandler().applyTaskFilterMutation(.excludedTags(tags), state: &state)

            case let .excludeTagMatchModeChanged(mode):
                return filterMutationHandler().applyTaskFilterMutation(.excludeTagMatchMode(mode), state: &state)

            case let .selectedManualPlaceFilterIDChanged(id):
                return filterMutationHandler().applyTaskFilterMutation(.selectedManualPlaceFilterID(id), state: &state)

            case let .selectedImportanceUrgencyFilterChanged(filter):
                return filterMutationHandler().applyTaskFilterMutation(.selectedImportanceUrgencyFilter(filter), state: &state)

            case let .selectedTodoStateFilterChanged(filter):
                return filterMutationHandler().applyTaskFilterMutation(.selectedTodoStateFilter(filter), state: &state)

            case let .selectedPressureFilterChanged(filter):
                return filterMutationHandler().applyTaskFilterMutation(.selectedPressureFilter(filter), state: &state)

            case let .taskListViewModeChanged(mode):
                return filterMutationHandler().applyTaskFilterMutation(.taskListViewMode(mode), state: &state)

            case let .taskListSortOrderChanged(order):
                return filterMutationHandler().applyTaskFilterMutation(.taskListSortOrder(order), state: &state)

            case let .createdDateFilterChanged(filter):
                return filterMutationHandler().applyTaskFilterMutation(.createdDateFilter(filter), state: &state)

            case let .isFilterSheetPresentedChanged(isPresented):
                return filterMutationHandler().applyTaskFilterMutation(.isFilterSheetPresented(isPresented), state: &state)

            case .clearOptionalFilters:
                return filterMutationHandler().applyTaskFilterMutation(.clearOptionalFilters, state: &state)

            // MARK: - Timeline filter actions

            case let .selectedTimelineRangeChanged(range):
                return filterMutationHandler().applyTimelineFilterMutation(.selectedRange(range), state: &state)

            case let .selectedTimelineFilterTypeChanged(filterType):
                return filterMutationHandler().applyTimelineFilterMutation(.selectedFilterType(filterType), state: &state)

            case let .selectedTimelineTagChanged(tag):
                return filterMutationHandler().applyTimelineFilterMutation(.selectedTag(tag), state: &state)

            case let .selectedTimelineTagsChanged(tags):
                return filterMutationHandler().applyTimelineFilterMutation(.selectedTags(tags), state: &state)

            case let .selectedTimelineIncludeTagMatchModeChanged(mode):
                return filterMutationHandler().applyTimelineFilterMutation(.includeTagMatchMode(mode), state: &state)

            case let .selectedTimelineExcludedTagsChanged(tags):
                return filterMutationHandler().applyTimelineFilterMutation(.selectedExcludedTags(tags), state: &state)

            case let .selectedTimelineExcludeTagMatchModeChanged(mode):
                return filterMutationHandler().applyTimelineFilterMutation(.excludeTagMatchMode(mode), state: &state)

            case let .selectedTimelineImportanceUrgencyFilterChanged(filter):
                return filterMutationHandler().applyTimelineFilterMutation(.selectedImportanceUrgencyFilter(filter), state: &state)

            // MARK: - Stats filter actions

            case let .statsSelectedRangeChanged(range):
                return filterMutationHandler().applyStatsFilterMutation(.selectedRange(range), state: &state)

            case let .statsSelectedTagChanged(tag):
                return filterMutationHandler().applyStatsFilterMutation(.selectedTag(tag), state: &state)

            case let .statsSelectedTagsChanged(tags):
                return filterMutationHandler().applyStatsFilterMutation(.selectedTags(tags), state: &state)

            case let .statsIncludeTagMatchModeChanged(mode):
                return filterMutationHandler().applyStatsFilterMutation(.includeTagMatchMode(mode), state: &state)

            // MARK: - macOS navigation actions

            case let .macSidebarModeChanged(mode):
                return macNavigationRouter().sidebarModeChanged(mode, state: &state)

            case let .macSidebarSelectionChanged(selection):
                return macNavigationRouter().sidebarSelectionChanged(selection, state: &state)

            case let .selectedSettingsSectionChanged(section):
                return macNavigationRouter().selectedSettingsSectionChanged(section, state: &state)

            case .deleteTasksConfirmed:
                let ids = presentationRouter().consumePendingDeleteTaskIDs(state: &state)
                return handleDeleteTasks(ids, state: &state)

            case let .deleteTasks(ids):
                return handleDeleteTasks(ids, state: &state)

            case let .markTaskDone(id):
                var routineTasks = state.routineTasks
                var doneStats = state.doneStats
                guard let effect = taskLifecycleCoordinator().markTaskDone(
                    taskID: id,
                    tasks: &routineTasks,
                    doneStats: &doneStats
                ) else {
                    return .none
                }
                state.routineTasks = routineTasks
                state.doneStats = doneStats
                return postMutationRefresher().finishMutation(effect, state: &state)

            case let .moveTodoToState(id, newState):
                return macBoardCommandRouter().moveTodoToState(id, newState, &state)

            case let .moveTodoOnBoard(taskID, targetState, orderedTaskIDs):
                return macBoardCommandRouter().moveTodoOnBoard(taskID, targetState, orderedTaskIDs, &state)

            case let .selectedBoardScopeChanged(scope):
                return macBoardCommandRouter().selectedBoardScopeChanged(scope, state: &state)

            case .createSprintTapped:
                return macBoardCommandRouter().createSprintTapped(state: &state)

            case .createBacklogTapped:
                return macBoardCommandRouter().createBacklogTapped(state: &state)

            case let .createBacklogTitleChanged(title):
                return macBoardCommandRouter().createBacklogTitleChanged(title, state: &state)

            case .createBacklogConfirmed:
                return macBoardCommandRouter().createBacklogConfirmed(state: &state)

            case .createBacklogCanceled:
                return macBoardCommandRouter().createBacklogCanceled(state: &state)

            case let .createSprintTitleChanged(title):
                return macBoardCommandRouter().createSprintTitleChanged(title, state: &state)

            case .createSprintConfirmed:
                return macBoardCommandRouter().createSprintConfirmed(state: &state)

            case .createSprintCanceled:
                return macBoardCommandRouter().createSprintCanceled(state: &state)

            case let .startSprintTapped(sprintID):
                return macBoardCommandRouter().startSprint(sprintID, &state)

            case let .finishSprintTapped(sprintID):
                return macBoardCommandRouter().finishSprint(sprintID, &state)

            case let .assignTodoToBacklog(taskID, backlogID):
                return macBoardCommandRouter().assignTodoToBacklog(taskID, backlogID, &state)

            case let .assignTodosToBacklog(taskIDs, backlogID):
                return macBoardCommandRouter().assignTodosToBacklog(taskIDs, backlogID, &state)

            case let .assignTodoToSprint(taskID, sprintID):
                return macBoardCommandRouter().assignTodoToSprint(taskID, sprintID, &state)

            case let .assignTodosToSprint(taskIDs, sprintID):
                return macBoardCommandRouter().assignTodosToSprint(taskIDs, sprintID, &state)

            case let .renameSprintTapped(id):
                return macBoardCommandRouter().renameSprintTapped(id, state: &state)

            case let .renamingSprintTitleChanged(title):
                return macBoardCommandRouter().renamingSprintTitleChanged(title, state: &state)

            case .renameSprintConfirmed:
                return macBoardCommandRouter().renameSprintConfirmed(state: &state)

            case .renameSprintCanceled:
                return macBoardCommandRouter().renameSprintCanceled(state: &state)

            case let .deleteSprintTapped(id):
                return macBoardCommandRouter().deleteSprintTapped(id, state: &state)

            case let .deleteSprintConfirmed(id):
                return macBoardCommandRouter().deleteSprint(id, &state)

            case .deleteSprintCanceled:
                return macBoardCommandRouter().deleteSprintCanceled(state: &state)

            case let .pauseTask(id):
                return taskLifecycleCommandRouter().pauseTask(id, state: &state)

            case let .resumeTask(id):
                return taskLifecycleCommandRouter().resumeTask(id, state: &state)

            case let .notTodayTask(id):
                return taskLifecycleCommandRouter().notTodayTask(id, state: &state)

            case let .pinTask(id):
                return taskLifecycleCommandRouter().pinTask(id, state: &state)

            case let .unpinTask(id):
                return taskLifecycleCommandRouter().unpinTask(id, state: &state)

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
                addRoutinePresentationRouter().dismissSheet(state: &state)
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
                var routineTasks = state.routineTasks
                var presentation = state.presentation
                let effect: Effect<Action> = HomeAddRoutineSupport.applySavedRoutine(
                    task,
                    referenceDate: now,
                    calendar: calendar,
                    tasks: &routineTasks,
                    presentation: &presentation,
                    scheduleNotification: { payload in
                        await self.notificationClient.schedule(payload)
                    }
                )
                state.routineTasks = routineTasks
                state.presentation = presentation
                return postMutationRefresher().finishMutation(
                    .merge(effect, loadTasksEffect()),
                    state: &state
                )

            case .routineSaveFailed:
                print("Failed to save routine.")
                return .none

            case .taskDetail(.routineDeleted):
                selectionRouter().clearTaskSelection(&state)
                return .none

            case let .taskDetail(.toggleChecklistItemCompletion(itemID)):
                selectionRouter().updatePendingChecklistReloadGuard(for: itemID, state: &state)
                return .none

            case let .taskDetail(.markChecklistItemCompleted(itemID)):
                selectionRouter().updatePendingChecklistReloadGuard(for: itemID, state: &state)
                return .none

            case .taskDetail(.undoSelectedDateCompletion):
                selectionRouter().updatePendingChecklistUndoReloadGuard(&state)
                return .none

            case .taskDetail(.logsLoaded):
                selectionRouter().syncSelectedTaskFromTaskDetail(&state)
                return .none

            case let .taskDetail(.openLinkedTask(taskID)):
                return selectionRouter().openLinkedTask(taskID, state: &state)

            case .taskDetail(.openAddLinkedTask):
                addRoutinePresentationRouter().openLinkedTaskSheet(state: &state)
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

    private func handleDeleteTasks(_ ids: [UUID], state: inout State) -> Effect<Action> {
        var routineTasks = state.routineTasks
        var doneStats = state.doneStats
        var sprintBoardData: SprintBoardData? = state.sprintBoardData
        guard let deleteEffect = taskDeletionCoordinator().deleteTasks(
            ids: ids,
            tasks: &routineTasks,
            doneStats: &doneStats,
            sprintBoardData: &sprintBoardData
        ) else { return .none }
        state.routineTasks = routineTasks
        state.doneStats = doneStats
        if let sprintBoardData {
            state.sprintBoardData = sprintBoardData
        }
        return postMutationRefresher().finishMutation(
            deleteEffect,
            state: &state,
            refreshAddRoutineAvailability: true
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
        return postMutationRefresher().finishMutation(
            HomeTaskOrderingSupport.persistTaskOrder(
                update,
                failureMessage: "Failed to persist manual section order",
                modelContext: { self.modelContext() }
            ),
            state: &state
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
        return postMutationRefresher().finishMutation(
            HomeTaskOrderingSupport.persistTaskOrder(
                update,
                failureMessage: "Failed to persist board section order",
                modelContext: { self.modelContext() }
            ),
            state: &state
        )
    }

    func taskDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineTask> {
        HomeTaskSupport.taskDescriptor(for: taskID)
    }

    func logsDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineLog> {
        HomeTaskSupport.logsDescriptor(for: taskID)
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
        taskLoadEffectFactory().loadTasksEffect()
    }

    func syncSelectedTaskDetailState(_ state: inout State) {
        selectionRouter().refreshSelectedTaskDetailState(&state)
    }

    private func applyTemporaryViewState(_ persistedState: TemporaryViewState?, to state: inout State) {
        let restoredState = HomeFeatureTemporaryViewStateSupport.applyBase(
            persistedState,
            to: &state,
            defaultHideUnavailableRoutines: appSettingsClient.hideUnavailableRoutines()
        )

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
                values: HomeFeatureTemporaryViewStateSupport.makeValues(
                    from: state,
                    macSidebarModeRawValue: state.macSidebarMode.rawValue,
                    macSelectedSettingsSectionRawValue: state.selectedSettingsSection?.rawValue
                )
            )
        )
    }

}

extension HomeFeature.RoutineDisplay: HomeTaskListDisplay, HomeTaskRowDisplay {}

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
