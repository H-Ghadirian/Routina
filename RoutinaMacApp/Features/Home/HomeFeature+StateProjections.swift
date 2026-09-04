import Foundation

extension HomeFeature.State {
    var selectedTaskID: UUID? {
        get { selection.selectedTaskID }
        set { selection.selectedTaskID = newValue }
    }

    var taskDetailState: TaskDetailFeature.State? {
        get { selection.taskDetailState }
        set { selection.taskDetailState = newValue }
    }

    var selectedTaskReloadGuard: HomeFeature.SelectedTaskReloadGuard? {
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

    var manualRefreshErrorMessage: String? {
        get { presentation.manualRefreshErrorMessage }
        set { presentation.manualRefreshErrorMessage = newValue }
    }

    var boardTodoDisplays: [HomeFeature.RoutineDisplay] {
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

    var selectedFlags: Set<String> {
        get { taskFilters.selectedFlags }
        set { taskFilters.selectedFlags = newValue }
    }

    var includeTagMatchMode: RoutineTagMatchMode {
        get { taskFilters.includeTagMatchMode }
        set { taskFilters.includeTagMatchMode = newValue }
    }

    var includeFlagMatchMode: RoutineTagMatchMode {
        get { taskFilters.includeFlagMatchMode }
        set { taskFilters.includeFlagMatchMode = newValue }
    }

    var excludedFlags: Set<String> {
        get { taskFilters.excludedFlags }
        set { taskFilters.excludedFlags = newValue }
    }

    var excludeFlagMatchMode: RoutineTagMatchMode {
        get { taskFilters.excludeFlagMatchMode }
        set { taskFilters.excludeFlagMatchMode = newValue }
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

    var selectedThinkingNeededFilter: RoutineTaskThinkingNeeded? {
        get { taskFilters.selectedThinkingNeededFilter }
        set { taskFilters.selectedThinkingNeededFilter = newValue }
    }

    var selectedGoalFilter: HomeTaskGoalFilter {
        get { taskFilters.selectedGoalFilter }
        set { taskFilters.selectedGoalFilter = newValue }
    }

    var selectedMediaFilter: TaskMediaFilter {
        get { taskFilters.selectedMediaFilter }
        set { taskFilters.selectedMediaFilter = newValue }
    }

    var selectedEstimationFilter: TaskEstimationFilter {
        get { taskFilters.selectedEstimationFilter }
        set { taskFilters.selectedEstimationFilter = newValue }
    }

    var hideAssumedDoneTasks: Bool {
        get { taskFilters.hideAssumedDoneTasks }
        set { taskFilters.hideAssumedDoneTasks = newValue }
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

    var selectedTimelineStatusFilter: TimelineStatusFilter {
        get { timelineFilters.selectedStatusFilter }
        set { timelineFilters.selectedStatusFilter = newValue }
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

    var selectedTimelineFlags: Set<String> {
        get { timelineFilters.selectedFlags }
        set { timelineFilters.selectedFlags = newValue }
    }

    var selectedTimelineIncludeFlagMatchMode: RoutineTagMatchMode {
        get { timelineFilters.includeFlagMatchMode }
        set { timelineFilters.includeFlagMatchMode = newValue }
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

    var selectedTimelinePressureFilter: RoutineTaskPressure? {
        get { timelineFilters.selectedPressureFilter }
        set { timelineFilters.selectedPressureFilter = newValue }
    }

    var selectedTimelineThinkingNeededFilter: RoutineTaskThinkingNeeded? {
        get { timelineFilters.selectedThinkingNeededFilter }
        set { timelineFilters.selectedThinkingNeededFilter = newValue }
    }

    var selectedTimelineEstimationFilter: TaskEstimationFilter {
        get { timelineFilters.selectedEstimationFilter }
        set { timelineFilters.selectedEstimationFilter = newValue }
    }

    var selectedTimelineMediaFilter: TaskMediaFilter {
        get { timelineFilters.selectedMediaFilter }
        set { timelineFilters.selectedMediaFilter = newValue }
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

    var macSidebarMode: HomeFeature.MacSidebarMode {
        get { navigation.sidebarMode }
        set { navigation.sidebarMode = newValue }
    }

    var macSidebarSelection: HomeFeature.MacSidebarSelection? {
        get { navigation.sidebarSelection }
        set { navigation.sidebarSelection = newValue }
    }

    var selectedSettingsSection: SettingsMacSection? {
        get { navigation.selectedSettingsSection }
        set { navigation.selectedSettingsSection = newValue }
    }

    var selectedBoardScope: HomeFeature.BoardScope {
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

    var sprintFocusAllocationSessionID: UUID? {
        get { board.sprintFocusAllocationSessionID }
        set { board.sprintFocusAllocationSessionID = newValue }
    }

    var sprintFocusAllocationDrafts: [SprintFocusAllocationDraft] {
        get { board.sprintFocusAllocationDrafts }
        set { board.sprintFocusAllocationDrafts = newValue }
    }
}
