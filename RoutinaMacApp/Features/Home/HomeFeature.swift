import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct HomeFeature {
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

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.modelContext) var modelContext
    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now
    @Dependency(\.locationClient) var locationClient
    @Dependency(\.cloudSyncClient) var cloudSyncClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.appSettingsClient) var appSettingsClient
    @Dependency(\.creationDraftClient) var creationDraftClient
    @Dependency(\.sprintBoardClient) var sprintBoardClient

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
                    state.isLoading = true
                    state.manualRefreshErrorMessage = nil
                    return lifecycleActionHandler().manualRefreshRequested()

                case let .manualRefreshFailed(message):
                    state.manualRefreshErrorMessage = message
                    return .none

                case .manualRefreshErrorDismissed:
                    state.manualRefreshErrorMessage = nil
                    return .none

                case let .statusComposerSaveRequested(rawText):
                    guard let text = RoutineNote.cleanedText(rawText) else { return .none }
                    state.statusComposerErrorMessage = nil
                    let createdAt = now
                    return .run { @MainActor send in
                        let context = modelContext()
                        let note = RoutineNote(
                            body: text,
                            tags: ["Status"],
                            createdAt: createdAt,
                            updatedAt: createdAt
                        )
                        context.insert(note)
                        do {
                            try context.save()
                            send(.statusComposerSaveSucceeded)
                        } catch {
                            context.delete(note)
                            send(.statusComposerSaveFailed)
                        }
                    }

                case .statusComposerSaveSucceeded:
                    state.statusComposerSaveCount += 1
                    state.statusComposerErrorMessage = nil
                    return .none

                case .statusComposerSaveFailed:
                    state.statusComposerErrorMessage = "Status was not saved."
                    return .none

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
                    return applySprintBoardLoaded(sprintBoardData, state: &state)

                case let .sprintBoardLoadedFromStorage(sprintBoardData, revision):
                    guard revision == state.board.sprintBoardRevision else {
                        return .none
                    }
                    return applySprintBoardLoaded(sprintBoardData, state: &state)

                case .tasksLoadFailed:
                    state.isLoading = false
                    state.hasLoadedTaskSnapshot = true
                    return lifecycleActionHandler().tasksLoadFailed()

                case let .locationSnapshotUpdated(snapshot):
                    return .merge(
                        lifecycleActionHandler().locationSnapshotUpdated(snapshot, state: &state),
                        automaticPlaceCheckInEffect(for: snapshot)
                    )

                case let .hideUnavailableRoutinesChanged(isHidden):
                    return lifecycleActionHandler().hideUnavailableRoutinesChanged(isHidden, state: &state)

                case let .setSelectedTask(taskID):
                    return selectionRouter().setSelectedTask(taskID, state: &state)

                case let .setAddRoutineSheet(isPresented):
                    addRoutinePresentationRouter().setSheet(isPresented, state: &state)
                    return .none

                case let .openAddTaskSheet(seedName):
                    state.navigation.enterAddTask()
                    state.macSidebarSelection = nil
                    addRoutinePresentationRouter().setSheet(
                        true,
                        state: &state,
                        seedName: seedName
                    )
                    persistTemporaryViewState(state)
                    return .none

                case let .openAddTaskInCustomSection(sectionID):
                    state.navigation.enterAddTask()
                    state.macSidebarSelection = nil
                    addRoutinePresentationRouter().setSheet(
                        true,
                        state: &state,
                        customTaskSectionID: sectionID
                    )
                    persistTemporaryViewState(state)
                    return .none

                case let .openAddTaskInCustomSectionWithName(sectionID, seedName):
                    state.navigation.enterAddTask()
                    state.macSidebarSelection = nil
                    addRoutinePresentationRouter().setSheet(
                        true,
                        state: &state,
                        seedName: seedName,
                        customTaskSectionID: sectionID
                    )
                    persistTemporaryViewState(state)
                    return .none

                case .dismissTaskCreationConfirmation:
                    state.taskCreationConfirmation = nil
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

                case let .taskListModeFilterChanged(mode):
                    taskListModeRouter().changeMode(mode, state: &state, closesFilterDetail: false)
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

                case let .taskDetailTagFilterTapped(tag):
                    guard let cleanedTag = RoutineTag.cleaned(tag) else { return .none }
                    state.macSidebarMode = .routines
                    state.macSidebarSelection = state.selectedTaskID.map(MacSidebarSelection.task)
                    state.isMacFilterDetailPresented = false
                    state.excludedTags = state.excludedTags.filter {
                        !RoutineTag.contains($0, in: [cleanedTag])
                    }
                    return filterMutationHandler().applyTaskFilterMutation(.selectedTags([cleanedTag]), state: &state)

                case let .includeTagMatchModeChanged(mode):
                    return filterMutationHandler().applyTaskFilterMutation(.includeTagMatchMode(mode), state: &state)

                case let .selectedFlagsChanged(flags):
                    return filterMutationHandler().applyTaskFilterMutation(.selectedFlags(flags), state: &state)

                case let .includeFlagMatchModeChanged(mode):
                    return filterMutationHandler().applyTaskFilterMutation(.includeFlagMatchMode(mode), state: &state)

                case let .excludedFlagsChanged(flags):
                    return filterMutationHandler().applyTaskFilterMutation(.excludedFlags(flags), state: &state)

                case let .excludeFlagMatchModeChanged(mode):
                    return filterMutationHandler().applyTaskFilterMutation(.excludeFlagMatchMode(mode), state: &state)

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

                case let .selectedThinkingNeededFilterChanged(filter):
                    return filterMutationHandler().applyTaskFilterMutation(.selectedThinkingNeededFilter(filter), state: &state)

                case let .selectedGoalFilterChanged(filter):
                    return filterMutationHandler().applyTaskFilterMutation(.selectedGoalFilter(filter), state: &state)

                case let .selectedMediaFilterChanged(filter):
                    return filterMutationHandler().applyTaskFilterMutation(.selectedMediaFilter(filter), state: &state)

                case let .selectedEstimationFilterChanged(filter):
                    return filterMutationHandler().applyTaskFilterMutation(.selectedEstimationFilter(filter), state: &state)

                case let .hideAssumedDoneTasksChanged(hideAssumedDoneTasks):
                    let effect = filterMutationHandler().applyTaskFilterMutation(
                        .hideAssumedDoneTasks(hideAssumedDoneTasks),
                        state: &state
                    )
                    refreshDisplays(&state)
                    return effect

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

                case .clearTaskListAndSharedFilters:
                    return filterMutationHandler().clearTaskListAndSharedFilters(state: &state)

                case .clearTimelineAndSharedFilters:
                    return filterMutationHandler().clearTimelineAndSharedFilters(state: &state)

                // MARK: - Timeline filter actions

                case let .selectedTimelineRangeChanged(range):
                    return filterMutationHandler().applyTimelineFilterMutation(.selectedRange(range), state: &state)

                case let .selectedTimelineFilterTypeChanged(filterType):
                    return filterMutationHandler().applyTimelineFilterMutation(.selectedFilterType(filterType), state: &state)

                case let .selectedTimelineStatusFilterChanged(statusFilter):
                    return filterMutationHandler().applyTimelineFilterMutation(.selectedStatusFilter(statusFilter), state: &state)

                case let .selectedTimelineTagChanged(tag):
                    return filterMutationHandler().applyTimelineFilterMutation(.selectedTag(tag), state: &state)

                case let .selectedTimelineTagsChanged(tags):
                    return filterMutationHandler().applyTimelineFilterMutation(.selectedTags(tags), state: &state)

                case let .selectedTimelineIncludeTagMatchModeChanged(mode):
                    return filterMutationHandler().applyTimelineFilterMutation(.includeTagMatchMode(mode), state: &state)

                case let .selectedTimelineFlagsChanged(flags):
                    return filterMutationHandler().applyTimelineFilterMutation(.selectedFlags(flags), state: &state)

                case let .selectedTimelineIncludeFlagMatchModeChanged(mode):
                    return filterMutationHandler().applyTimelineFilterMutation(.includeFlagMatchMode(mode), state: &state)

                case let .selectedTimelineExcludedTagsChanged(tags):
                    return filterMutationHandler().applyTimelineFilterMutation(.selectedExcludedTags(tags), state: &state)

                case let .selectedTimelineExcludeTagMatchModeChanged(mode):
                    return filterMutationHandler().applyTimelineFilterMutation(.excludeTagMatchMode(mode), state: &state)

                case let .selectedTimelineImportanceUrgencyFilterChanged(filter):
                    return filterMutationHandler().applyTimelineFilterMutation(.selectedImportanceUrgencyFilter(filter), state: &state)

                case let .selectedTimelinePressureFilterChanged(filter):
                    return filterMutationHandler().applyTimelineFilterMutation(.selectedPressureFilter(filter), state: &state)

                case let .selectedTimelineThinkingNeededFilterChanged(filter):
                    return filterMutationHandler().applyTimelineFilterMutation(.selectedThinkingNeededFilter(filter), state: &state)

                case let .selectedTimelineEstimationFilterChanged(filter):
                    return filterMutationHandler().applyTimelineFilterMutation(.selectedEstimationFilter(filter), state: &state)

                case let .selectedTimelineMediaFilterChanged(filter):
                    return filterMutationHandler().applyTimelineFilterMutation(.selectedMediaFilter(filter), state: &state)

                case let .fileAttachmentTaskIDsChanged(taskIDs):
                    guard state.fileAttachmentTaskIDs != taskIDs else { return .none }
                    state.fileAttachmentTaskIDs = taskIDs
                    refreshDisplays(&state)
                    return .none

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
                    return taskLifecycleCommandRouter().markTaskDone(id, state: &state)

                case let .markTaskMissed(id):
                    return taskLifecycleCommandRouter().markTaskMissed(id, state: &state)

                case let .confirmAssumedTaskDone(id):
                    return taskLifecycleCommandRouter().confirmAssumedTaskDone(id, state: &state)

                case let .markAssumedTaskMissed(id):
                    return taskLifecycleCommandRouter().markAssumedTaskMissed(id, state: &state)

                case let .markTaskCanceled(id):
                    return taskLifecycleCommandRouter().markTaskCanceled(id, state: &state)

                case let .moveTodoToState(id, newState):
                    return macBoardCommandRouter().moveTodoToState(id, newState, &state)

                case let .moveTodoOnBoard(taskID, targetState, orderedTaskIDs):
                    return macBoardCommandRouter().moveTodoOnBoard(taskID, targetState, orderedTaskIDs, &state)

                case let .selectedBoardScopeChanged(scope):
                    return macBoardCommandRouter().selectedBoardScopeChanged(scope, state: &state)

                case let .openTaskDeepLink(taskID):
                    return macNavigationRouter().openTaskDeepLink(
                        taskID,
                        state: &state,
                        setSelectedTask: { taskID, state in
                            selectionRouter().setSelectedTask(taskID, state: &state)
                        }
                    )

                case let .openNoteDeepLink(noteID):
                    guard appSettingsClient.notesEnabled() else { return .none }
                    return macNavigationRouter().openNoteDeepLink(noteID, state: &state)

                case let .openEventDeepLink(eventID):
                    guard appSettingsClient.eventEmotionActionsEnabled() else { return .none }
                    return macNavigationRouter().openEventDeepLink(eventID, state: &state)

                case let .openSprintDeepLink(sprintID):
                    return macNavigationRouter().openSprintDeepLink(sprintID, state: &state)

                case let .openSleepDeepLink(sleepID):
                    return macNavigationRouter().openSleepDeepLink(sleepID, state: &state)

                case let .sleepPlannerDeepLinkHandled(sleepID):
                    guard state.pendingSleepPlannerSessionID == sleepID else { return .none }
                    state.pendingSleepPlannerSessionID = nil
                    return .none

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

                case let .setBacklogRoutingTags(backlogID, tags):
                    return handleSetBacklogRoutingTags(
                        backlogID: backlogID,
                        tags: tags,
                        state: &state
                    )

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

                case let .startSprintFocusTapped(sprintID):
                    return handleStartSprintFocus(sprintID, state: &state)

                case let .pauseSprintFocusTapped(sessionID):
                    return handlePauseSprintFocus(sessionID, state: &state)

                case let .resumeSprintFocusTapped(sessionID):
                    return handleResumeSprintFocus(sessionID, state: &state)

                case let .stopSprintFocusTapped(sessionID):
                    return handleStopSprintFocus(sessionID, state: &state)

                case let .abandonSprintFocusTapped(sessionID):
                    return handleAbandonSprintFocus(sessionID, state: &state)

                case let .reviewSprintFocusAllocationTapped(sessionID):
                    beginSprintFocusAllocationReview(sessionID: sessionID, state: &state)
                    return .none

                case let .deleteSprintFocusSessionTapped(sessionID):
                    return handleDeleteSprintFocusSession(sessionID, state: &state)

                case let .sprintFocusAllocationMinutesChanged(taskID, minutes):
                    updateSprintFocusAllocationDraft(taskID: taskID, minutes: minutes, state: &state)
                    return .none

                case .sprintFocusAllocationSaveTapped:
                    return handleSaveSprintFocusAllocations(state: &state)

                case .sprintFocusAllocationCancelTapped:
                    state.sprintFocusAllocationSessionID = nil
                    state.sprintFocusAllocationDrafts = []
                    return .none

                case let .pauseTask(id):
                    return taskLifecycleCommandRouter().pauseTask(id, state: &state)

                case let .resumeTask(id):
                    return taskLifecycleCommandRouter().resumeTask(id, state: &state)

                case let .pauseCustomTaskSectionTasks(taskIDs):
                    return pauseCustomTaskSectionTasks(taskIDs, state: &state)

                case let .resumeCustomTaskSectionTasks(taskIDs):
                    return resumeCustomTaskSectionTasks(taskIDs, state: &state)

                case let .notTodayTask(id):
                    return taskLifecycleCommandRouter().notTodayTask(id, state: &state)

                case let .pinTask(id):
                    return taskLifecycleCommandRouter().pinTask(id, state: &state)

                case let .planTask(id, plannedDate):
                    return taskLifecycleCommandRouter().planTask(id, plannedDate: plannedDate, state: &state)

                case let .moveTaskToCustomSection(taskID, sectionID):
                    return moveTaskToCustomSection(
                        taskID: taskID,
                        sectionID: sectionID,
                        state: &state
                    )

                case let .deleteCustomTaskSection(sectionID):
                    return deleteCustomTaskSection(sectionID: sectionID, state: &state)

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
                    return addRoutineActionHandler().cancel(state: &state)

                case let .addRoutineSheet(.delegate(.didSave(request))):
                    return addRoutineActionHandler().save(request)

                case let .routineSavedSuccessfully(task):
                    return finishSaveAndRouteNewTodoToBacklog(task, state: &state)

                case .routineSaveFailed:
                    return .merge(
                        addRoutineActionHandler().failSave(),
                        .send(.addRoutineSheet(.saveFailed))
                    )

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

    func loadTasksEffect(performingMaintenance: Bool = false) -> Effect<Action> {
        taskLoadEffectFactory().loadTasksEffect(performingMaintenance: performingMaintenance)
    }

    func syncSelectedTaskDetailState(_ state: inout State) {
        selectionRouter().refreshSelectedTaskDetailState(&state)
    }
}
