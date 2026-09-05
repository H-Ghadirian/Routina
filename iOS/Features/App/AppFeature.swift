import ComposableArchitecture
import Foundation

@Reducer
struct AppFeature {

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .home
        var hasRestoredTemporaryViewState = false
        var pendingDeepLinkedTaskID: UUID?
        var home = HomeFeature.State()
        var goals = GoalsFeature.State()
        var timeline = TimelineFeature.State()
        var stats = StatsFeature.State()
        var settings = SettingsFeature.State()
        var backlog = BacklogFeature.State()
        var taskRanking = TaskRankingFeature.State()
        var taskChoice = TaskChoiceFeature.State()
        var missingPressureData = MissingTaskDataFeature.State(field: .pressure)
        var missingThinkingNeededData = MissingTaskDataFeature.State(field: .thinkingNeeded)
        var missingEstimatedDurationData = MissingTaskDataFeature.State(field: .estimatedDuration)
        var missingImportanceData = MissingTaskMetadataFeature.State(field: .importance)
        var missingUrgencyData = MissingTaskMetadataFeature.State(field: .urgency)
    }

    @CasePathable
    enum Action: Equatable {
        case tabSelected(Tab)
        case homeFastFilterSelected(String)
        case home(HomeFeature.Action)
        case goals(GoalsFeature.Action)
        case timeline(TimelineFeature.Action)
        case stats(StatsFeature.Action)
        case settings(SettingsFeature.Action)
        case backlog(BacklogFeature.Action)
        case taskRanking(TaskRankingFeature.Action)
        case taskChoice(TaskChoiceFeature.Action)
        case missingPressureData(MissingTaskDataFeature.Action)
        case missingThinkingNeededData(MissingTaskDataFeature.Action)
        case missingEstimatedDurationData(MissingTaskDataFeature.Action)
        case missingImportanceData(MissingTaskMetadataFeature.Action)
        case missingUrgencyData(MissingTaskMetadataFeature.Action)
        case onAppear
        case cloudSettingsChanged
        case openDeepLink(RoutinaDeepLink)
    }

    @Dependency(\.appSettingsClient) var appSettingsClient

    var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Scope(state: \.goals, action: \.goals) {
            GoalsFeature()
        }
        Scope(state: \.timeline, action: \.timeline) {
            TimelineFeature()
        }
        Scope(state: \.stats, action: \.stats) {
            StatsFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Scope(state: \.backlog, action: \.backlog) {
            BacklogFeature()
        }
        Scope(state: \.taskRanking, action: \.taskRanking) {
            TaskRankingFeature()
        }
        Scope(state: \.taskChoice, action: \.taskChoice) {
            TaskChoiceFeature()
        }
        Scope(state: \.missingPressureData, action: \.missingPressureData) {
            MissingTaskDataFeature(field: .pressure)
        }
        Scope(state: \.missingThinkingNeededData, action: \.missingThinkingNeededData) {
            MissingTaskDataFeature(field: .thinkingNeeded)
        }
        Scope(state: \.missingEstimatedDurationData, action: \.missingEstimatedDurationData) {
            MissingTaskDataFeature(field: .estimatedDuration)
        }
        Scope(state: \.missingImportanceData, action: \.missingImportanceData) {
            MissingTaskMetadataFeature(field: .importance)
        }
        Scope(state: \.missingUrgencyData, action: \.missingUrgencyData) {
            MissingTaskMetadataFeature(field: .urgency)
        }
        Reduce { state, action in
            if let interaction = performanceInteraction(for: action) {
                RoutinaPerformanceProfiler.shared.recordInteraction(interaction)
            }

            switch action {
            case .tabSelected(let tab):
                state.selectedTab = tab
                persistTemporaryViewState(state)
                return .none
            case let .homeFastFilterSelected(tag):
                state.selectedTab = .home
                persistTemporaryViewState(state)
                return .send(.home(.applyFastTagFilter(tag)))
            case let .openDeepLink(deepLink):
                return handleDeepLink(deepLink, state: &state)
            case let .taskChoice(.delegate(.taskDetailsRequested(taskID))):
                return openTaskDetails(taskID, state: &state)
            case let .missingPressureData(.delegate(.taskDetailsRequested(taskID))),
                let .missingThinkingNeededData(.delegate(.taskDetailsRequested(taskID))),
                let .missingEstimatedDurationData(.delegate(.taskDetailsRequested(taskID))):
                return openTaskDetails(taskID, state: &state)
            case let .missingImportanceData(.delegate(.taskDetailsRequested(taskID))),
                let .missingUrgencyData(.delegate(.taskDetailsRequested(taskID))):
                return openTaskDetails(taskID, state: &state)
            case let .home(.tasksLoadedSuccessfully(tasks, _, _, _, _)):
                guard let taskID = state.pendingDeepLinkedTaskID,
                    tasks.contains(where: { $0.id == taskID })
                else {
                    return .none
                }
                state.pendingDeepLinkedTaskID = nil
                state.selectedTab = .home
                persistTemporaryViewState(state)
                return .send(.home(.setSelectedTask(taskID)))
            case .onAppear:
                guard !state.hasRestoredTemporaryViewState else { return .none }
                state.hasRestoredTemporaryViewState = true
                applyTemporaryViewState(appSettingsClient.temporaryViewState(), to: &state)
                return .none
            case .cloudSettingsChanged:
                let tagColors = appSettingsClient.tagColors()
                let relatedTagRules = appSettingsClient.relatedTagRules()
                let flagRules = appSettingsClient.flagRules()
                state.home.tagColors = tagColors
                state.home.flagRules = flagRules
                state.home.relatedTagRules = RoutineTagRelations.sanitized(
                    relatedTagRules + RoutineTagRelations.learnedRules(from: state.home.routineTasks.map(\.tags))
                )
                state.timeline.relatedTagRules = RoutineTagRelations.sanitized(
                    relatedTagRules + RoutineTagRelations.learnedRules(from: state.timeline.tasks.map(\.tags))
                )
                state.goals.tagColors = tagColors
                state.goals.availableTagSummaries = RoutineTagColors.applying(
                    tagColors,
                    to: state.goals.availableTagSummaries
                )
                state.goals.relatedTagRules = RoutineTagRelations.sanitized(
                    relatedTagRules + RoutineTagRelations.learnedRules(from: state.goals.goals.map(\.tags))
                )
                state.stats.tagColors = tagColors
                state.stats.relatedTagRules = RoutineTagRelations.sanitized(
                    relatedTagRules + RoutineTagRelations.learnedRules(from: state.stats.tasks.map(\.tags))
                )
                SettingsTagEditor.loadedTagColors(tagColors, state: &state.settings.tags)
                SettingsTagEditor.loadedRelatedTagRules(relatedTagRules, state: &state.settings.tags)
                SettingsFlagEditor.loadedRules(flagRules, state: &state.settings.flags)
                SettingsFlagEditor.loadedDefinedFlags(
                    appSettingsClient.definedFlags(),
                    state: &state.settings.flags
                )
                return .send(.timeline(.flagRulesChanged(flagRules)))
            case .settings(.resetTemporaryViewStateTapped):
                let timelineTasks = state.timeline.tasks
                let timelineLogs = state.timeline.logs
                let timelineEvents = state.timeline.events
                let timelineNotes = state.timeline.notes
                let timelineFocusSessions = state.timeline.focusSessions
                let timelineSprintFocusSessions = state.timeline.sprintFocusSessions
                let timelineFocusSessionEvents = state.timeline.focusSessionEvents
                let timelineBoardSprints = state.timeline.boardSprints
                let timelineAwaySessions = state.timeline.awaySessions
                let timelineFileAttachmentTaskIDs = state.timeline.fileAttachmentTaskIDs
                let timelineNoteAttachmentNoteIDs = state.timeline.noteAttachmentNoteIDs
                let statsTasks = state.stats.tasks
                let statsLogs = state.stats.logs
                let statsFocusSessions = state.stats.focusSessions
                let statsSprintFocusSessions = state.stats.sprintFocusSessions
                let statsFocusSessionEvents = state.stats.focusSessionEvents
                let statsBoardSprints = state.stats.boardSprints
                let statsSleepSessions = state.stats.sleepSessions
                let statsAwaySessions = state.stats.awaySessions
                let statsEmotionLogs = state.stats.emotionLogs
                let statsNotes = state.stats.notes
                let statsEvents = state.stats.events
                let statsNoteAttachmentNoteIDs = state.stats.noteAttachmentNoteIDs
                let statsGoals = state.stats.goals
                let statsPlaces = state.stats.places
                let statsPlaceCheckInSessions = state.stats.placeCheckInSessions
                resetTemporaryViewState(&state)
                persistTemporaryViewState(state)
                return .merge(
                    .send(
                        .timeline(
                            .setData(
                                tasks: timelineTasks,
                                logs: timelineLogs,
                                events: timelineEvents,
                                notes: timelineNotes,
                                focusSessions: timelineFocusSessions,
                                sprintFocusSessions: timelineSprintFocusSessions,
                                focusSessionEvents: timelineFocusSessionEvents,
                                boardSprints: timelineBoardSprints,
                                awaySessions: timelineAwaySessions,
                                fileAttachmentTaskIDs: timelineFileAttachmentTaskIDs,
                                noteAttachmentNoteIDs: timelineNoteAttachmentNoteIDs
                            ))),
                    .send(
                        .stats(
                            .setData(
                                tasks: statsTasks,
                                logs: statsLogs,
                                focusSessions: statsFocusSessions,
                                sprintFocusSessions: statsSprintFocusSessions,
                                focusSessionEvents: statsFocusSessionEvents,
                                boardSprints: statsBoardSprints,
                                sleepSessions: statsSleepSessions,
                                awaySessions: statsAwaySessions,
                                emotionLogs: statsEmotionLogs,
                                notes: statsNotes,
                                events: statsEvents,
                                noteAttachmentNoteIDs: statsNoteAttachmentNoteIDs,
                                goals: statsGoals,
                                places: statsPlaces,
                                placeCheckInSessions: statsPlaceCheckInSessions
                            )))
                )
            case .timeline(.selectedRangeChanged),
                .timeline(.filterTypeChanged),
                .timeline(.selectedTagChanged),
                .timeline(.selectedTagsChanged),
                .timeline(.includeTagMatchModeChanged),
                .timeline(.selectedImportanceUrgencyFilterChanged),
                .timeline(.mediaFilterChanged),
                .timeline(.excludedTagsChanged),
                .timeline(.excludeTagMatchModeChanged),
                .timeline(.selectedFlagsChanged),
                .timeline(.includeFlagMatchModeChanged),
                .timeline(.clearFilters),
                .stats(.selectedRangeChanged),
                .stats(.taskTypeFilterChanged),
                .stats(.selectedTagChanged),
                .stats(.selectedTagsChanged),
                .stats(.includeTagMatchModeChanged),
                .stats(.advancedQueryChanged),
                .stats(.selectedImportanceUrgencyFilterChanged),
                .stats(.excludedTagsChanged),
                .stats(.excludeTagMatchModeChanged),
                .stats(.selectedFlagsChanged),
                .stats(.includeFlagMatchModeChanged),
                .stats(.excludedFlagsChanged),
                .stats(.excludeFlagMatchModeChanged),
                .stats(.clearFilters):
                persistTemporaryViewState(state)
                return .none
            case .settings(.tagColorChanged):
                let tagColors = appSettingsClient.tagColors()
                state.home.tagColors = tagColors
                state.stats.tagColors = tagColors
                return .none
            case .settings(.addFlagRuleTapped),
                .settings(.removeFlagRuleTapped),
                .settings(.removeFlagTapped):
                let flagRules = RoutineFlagRules.sanitized(appSettingsClient.flagRules())
                state.home.flagRules = flagRules
                return .send(.timeline(.flagRulesChanged(flagRules)))
            default:
                return .none
            }
        }
    }

    private func performanceInteraction(
        for action: Action
    ) -> RoutinaPerformanceInteraction? {
        switch action {
        case let .tabSelected(tab):
            return RoutinaPerformanceInteraction.navigationTab(named: tab.rawValue)

        case .homeFastFilterSelected:
            return .homeFilterChanged

        case let .home(homeAction):
            return performanceInteraction(for: homeAction)

        case let .timeline(timelineAction):
            return performanceInteraction(for: timelineAction)

        case let .stats(statsAction):
            return performanceInteraction(for: statsAction)

        case .settings(.syncNowTapped):
            return .settingsSyncRequested
        case .settings(.exportRoutineDataTapped):
            return .settingsBackupExportRequested

        default:
            return nil
        }
    }

    private func performanceInteraction(
        for action: HomeFeature.Action
    ) -> RoutinaPerformanceInteraction? {
        switch action {
        case .manualRefreshRequested:
            return .manualRefreshRequested
        case .setSelectedTask(.some):
            return .taskDetailOpened
        case .setSelectedTask(.none):
            return .taskDetailClosed
        case .setAddRoutineSheet(true), .setSmartAddTaskSheet(true), .prepareAddRoutineDetails:
            return .taskComposerOpened
        case .setAddRoutineSheet(false), .setSmartAddTaskSheet(false):
            return .taskComposerClosed
        case .taskListModeChanged:
            return .taskListModeChanged
        case .isFilterSheetPresentedChanged(true):
            return .homeFilterOpened
        case .isFilterSheetPresentedChanged(false):
            return nil
        case .clearOptionalFilters:
            return .homeFilterCleared
        case .selectedFilterChanged,
            .advancedQueryChanged,
            .selectedTagChanged,
            .selectedTagsChanged,
            .includeTagMatchModeChanged,
            .selectedFlagsChanged,
            .includeFlagMatchModeChanged,
            .excludedTagsChanged,
            .excludeTagMatchModeChanged,
            .selectedManualPlaceFilterIDChanged,
            .selectedImportanceUrgencyFilterChanged,
            .selectedTodoStateFilterChanged,
            .selectedPressureFilterChanged,
            .selectedThinkingNeededFilterChanged,
            .selectedGoalFilterChanged,
            .selectedMediaFilterChanged,
            .selectedEstimationFilterChanged,
            .hideAssumedDoneTasksChanged,
            .taskListViewModeChanged,
            .taskListSortOrderChanged,
            .createdDateFilterChanged,
            .showArchivedTasksChanged:
            return .homeFilterChanged
        case .markTaskDone:
            return .taskMarkedDone
        case .markTaskMissed:
            return .taskMarkedMissed
        case .markTaskCanceled:
            return .taskMarkedCanceled
        case .pauseTask:
            return .taskPaused
        case .resumeTask:
            return .taskResumed
        case .planTask:
            return .taskPlanned
        default:
            return nil
        }
    }

    private func performanceInteraction(
        for action: TimelineFeature.Action
    ) -> RoutinaPerformanceInteraction? {
        switch action {
        case .setFilterSheet(true):
            return .timelineFilterOpened
        case .clearFilters:
            return .timelineFilterCleared
        case .selectedRangeChanged,
            .filterTypeChanged,
            .selectedTagChanged,
            .selectedTagsChanged,
            .includeTagMatchModeChanged,
            .excludedTagsChanged,
            .excludeTagMatchModeChanged,
            .selectedFlagsChanged,
            .includeFlagMatchModeChanged,
            .selectedImportanceUrgencyFilterChanged,
            .mediaFilterChanged:
            return .timelineFilterChanged
        default:
            return nil
        }
    }

    private func performanceInteraction(
        for action: StatsFeature.Action
    ) -> RoutinaPerformanceInteraction? {
        switch action {
        case .setFilterSheet(true):
            return .statsFilterOpened
        case .clearFilters:
            return .statsFilterCleared
        case .selectedRangeChanged,
            .taskTypeFilterChanged,
            .selectedTagChanged,
            .selectedTagsChanged,
            .includeTagMatchModeChanged,
            .advancedQueryChanged,
            .selectedImportanceUrgencyFilterChanged,
            .excludedTagsChanged,
            .excludeTagMatchModeChanged,
            .selectedFlagsChanged,
            .includeFlagMatchModeChanged,
            .excludedFlagsChanged,
            .excludeFlagMatchModeChanged:
            return .statsFilterChanged
        default:
            return nil
        }
    }

    private func applyTemporaryViewState(_ persistedState: TemporaryViewState?, to state: inout State) {
        AppFeatureTemporaryViewStateSupport.apply(persistedState, to: &state)
    }

    private func resetTemporaryViewState(_ state: inout State) {
        AppFeatureTemporaryViewStateSupport.reset(&state, homeTaskListMode: .all)
        state.stats.isFilterSheetPresented = false
    }

    private func persistTemporaryViewState(_ state: State) {
        appSettingsClient.setTemporaryViewState(
            AppFeatureTemporaryViewStateSupport.makeTemporaryViewState(
                from: state,
                preserving: appSettingsClient.temporaryViewState()
            )
        )
    }

    private func handleDeepLink(_ deepLink: RoutinaDeepLink, state: inout State) -> Effect<Action> {
        if case .goal = deepLink,
            !appSettingsClient.goalsEnabled()
        {
            return .none
        }
        if case .event = deepLink,
            !appSettingsClient.eventEmotionActionsEnabled()
        {
            return .none
        }
        state.hasRestoredTemporaryViewState = true

        switch deepLink {
        case let .task(taskID):
            return openTaskDetails(taskID, state: &state)
        case let .goal(goalID):
            state.selectedTab = .goals
            state.pendingDeepLinkedTaskID = nil
            persistTemporaryViewState(state)
            return .send(.goals(.openGoalDeepLink(goalID)))
        case let .note(noteID):
            guard appSettingsClient.notesEnabled() else { return .none }
            state.selectedTab = .timeline
            state.pendingDeepLinkedTaskID = nil
            persistTemporaryViewState(state)
            return .send(.timeline(.openNoteDeepLink(noteID)))
        case let .event(eventID):
            state.selectedTab = .timeline
            state.pendingDeepLinkedTaskID = nil
            persistTemporaryViewState(state)
            return .send(.timeline(.openEventDeepLink(eventID)))
        case .sleep:
            state.selectedTab = .timeline
            state.pendingDeepLinkedTaskID = nil
            persistTemporaryViewState(state)
            return .none
        case .sprint:
            state.selectedTab = .home
            state.pendingDeepLinkedTaskID = nil
            persistTemporaryViewState(state)
            return .send(.home(.onAppear))
        }
    }

    private func openTaskDetails(_ taskID: UUID, state: inout State) -> Effect<Action> {
        state.hasRestoredTemporaryViewState = true
        state.selectedTab = .home
        persistTemporaryViewState(state)

        guard state.home.routineTasks.contains(where: { $0.id == taskID }) else {
            state.pendingDeepLinkedTaskID = taskID
            return .send(.home(.onAppear))
        }

        state.pendingDeepLinkedTaskID = nil
        return .send(.home(.setSelectedTask(taskID)))
    }
}

extension AppFeature.State: AppFeatureTemporaryViewState {}
