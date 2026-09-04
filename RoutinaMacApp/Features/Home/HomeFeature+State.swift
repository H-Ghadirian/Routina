import ComposableArchitecture
import Foundation

extension HomeFeature {
    @ObservableState
    struct State: Equatable {
        var routineTasks: [RoutineTask] = []
        var routinePlaces: [RoutinePlace] = []
        var routineGoals: [RoutineGoal] = []
        var timelineLogs: [RoutineLog] = []
        var fileAttachmentTaskIDs: Set<UUID> = []
        var routineDisplays: [RoutineDisplay] = []
        var awayRoutineDisplays: [RoutineDisplay] = []
        var archivedRoutineDisplays: [RoutineDisplay] = []
        var routineDisplaysRevision = 0
        var homeToolbarRoutineCount = 0
        var homeToolbarTodoCount = 0
        var board = HomeBoardState()
        var doneStats: DoneStats = DoneStats()
        var isLoading = false
        var hasLoadedTaskSnapshot = false
        var selection = HomeSelectionState()
        var presentation = HomePresentationState()
        var locationSnapshot = LocationSnapshot(
            authorizationStatus: .notDetermined,
            coordinate: nil,
            horizontalAccuracy: nil,
            timestamp: nil
        )
        var hideUnavailableRoutines: Bool = false
        var taskListMode: TaskListMode = .all
        var taskFilters = HomeTaskFiltersState()
        var timelineFilters = HomeTimelineFiltersState()
        var statsFilters = HomeStatsFiltersState()
        var navigation = HomeMacNavigationState()
        var pendingSleepPlannerSessionID: UUID?
        var relatedTagRules: [RoutineRelatedTagRule] = []
        var flagRules: [RoutineFlagRule] = []
        var flagFilterOptions: [HomeFlagFilterOption] = []
        var tagColors: [String: String] = [:]
        var statusComposerSaveCount = 0
        var statusComposerErrorMessage: String?
        var taskCreationConfirmation: TaskCreationConfirmation?

        init(
            routineTasks: [RoutineTask] = [],
            routinePlaces: [RoutinePlace] = [],
            routineGoals: [RoutineGoal] = [],
            timelineLogs: [RoutineLog] = [],
            fileAttachmentTaskIDs: Set<UUID> = [],
            routineDisplays: [RoutineDisplay] = [],
            awayRoutineDisplays: [RoutineDisplay] = [],
            archivedRoutineDisplays: [RoutineDisplay] = [],
            boardTodoDisplays: [RoutineDisplay] = [],
            sprintBoardData: SprintBoardData = SprintBoardData(),
            doneStats: DoneStats = DoneStats(),
            isLoading: Bool = false,
            hasLoadedTaskSnapshot: Bool = false,
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
            taskListMode: TaskListMode = .all,
            selectedFilter: RoutineListFilter = .all,
            selectedTag: String? = nil,
            selectedTags: Set<String> = [],
            includeTagMatchMode: RoutineTagMatchMode = .all,
            selectedFlags: Set<String> = [],
            includeFlagMatchMode: RoutineTagMatchMode = .all,
            excludedFlags: Set<String> = [],
            excludeFlagMatchMode: RoutineTagMatchMode = .any,
            excludedTags: Set<String> = [],
            excludeTagMatchMode: RoutineTagMatchMode = .any,
            selectedManualPlaceFilterID: UUID? = nil,
            selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
            selectedTodoStateFilter: TodoState? = nil,
            selectedPressureFilter: RoutineTaskPressure? = nil,
            selectedThinkingNeededFilter: RoutineTaskThinkingNeeded? = nil,
            selectedGoalFilter: HomeTaskGoalFilter = .all,
            selectedMediaFilter: TaskMediaFilter = .all,
            selectedEstimationFilter: TaskEstimationFilter = .all,
            hideAssumedDoneTasks: Bool = false,
            taskListViewMode: HomeTaskListViewMode = .all,
            taskListSortOrder: HomeTaskListSortOrder = .smart,
            createdDateFilter: HomeTaskCreatedDateFilter = .all,
            showArchivedTasks: Bool = true,
            tabFilterSnapshots: [String: TabFilterStateManager.Snapshot] = [:],
            isFilterSheetPresented: Bool = false,
            selectedTimelineRange: TimelineRange = .all,
            selectedTimelineFilterType: TimelineFilterType = .all,
            selectedTimelineStatusFilter: TimelineStatusFilter = .all,
            selectedTimelineTag: String? = nil,
            selectedTimelineTags: Set<String> = [],
            selectedTimelineIncludeTagMatchMode: RoutineTagMatchMode = .all,
            selectedTimelineFlags: Set<String> = [],
            selectedTimelineIncludeFlagMatchMode: RoutineTagMatchMode = .all,
            selectedTimelineExcludedTags: Set<String> = [],
            selectedTimelineExcludeTagMatchMode: RoutineTagMatchMode = .any,
            selectedTimelineImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
            selectedTimelinePressureFilter: RoutineTaskPressure? = nil,
            selectedTimelineThinkingNeededFilter: RoutineTaskThinkingNeeded? = nil,
            selectedTimelineEstimationFilter: TaskEstimationFilter = .all,
            selectedTimelineMediaFilter: TaskMediaFilter = .all,
            statsSelectedRange: DoneChartRange = .week,
            statsSelectedTag: String? = nil,
            statsSelectedTags: Set<String> = [],
            statsIncludeTagMatchMode: RoutineTagMatchMode = .all,
            macSidebarMode: MacSidebarMode = .routines,
            macSidebarSelection: MacSidebarSelection? = nil,
            selectedSettingsSection: SettingsMacSection? = .notifications,
            selectedBoardScope: BoardScope = .backlog,
            relatedTagRules: [RoutineRelatedTagRule] = [],
            flagRules: [RoutineFlagRule] = [],
            flagFilterOptions: [HomeFlagFilterOption] = [],
            tagColors: [String: String] = [:]
        ) {
            self.routineTasks = routineTasks
            self.routinePlaces = routinePlaces
            self.routineGoals = routineGoals
            self.timelineLogs = timelineLogs
            self.fileAttachmentTaskIDs = fileAttachmentTaskIDs
            self.routineDisplays = routineDisplays
            self.awayRoutineDisplays = awayRoutineDisplays
            self.archivedRoutineDisplays = archivedRoutineDisplays
            let toolbarDisplays = routineDisplays + awayRoutineDisplays + archivedRoutineDisplays
            self.homeToolbarRoutineCount = toolbarDisplays.lazy.filter { !$0.isOneOffTask }.count
            self.homeToolbarTodoCount =
                boardTodoDisplays.lazy.filter {
                    !$0.isCompletedOneOff && !$0.isCanceledOneOff
                }.count
            self.routineDisplaysRevision =
                routineDisplays.isEmpty
                    && awayRoutineDisplays.isEmpty
                    && archivedRoutineDisplays.isEmpty
                    && boardTodoDisplays.isEmpty
                ? 0
                : 1
            self.board = HomeBoardState(
                todoDisplays: boardTodoDisplays,
                sprintBoardData: sprintBoardData,
                selectedScope: selectedBoardScope
            )
            self.doneStats = doneStats
            self.isLoading = isLoading
            self.hasLoadedTaskSnapshot = hasLoadedTaskSnapshot
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
                selectedFlags: selectedFlags,
                includeFlagMatchMode: includeFlagMatchMode,
                excludedFlags: excludedFlags,
                excludeFlagMatchMode: excludeFlagMatchMode,
                excludedTags: excludedTags,
                excludeTagMatchMode: excludeTagMatchMode,
                selectedManualPlaceFilterID: selectedManualPlaceFilterID,
                selectedImportanceUrgencyFilter: selectedImportanceUrgencyFilter,
                selectedTodoStateFilter: selectedTodoStateFilter,
                selectedPressureFilter: selectedPressureFilter,
                selectedThinkingNeededFilter: selectedThinkingNeededFilter,
                selectedGoalFilter: selectedGoalFilter,
                selectedMediaFilter: selectedMediaFilter,
                selectedEstimationFilter: selectedEstimationFilter,
                hideAssumedDoneTasks: hideAssumedDoneTasks,
                taskListViewMode: taskListViewMode,
                taskListSortOrder: taskListSortOrder,
                createdDateFilter: createdDateFilter,
                showArchivedTasks: showArchivedTasks,
                tabFilterSnapshots: tabFilterSnapshots,
                isFilterSheetPresented: isFilterSheetPresented
            )
            self.timelineFilters = HomeTimelineFiltersState(
                selectedRange: selectedTimelineRange,
                selectedFilterType: selectedTimelineFilterType.isStatusCase ? .all : selectedTimelineFilterType,
                selectedStatusFilter: selectedTimelineStatusFilter == .all
                    ? TimelineStatusFilter(legacyFilterType: selectedTimelineFilterType)
                    : selectedTimelineStatusFilter,
                selectedTag: selectedTimelineTag,
                selectedTags: selectedTimelineTags.isEmpty ? selectedTimelineTag.map { [$0] } ?? [] : selectedTimelineTags,
                includeTagMatchMode: selectedTimelineIncludeTagMatchMode,
                selectedFlags: selectedTimelineFlags,
                includeFlagMatchMode: selectedTimelineIncludeFlagMatchMode,
                selectedExcludedTags: selectedTimelineExcludedTags,
                excludeTagMatchMode: selectedTimelineExcludeTagMatchMode,
                selectedImportanceUrgencyFilter: selectedTimelineImportanceUrgencyFilter,
                selectedPressureFilter: selectedTimelinePressureFilter,
                selectedThinkingNeededFilter: selectedTimelineThinkingNeededFilter,
                selectedEstimationFilter: selectedTimelineEstimationFilter,
                selectedMediaFilter: selectedTimelineMediaFilter
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
            self.flagRules = RoutineFlagRules.sanitized(flagRules)
            self.flagFilterOptions = flagFilterOptions
            self.tagColors = RoutineTagColors.sanitized(tagColors)
        }

    }
}

extension HomeFeature.State: HomeFeatureFilterMutationState {}
extension HomeFeature.State: HomeFeatureTaskLoadState {}
extension HomeFeature.State: HomeFeaturePostMutationRefreshState {}
extension HomeFeature.State: HomeFeatureSelectionRoutingState {}
extension HomeFeature.State: HomeFeatureAddRoutinePresentationState {}
extension HomeFeature.State: HomeFeatureAddRoutineActionState {}
extension HomeFeature.State: HomeFeaturePresentationRoutingState {}
extension HomeFeature.State: HomeFeatureTaskListModeRoutingState {}
extension HomeFeature.State: HomeFeatureTemporaryViewState {}
extension HomeFeature.State: HomeFeatureLifecycleState {}
extension HomeFeature.State: HomeFeatureTaskLifecycleCommandState {}
