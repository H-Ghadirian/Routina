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
            case .all: return "square.stack.3d.up"
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
    }

    @ObservableState
    struct State: Equatable {
        var routineTasks: [RoutineTask] = []
        var routinePlaces: [RoutinePlace] = []
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
        case tasksLoadedSuccessfully([RoutineTask], [RoutinePlace], [RoutineLog], DoneStats)
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

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                applyTemporaryViewState(appSettingsClient.temporaryViewState(), to: &state)
                state.tagColors = appSettingsClient.tagColors()
                return .concatenate(
                    loadTasksEffect(),
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
                state.tagColors = appSettingsClient.tagColors()
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
                    HomeAddRoutineSupport.availabilityRefreshEffect(
                        tasks: snapshot.tasks,
                        places: snapshot.places,
                        doneStats: snapshot.doneStats,
                        action: { .addRoutineSheet($0) }
                    )
                )

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
                   state.selection.selectedTaskID == taskID,
                   state.selection.taskDetailState?.task.id == taskID {
                    state.presentation.isMacFilterDetailPresented = false
                    return .none
                }
                state.selection.selectedTaskID = taskID
                if taskID != nil {
                    state.presentation.isMacFilterDetailPresented = false
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

            case let .advancedQueryChanged(query):
                return applyTaskFilterMutation(.advancedQuery(query), state: &state)

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

            case let .selectedPressureFilterChanged(filter):
                return applyTaskFilterMutation(.selectedPressureFilter(filter), state: &state)

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
                guard let effect = taskLifecycleCoordinator().markTaskDone(
                    taskID: id,
                    tasks: &routineTasks,
                    doneStats: &doneStats
                ) else {
                    return .none
                }
                state.routineTasks = routineTasks
                state.doneStats = doneStats
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)
                return effect

            case let .pauseTask(id):
                guard let effect = taskLifecycleCoordinator().pauseTask(
                    taskID: id,
                    tasks: &state.routineTasks
                ) else {
                    return .none
                }
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)
                return effect

            case let .resumeTask(id):
                guard let effect = taskLifecycleCoordinator().resumeTask(
                    taskID: id,
                    tasks: &state.routineTasks
                ) else {
                    return .none
                }
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)
                return effect

            case let .notTodayTask(id):
                guard let effect = taskLifecycleCoordinator().notTodayTask(
                    taskID: id,
                    tasks: &state.routineTasks
                ) else {
                    return .none
                }
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)
                return effect

            case let .pinTask(id):
                guard let effect = taskLifecycleCoordinator().pinTask(
                    taskID: id,
                    tasks: &state.routineTasks
                ) else {
                    return .none
                }
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)
                return effect

            case let .unpinTask(id):
                guard let effect = taskLifecycleCoordinator().unpinTask(
                    taskID: id,
                    tasks: &state.routineTasks
                ) else {
                    return .none
                }
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)
                return effect

            case let .moveTaskInSection(taskID, sectionKey, orderedTaskIDs, direction):
                return moveTaskInSection(
                    taskID: taskID,
                    sectionKey: sectionKey,
                    orderedTaskIDs: orderedTaskIDs,
                    direction: direction,
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
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)
                return effect

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
        var sprintBoardData: SprintBoardData?
        guard let deleteEffect = taskDeletionCoordinator().deleteTasks(
            ids: ids,
            tasks: &routineTasks,
            doneStats: &doneStats,
            sprintBoardData: &sprintBoardData
        ) else { return .none }
        state.routineTasks = routineTasks
        state.doneStats = doneStats
        refreshDisplays(&state)
        syncSelectedTaskDetailState(&state)

        guard state.presentation.addRoutineState != nil else { return deleteEffect }
        return .merge(
            deleteEffect,
            HomeAddRoutineSupport.availabilityRefreshEffect(
                tasks: state.routineTasks,
                places: state.routinePlaces,
                doneStats: state.doneStats,
                action: { .addRoutineSheet($0) }
            )
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

    private func taskDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineTask> {
        HomeTaskSupport.taskDescriptor(for: taskID)
    }

    func logsDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineLog> {
        HomeTaskSupport.logsDescriptor(for: taskID)
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

    private func syncSelectedTaskDetailState(_ state: inout State) {
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
                    macSidebarModeRawValue: nil,
                    macSelectedSettingsSectionRawValue: nil
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
