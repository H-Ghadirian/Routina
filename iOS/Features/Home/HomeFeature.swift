import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct HomeFeature {
    typealias TaskListMode = HomeTaskListMode

    private enum TaskDetailCancelID: Hashable, Sendable {
        case task(UUID)
    }

    typealias SelectedTaskReloadGuard = HomeSelectedTaskReloadGuard

    typealias DoneStats = HomeDoneStats

    typealias MoveDirection = HomeTaskMoveDirection

    typealias RoutineDisplay = HomeRoutineDisplay

    @ObservableState
    struct State: Equatable, HomeFeatureFilterMutationState, HomeFeatureTaskLoadState, HomeFeaturePostMutationRefreshState, HomeFeatureSelectionRoutingState, HomeFeatureAddRoutinePresentationState, HomeFeatureAddRoutineActionState, HomeFeaturePresentationRoutingState, HomeFeatureTaskListModeRoutingState, HomeFeatureTemporaryViewState, HomeFeatureLifecycleState, HomeFeatureTaskLifecycleCommandState {
        var routineTasks: [RoutineTask] = []
        var routinePlaces: [RoutinePlace] = []
        var routineGoals: [RoutineGoal] = []
        var timelineLogs: [RoutineLog] = []
        var routineDisplays: [RoutineDisplay] = []
        var awayRoutineDisplays: [RoutineDisplay] = []
        var archivedRoutineDisplays: [RoutineDisplay] = []
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
            showArchivedTasks: Bool = true,
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
                showArchivedTasks: showArchivedTasks,
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

        var showArchivedTasks: Bool {
            get { taskFilters.showArchivedTasks }
            set { taskFilters.showArchivedTasks = newValue }
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
    }

    enum Action: Equatable {
        case onAppear
        case manualRefreshRequested
        case tasksLoadedSuccessfully([RoutineTask], [RoutinePlace], [RoutineGoal], [RoutineLog], DoneStats)
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
        case notTodayTask(UUID)
        case pauseTask(UUID)
        case resumeTask(UUID)
        case pinTask(UUID)
        case unpinTask(UUID)
        case moveTaskInSection(taskID: UUID, sectionKey: String, orderedTaskIDs: [UUID], direction: MoveDirection)

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
        case showArchivedTasksChanged(Bool)
        case isFilterSheetPresentedChanged(Bool)
        case clearOptionalFilters
        case applyFastTagFilter(String)

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
            saveSprintBoardData: { _ in },
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
            refreshTaskDetailAction: { .taskDetail(.onAppear) }
        )
    }

    private func taskDetailActionRouter() -> HomeFeatureTaskDetailActionRouter<State, Action> {
        HomeFeatureTaskDetailActionRouter(
            clearTaskSelection: { state in
                selectionRouter().clearTaskSelection(&state)
            },
            updatePendingChecklistReloadGuard: { itemID, state in
                selectionRouter().updatePendingChecklistReloadGuard(for: itemID, state: &state)
            },
            updatePendingChecklistUndoReloadGuard: { state in
                selectionRouter().updatePendingChecklistUndoReloadGuard(&state)
            },
            syncSelectedTaskFromTaskDetail: { state in
                selectionRouter().syncSelectedTaskFromTaskDetail(&state)
            },
            openLinkedTask: { taskID, state in
                selectionRouter().openLinkedTask(taskID, state: &state)
            },
            openLinkedTaskSheet: { state in
                addRoutinePresentationRouter().openLinkedTaskSheet(state: &state)
            }
        )
    }

    private func addRoutinePresentationRouter() -> HomeFeatureAddRoutinePresentationRouter<State> {
        HomeFeatureAddRoutinePresentationRouter(
            tagCounterDisplayMode: { appSettingsClient.tagCounterDisplayMode() },
            relatedTagRules: { appSettingsClient.relatedTagRules() }
        )
    }

    private func addRoutineActionHandler() -> HomeFeatureAddRoutineActionHandler<State, Action> {
        HomeFeatureAddRoutineActionHandler(
            referenceDate: now,
            calendar: calendar,
            dismissSheet: { state in
                addRoutinePresentationRouter().dismissSheet(state: &state)
            },
            modelContext: { self.modelContext() },
            scheduleAnchor: { self.now },
            scheduleNotification: { payload in
                await self.notificationClient.schedule(payload)
            },
            savedAction: { .routineSavedSuccessfully($0) },
            failedAction: { .routineSaveFailed },
            finishMutation: { effect, state in
                postMutationRefresher().finishMutation(effect, state: &state)
            },
            loadTasksEffect: { loadTasksEffect() }
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
            }
        )
    }

    private func taskLifecycleCommandRouter() -> HomeFeatureTaskLifecycleCommandRouter<State, Action> {
        HomeFeatureTaskLifecycleCommandRouter(
            markDone: { id, tasks, doneStats in
                taskLifecycleCoordinator().markTaskDone(
                    taskID: id,
                    tasks: &tasks,
                    doneStats: &doneStats
                )
            },
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

    private func lifecycleActionHandler() -> HomeFeatureLifecycleActionHandler<State, Action> {
        HomeFeatureLifecycleActionHandler(
            temporaryViewState: { appSettingsClient.temporaryViewState() },
            applyTemporaryViewState: { persistedState, state in
                applyTemporaryViewState(persistedState, to: &state)
            },
            tagColors: { appSettingsClient.tagColors() },
            refreshDisplays: { state in
                refreshDisplays(&state)
            },
            setHideUnavailableRoutines: { isHidden in
                appSettingsClient.setHideUnavailableRoutines(isHidden)
            },
            persistTemporaryViewState: { state in
                persistTemporaryViewState(state)
            },
            loadOnAppearEffect: { _ in
                .concatenate(
                    loadTasksEffect(),
                    .run { @MainActor send in
                        let snapshot = await self.locationClient.snapshot(false)
                        send(.locationSnapshotUpdated(snapshot))
                    }
                )
            },
            manualRefreshEffect: {
                HomeFeatureLifecycleEffectSupport.manualRefreshEffect(
                    modelContext: { self.modelContext() },
                    pullLatestIntoLocalStore: { try await self.cloudSyncClient.pullLatestIntoLocalStore($0) },
                    sleepBeforeSecondRefresh: { try await self.clock.sleep(for: .seconds(2)) },
                    onAppearAction: { .onAppear }
                )
            }
        )
    }

    var body: some ReducerOf<Self> {
        CombineReducers {
            Reduce { state, action in
                reduceTaskDetail(into: &state, action: action)
            }
            Reduce { state, action in
                switch action {
            case .onAppear:
                return lifecycleActionHandler().onAppear(state: &state)

            case .manualRefreshRequested:
                return lifecycleActionHandler().manualRefreshRequested()

            case let .tasksLoadedSuccessfully(tasks, places, goals, logs, doneStats):
                return taskLoadHandler().applyLoadedTasks(
                    tasks: tasks,
                    places: places,
                    goals: goals,
                    logs: logs,
                    doneStats: doneStats,
                    state: &state
                )

            case .tasksLoadFailed:
                return lifecycleActionHandler().tasksLoadFailed()

            case let .locationSnapshotUpdated(snapshot):
                return lifecycleActionHandler().locationSnapshotUpdated(snapshot, state: &state)

            case let .hideUnavailableRoutinesChanged(isHidden):
                return lifecycleActionHandler().hideUnavailableRoutinesChanged(isHidden, state: &state)

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

            case let .showArchivedTasksChanged(showArchivedTasks):
                return filterMutationHandler().applyTaskFilterMutation(.showArchivedTasks(showArchivedTasks), state: &state)

            case let .isFilterSheetPresentedChanged(isPresented):
                return filterMutationHandler().applyTaskFilterMutation(.isFilterSheetPresented(isPresented), state: &state)

            case .clearOptionalFilters:
                return filterMutationHandler().applyTaskFilterMutation(.clearOptionalFilters, state: &state)

            case let .applyFastTagFilter(tag):
                guard let cleanedTag = RoutineTag.cleaned(tag) else { return .none }
                state.taskFilters.setSelectedTags([cleanedTag])
                state.taskFilters.includeTagMatchMode = .all
                state.taskFilters.excludedTags = []
                state.taskFilters.excludeTagMatchMode = .any
                state.taskFilters.advancedQuery = ""
                state.taskFilters.selectedManualPlaceFilterID = nil
                state.taskFilters.selectedImportanceUrgencyFilter = nil
                state.taskFilters.selectedTodoStateFilter = nil
                state.taskFilters.selectedPressureFilter = nil
                if state.hideUnavailableRoutines {
                    state.hideUnavailableRoutines = false
                    appSettingsClient.setHideUnavailableRoutines(false)
                }
                state.taskFilters.isFilterSheetPresented = false
                state.presentation.isMacFilterDetailPresented = false
                persistTemporaryViewState(state)
                return .none

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

            case .deleteTasksConfirmed:
                let ids = presentationRouter().consumePendingDeleteTaskIDs(state: &state)
                return handleDeleteTasks(ids, state: &state)

            case let .deleteTasks(ids):
                return handleDeleteTasks(ids, state: &state)

            case let .markTaskDone(id):
                return taskLifecycleCommandRouter().markTaskDone(id, state: &state)

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

            case .addRoutineSheet(.delegate(.didCancel)):
                return addRoutineActionHandler().cancel(state: &state)

            case let .addRoutineSheet(.delegate(.didSave(request))):
                return addRoutineActionHandler().save(request)

            case let .routineSavedSuccessfully(task):
                return addRoutineActionHandler().finishSave(task, state: &state)

            case .routineSaveFailed:
                return addRoutineActionHandler().failSave()

            case let .taskDetail(action):
                return taskDetailActionRouter().handle(action, state: &state) ?? .none

            case .addRoutineSheet:
                return .none
                }
            }
            Reduce { state, _ in
                cancelStaleTaskDetailEffects(state: &state)
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
    }

    private func reduceTaskDetail(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        guard case let .taskDetail(taskDetailAction) = action,
              let taskDetailID = state.taskDetailState?.task.id else {
            return .none
        }

        state.selection.taskDetailEffectTaskID = taskDetailID
        return TaskDetailFeature()
            .reduce(into: &state.taskDetailState!, action: taskDetailAction)
            .map(Action.taskDetail)
            .cancellable(id: TaskDetailCancelID.task(taskDetailID))
    }

    private func cancelStaleTaskDetailEffects(state: inout State) -> Effect<Action> {
        let currentTaskID = state.taskDetailState?.task.id
        guard state.selection.taskDetailEffectTaskID != currentTaskID else { return .none }

        let previousTaskID = state.selection.taskDetailEffectTaskID
        state.selection.taskDetailEffectTaskID = currentTaskID
        guard let previousTaskID else { return .none }
        return .cancel(id: TaskDetailCancelID.task(previousTaskID))
    }

    private func handleDeleteTasks(_ ids: [UUID], state: inout State) -> Effect<Action> {
        var routineTasks = state.routineTasks
        var doneStats = state.doneStats
        var sprintBoardData: SprintBoardData?
        guard let deleteEffect = taskDeletionCoordinator().deleteTasks(
            ids: ids,
            tasks: &routineTasks,
            doneStats: &doneStats,
            sprintBoardData: &sprintBoardData
        ) else { return .none }
        state.routineTasks = routineTasks
        state.doneStats = doneStats
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

    private func loadTasksEffect() -> Effect<Action> {
        taskLoadEffectFactory().loadTasksEffect()
    }

    private func applyTemporaryViewState(_ persistedState: TemporaryViewState?, to state: inout State) {
        _ = HomeFeatureTemporaryViewStateSupport.applyBase(
            persistedState,
            to: &state,
            defaultHideUnavailableRoutines: appSettingsClient.hideUnavailableRoutines()
        )
    }

    private func persistTemporaryViewState(_ state: State) {
        appSettingsClient.setTemporaryViewState(
            HomeFeatureTemporaryViewStateSupport.makeTemporaryViewState(
                from: state,
                existing: appSettingsClient.temporaryViewState(),
                macSidebarModeRawValue: nil,
                macSelectedSettingsSectionRawValue: nil
            )
        )
    }

}

extension HomeFeature {
    @MainActor
    static func detailLogs(taskID: UUID, context: ModelContext) -> [RoutineLog] {
        HomeTaskSupport.detailLogs(taskID: taskID, context: context)
    }

    static func availableTags(from routineDisplays: [RoutineDisplay]) -> [String] {
        HomeRoutineDisplayQuerySupport.availableTags(from: routineDisplays)
    }

    static func tagSummaries(from routineDisplays: [RoutineDisplay]) -> [RoutineTagSummary] {
        HomeRoutineDisplayQuerySupport.tagSummaries(from: routineDisplays)
    }

    static func matchesSelectedTag(_ selectedTag: String?, in tags: [String]) -> Bool {
        HomeRoutineDisplayQuerySupport.matchesSelectedTag(selectedTag, in: tags)
    }

    static func matchesSelectedTags(
        _ selectedTags: Set<String>,
        mode: RoutineTagMatchMode,
        in tags: [String]
    ) -> Bool {
        HomeRoutineDisplayQuerySupport.matchesSelectedTags(selectedTags, mode: mode, in: tags)
    }

    static func matchesExcludedTags(_ excludedTags: Set<String>, in tags: [String]) -> Bool {
        HomeRoutineDisplayQuerySupport.matchesExcludedTags(excludedTags, in: tags)
    }

    static func matchesExcludedTags(
        _ excludedTags: Set<String>,
        mode: RoutineTagMatchMode,
        in tags: [String]
    ) -> Bool {
        HomeRoutineDisplayQuerySupport.matchesExcludedTags(excludedTags, mode: mode, in: tags)
    }

    static func matchesImportanceUrgencyFilter(
        _ selectedFilter: ImportanceUrgencyFilterCell?,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency
    ) -> Bool {
        HomeRoutineDisplayQuerySupport.matchesImportanceUrgencyFilter(
            selectedFilter,
            importance: importance,
            urgency: urgency
        )
    }

    static func matchesTodoStateFilter(_ filter: TodoState?, task: RoutineDisplay) -> Bool {
        HomeRoutineDisplayQuerySupport.matchesTodoStateFilter(filter, task: task)
    }
}
