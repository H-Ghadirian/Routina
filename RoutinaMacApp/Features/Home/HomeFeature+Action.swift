import ComposableArchitecture
import Foundation

extension HomeFeature {
    @CasePathable
    enum Action: Equatable {
        case onAppear
        case manualRefreshRequested
        case manualRefreshFailed(String)
        case manualRefreshErrorDismissed
        case tasksLoadedSuccessfully([RoutineTask], [RoutinePlace], [RoutineGoal], [RoutineLog], DoneStats)
        case sprintBoardLoaded(SprintBoardData)
        case sprintBoardLoadedFromStorage(SprintBoardData, revision: Int)
        case tasksLoadFailed
        case locationSnapshotUpdated(LocationSnapshot)
        case hideUnavailableRoutinesChanged(Bool)
        case setSelectedTask(UUID?)

        case setAddRoutineSheet(Bool)
        case openAddTaskSheet(seedName: String?)
        case openAddTaskInCustomSection(UUID)
        case openAddTaskInCustomSectionWithName(UUID, String)
        case dismissTaskCreationConfirmation
        case deleteTasksTapped([UUID])
        case setDeleteConfirmation(Bool)
        case setMacFilterDetailPresented(Bool)
        case taskListModeChanged(TaskListMode)
        case taskListModeFilterChanged(TaskListMode)
        case deleteTasksConfirmed
        case deleteTasks([UUID])
        case markTaskDone(UUID)
        case markTaskMissed(UUID)
        case confirmAssumedTaskDone(UUID)
        case markAssumedTaskMissed(UUID)
        case markTaskCanceled(UUID)
        case moveTodoToState(UUID, TodoState)
        case moveTodoOnBoard(taskID: UUID, targetState: TodoState, orderedTaskIDs: [UUID])
        case selectedBoardScopeChanged(BoardScope)
        case openTaskDeepLink(UUID)
        case openNoteDeepLink(UUID)
        case openEventDeepLink(UUID)
        case openSprintDeepLink(UUID)
        case openSleepDeepLink(UUID)
        case sleepPlannerDeepLinkHandled(UUID)
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
        case setBacklogRoutingTags(backlogID: UUID, tags: [String])
        case renameSprintTapped(UUID)
        case renamingSprintTitleChanged(String)
        case renameSprintConfirmed
        case renameSprintCanceled
        case deleteSprintTapped(UUID)
        case deleteSprintConfirmed(UUID)
        case deleteSprintCanceled
        case startSprintFocusTapped(UUID)
        case pauseSprintFocusTapped(UUID)
        case resumeSprintFocusTapped(UUID)
        case stopSprintFocusTapped(UUID)
        case abandonSprintFocusTapped(UUID)
        case reviewSprintFocusAllocationTapped(UUID)
        case deleteSprintFocusSessionTapped(UUID)
        case sprintFocusAllocationMinutesChanged(taskID: UUID, minutes: Int)
        case sprintFocusAllocationSaveTapped
        case sprintFocusAllocationCancelTapped
        case notTodayTask(UUID)
        case pauseTask(UUID)
        case resumeTask(UUID)
        case pauseCustomTaskSectionTasks([UUID])
        case resumeCustomTaskSectionTasks([UUID])
        case pinTask(UUID)
        case planTask(UUID, Date?)
        case moveTaskToCustomSection(taskID: UUID, sectionID: UUID?)
        case deleteCustomTaskSection(sectionID: UUID)
        case unpinTask(UUID)
        case moveTaskInSection(taskID: UUID, sectionKey: String, orderedTaskIDs: [UUID], direction: MoveDirection)
        case setTaskOrderInSection(sectionKey: String, orderedTaskIDs: [UUID])

        // Filter actions
        case selectedFilterChanged(RoutineListFilter)
        case advancedQueryChanged(String)
        case selectedTagChanged(String?)
        case selectedTagsChanged(Set<String>)
        case taskDetailTagFilterTapped(String)
        case includeTagMatchModeChanged(RoutineTagMatchMode)
        case selectedFlagsChanged(Set<String>)
        case includeFlagMatchModeChanged(RoutineTagMatchMode)
        case excludedFlagsChanged(Set<String>)
        case excludeFlagMatchModeChanged(RoutineTagMatchMode)
        case excludedTagsChanged(Set<String>)
        case excludeTagMatchModeChanged(RoutineTagMatchMode)
        case selectedManualPlaceFilterIDChanged(UUID?)
        case selectedImportanceUrgencyFilterChanged(ImportanceUrgencyFilterCell?)
        case selectedTodoStateFilterChanged(TodoState?)
        case selectedPressureFilterChanged(RoutineTaskPressure?)
        case selectedThinkingNeededFilterChanged(RoutineTaskThinkingNeeded?)
        case selectedGoalFilterChanged(HomeTaskGoalFilter)
        case selectedMediaFilterChanged(TaskMediaFilter)
        case selectedEstimationFilterChanged(TaskEstimationFilter)
        case hideAssumedDoneTasksChanged(Bool)
        case taskListViewModeChanged(HomeTaskListViewMode)
        case taskListSortOrderChanged(HomeTaskListSortOrder)
        case createdDateFilterChanged(HomeTaskCreatedDateFilter)
        case showArchivedTasksChanged(Bool)
        case isFilterSheetPresentedChanged(Bool)
        case clearOptionalFilters
        case clearTaskListAndSharedFilters
        case clearTimelineAndSharedFilters

        // Timeline filter actions
        case selectedTimelineRangeChanged(TimelineRange)
        case selectedTimelineFilterTypeChanged(TimelineFilterType)
        case selectedTimelineStatusFilterChanged(TimelineStatusFilter)
        case selectedTimelineTagChanged(String?)
        case selectedTimelineTagsChanged(Set<String>)
        case selectedTimelineIncludeTagMatchModeChanged(RoutineTagMatchMode)
        case selectedTimelineFlagsChanged(Set<String>)
        case selectedTimelineIncludeFlagMatchModeChanged(RoutineTagMatchMode)
        case selectedTimelineExcludedTagsChanged(Set<String>)
        case selectedTimelineExcludeTagMatchModeChanged(RoutineTagMatchMode)
        case selectedTimelineImportanceUrgencyFilterChanged(ImportanceUrgencyFilterCell?)
        case selectedTimelinePressureFilterChanged(RoutineTaskPressure?)
        case selectedTimelineThinkingNeededFilterChanged(RoutineTaskThinkingNeeded?)
        case selectedTimelineEstimationFilterChanged(TaskEstimationFilter)
        case selectedTimelineMediaFilterChanged(TaskMediaFilter)
        case fileAttachmentTaskIDsChanged(Set<UUID>)

        // Stats filter actions
        case statsSelectedRangeChanged(DoneChartRange)
        case statsSelectedTagChanged(String?)
        case statsSelectedTagsChanged(Set<String>)
        case statsIncludeTagMatchModeChanged(RoutineTagMatchMode)

        // macOS navigation actions
        case macSidebarModeChanged(MacSidebarMode)
        case macSidebarSelectionChanged(MacSidebarSelection?)
        case selectedSettingsSectionChanged(SettingsMacSection?)

        case statusComposerSaveRequested(String)
        case statusComposerSaveSucceeded
        case statusComposerSaveFailed

        case addRoutineSheet(AddRoutineFeature.Action)
        case taskDetail(TaskDetailFeature.Action)
        case routineSavedSuccessfully(RoutineTask)
        case routineSaveFailed
    }
}
