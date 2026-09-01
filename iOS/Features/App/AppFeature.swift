import ComposableArchitecture
import Foundation
import SwiftData

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
                      tasks.contains(where: { $0.id == taskID }) else {
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
                    .send(.timeline(.setData(
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
                    .send(.stats(.setData(
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
           !appSettingsClient.goalsEnabled() {
            return .none
        }
        if case .event = deepLink,
           !appSettingsClient.eventEmotionActionsEnabled() {
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

@Reducer
struct StatsFeature {
    typealias Metrics = StatsFeatureMetrics

    @ObservableState
    struct State: Equatable {
        var tasks: [RoutineTask] = []
        var logs: [RoutineLog] = []
        var focusSessions: [FocusSession] = []
        var sprintFocusSessions: [SprintFocusSessionRecord] = []
        var focusSessionEvents: [FocusSessionActionEvent] = []
        var boardSprints: [BoardSprintRecord] = []
        var sleepSessions: [SleepSession] = []
        var awaySessions: [AwaySession] = []
        var emotionLogs: [EmotionLog] = []
        var notes: [RoutineNote] = []
        var events: [RoutineEvent] = []
        var noteAttachmentNoteIDs: Set<UUID> = []
        var goals: [RoutineGoal] = []
        var places: [RoutinePlace] = []
        var placeCheckInSessions: [PlaceCheckInSession] = []
        var selectedRange: DoneChartRange = .week
        var taskTypeFilter: StatsTaskTypeFilter = .all
        var isFilterSheetPresented: Bool = false
        var selectedTag: String?
        var selectedTags: Set<String> = []
        var includeTagMatchMode: RoutineTagMatchMode = .all
        var excludedTags: Set<String> = []
        var excludeTagMatchMode: RoutineTagMatchMode = .any
        var selectedFlags: Set<String> = []
        var includeFlagMatchMode: RoutineTagMatchMode = .all
        var excludedFlags: Set<String> = []
        var excludeFlagMatchMode: RoutineTagMatchMode = .any
        var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
        var advancedQuery: String = ""
        var availableTags: [String] = []
        var availableExcludeTags: [String] = []
        var availableFlags: [String] = []
        var availableExcludeFlags: [String] = []
        var tagColors: [String: String] = [:]
        var relatedTagRules: [RoutineRelatedTagRule] = []
        var filteredTaskCount: Int = 0
        var filteredTaskIDs: Set<UUID> = []
        var hasOneOffTasks = false
        var unassignedFocusSessions: [FocusSession] = []
        var assignableFocusTasks: [RoutineTask] = []
        var activeFocusSprints: [BoardSprintRecord] = []
        var metrics = Metrics()
        var achievementSnapshot = StatsAchievementPresentationSnapshot()
        var gitHubConnection = GitHubConnectionStatus.disconnected
        var gitHubStats: GitHubStatsSnapshot?
        var isGitHubStatsLoading: Bool = false
        var gitHubStatsErrorMessage: String?
        var isGitFeaturesEnabled: Bool = false
        var hasLoadedDataSnapshot = false

        var hasActiveFilters: Bool {
            selectedRange != .week
                || taskTypeFilter != .all
                || !advancedQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !effectiveSelectedTags.isEmpty
                || !excludedTags.isEmpty
                || !selectedFlags.isEmpty
                || !excludedFlags.isEmpty
                || selectedImportanceUrgencyFilter != nil
        }

        var effectiveSelectedTags: Set<String> {
            if !selectedTags.isEmpty { return selectedTags }
            return selectedTag.map { [$0] } ?? []
        }

        mutating func setSelectedTag(_ tag: String?) {
            selectedTag = tag
            selectedTags = tag.map { [$0] } ?? []
        }

        mutating func setSelectedTags(_ tags: Set<String>) {
            selectedTags = tags
            selectedTag = tags.sorted().first
        }
    }

    enum Action: Equatable {
        case setData(
            tasks: [RoutineTask],
            logs: [RoutineLog],
            focusSessions: [FocusSession],
            sprintFocusSessions: [SprintFocusSessionRecord] = [],
            focusSessionEvents: [FocusSessionActionEvent] = [],
            boardSprints: [BoardSprintRecord] = [],
            sleepSessions: [SleepSession] = [],
            awaySessions: [AwaySession] = [],
            emotionLogs: [EmotionLog] = [],
            notes: [RoutineNote] = [],
            events: [RoutineEvent] = [],
            noteAttachmentNoteIDs: Set<UUID> = [],
            goals: [RoutineGoal] = [],
            places: [RoutinePlace] = [],
            placeCheckInSessions: [PlaceCheckInSession] = []
        )
        case dataRefreshRequested
        case dataRefreshDebounceCompleted
        case dataRefreshFailed
        case onAppear
        case selectedRangeChanged(DoneChartRange)
        case taskTypeFilterChanged(StatsTaskTypeFilter)
        case selectedTagChanged(String?)
        case selectedTagsChanged(Set<String>)
        case includeTagMatchModeChanged(RoutineTagMatchMode)
        case advancedQueryChanged(String)
        case selectedImportanceUrgencyFilterChanged(ImportanceUrgencyFilterCell?)
        case excludedTagsChanged(Set<String>)
        case excludeTagMatchModeChanged(RoutineTagMatchMode)
        case selectedFlagsChanged(Set<String>)
        case includeFlagMatchModeChanged(RoutineTagMatchMode)
        case excludedFlagsChanged(Set<String>)
        case excludeFlagMatchModeChanged(RoutineTagMatchMode)
        case setFilterSheet(Bool)
        case gitHubStatsRefreshRequested
        case gitHubStatsLoaded(GitHubStatsSnapshot)
        case gitHubStatsFailed(String)
        case clearFilters
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.continuousClock) var continuousClock
    @Dependency(\.date.now) var now
    @Dependency(\.gitHubStatsClient) var gitHubStatsClient
    @Dependency(\.gitLabStatsClient) var gitLabStatsClient
    @Dependency(\.appSettingsClient) var appSettingsClient
    @Dependency(\.modelContext) var modelContext

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setData(tasks, logs, focusSessions, sprintFocusSessions, focusSessionEvents, boardSprints, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions):
                state.hasLoadedDataSnapshot = true
                state.tasks = tasks
                state.logs = logs
                state.focusSessions = focusSessions
                state.sprintFocusSessions = sprintFocusSessions
                state.focusSessionEvents = focusSessionEvents
                state.boardSprints = boardSprints
                state.sleepSessions = sleepSessions
                state.awaySessions = awaySessions
                state.emotionLogs = emotionLogs
                state.notes = notes
                state.events = events
                state.noteAttachmentNoteIDs = noteAttachmentNoteIDs
                state.goals = goals
                state.places = places
                state.placeCheckInSessions = placeCheckInSessions
                state.hasOneOffTasks = tasks.contains(where: \.isOneOffTask)
                state.unassignedFocusSessions = focusSessions
                    .filter { $0.isUnassigned && $0.state == .completed }
                    .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
                state.assignableFocusTasks = tasks
                    .filter { task in
                        !task.isArchived(referenceDate: now, calendar: calendar)
                            && !task.isCompletedOneOff
                            && !task.isCanceledOneOff
                    }
                    .sorted { lhs, rhs in
                        let lhsTitle = RoutineTask.trimmedName(lhs.name) ?? "Untitled task"
                        let rhsTitle = RoutineTask.trimmedName(rhs.name) ?? "Untitled task"
                        return lhsTitle.localizedCaseInsensitiveCompare(rhsTitle) == .orderedAscending
                    }
                state.activeFocusSprints = boardSprints
                    .filter { $0.statusRawValue == SprintStatus.active.rawValue }
                    .sorted { lhs, rhs in
                        let lhsTitle = lhs.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let rhsTitle = rhs.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        return lhsTitle.localizedCaseInsensitiveCompare(rhsTitle) == .orderedAscending
                    }
                state.relatedTagRules = RoutineTagRelations.sanitized(
                    appSettingsClient.relatedTagRules()
                    + RoutineTagRelations.learnedRules(from: tasks.map(\.tags))
                )
                state.tagColors = appSettingsClient.tagColors()
                state.achievementSnapshot = StatsAchievementPresentationSnapshot.build(
                    focusSessions: focusSessions,
                    sleepSessions: sleepSessions,
                    awaySessions: awaySessions,
                    logs: logs,
                    emotionLogs: emotionLogs,
                    notes: notes,
                    noteAttachmentNoteIDs: noteAttachmentNoteIDs,
                    goals: goals,
                    places: places,
                    placeCheckInSessions: placeCheckInSessions,
                    referenceDate: now,
                    calendar: calendar
                )
                refreshDerivedState(&state)
                return .none

            case .dataRefreshRequested:
                return .run { send in
                    try await continuousClock.sleep(for: .seconds(1))
                    await send(.dataRefreshDebounceCompleted)
                }
                .cancellable(id: CancelID.dataRefreshDebounce, cancelInFlight: true)

            case .dataRefreshDebounceCompleted:
                return refreshDataEffect()

            case .dataRefreshFailed:
                return .none

            case .onAppear:
                state.relatedTagRules = RoutineTagRelations.sanitized(
                    appSettingsClient.relatedTagRules()
                    + RoutineTagRelations.learnedRules(from: state.tasks.map(\.tags))
                )
                state.tagColors = appSettingsClient.tagColors()
                var effects: [Effect<Action>] = []
                state.isGitFeaturesEnabled = appSettingsClient.gitFeaturesEnabled()
                guard state.isGitFeaturesEnabled else {
                    state.gitHubConnection = .disconnected
                    state.isGitHubStatsLoading = false
                    state.gitHubStats = nil
                    state.gitHubStatsErrorMessage = nil
                    if !state.hasLoadedDataSnapshot {
                        effects.append(refreshDataEffect())
                    }
                    return .merge(effects)
                }
                state.gitHubConnection = gitHubStatsClient.loadConnectionStatus()
                if !state.gitHubConnection.isConnected {
                    state.isGitHubStatsLoading = false
                    state.gitHubStats = nil
                    state.gitHubStatsErrorMessage = nil
                }
                effects.append(refreshGitHubStatsEffect(state: &state))
                if !state.hasLoadedDataSnapshot {
                    effects.append(refreshDataEffect())
                }
                return .merge(effects)

            case let .selectedRangeChanged(range):
                state.selectedRange = range
                refreshDerivedState(&state)
                guard state.isGitFeaturesEnabled, state.gitHubConnection.isConnected else {
                    return .none
                }
                return refreshGitHubStatsEffect(state: &state, skipGitLab: true)

            case let .taskTypeFilterChanged(filter):
                state.taskTypeFilter = filter
                refreshDerivedState(&state)
                return .none

            case let .selectedTagChanged(tag):
                state.setSelectedTag(tag)
                refreshDerivedState(&state)
                return .none

            case let .selectedTagsChanged(tags):
                state.setSelectedTags(tags)
                refreshDerivedState(&state)
                return .none

            case let .includeTagMatchModeChanged(mode):
                state.includeTagMatchMode = mode
                refreshDerivedState(&state)
                return .none

            case let .advancedQueryChanged(query):
                state.advancedQuery = query
                refreshDerivedState(&state)
                return .none

            case let .selectedImportanceUrgencyFilterChanged(filter):
                state.selectedImportanceUrgencyFilter = ImportanceUrgencyFilterCell.normalized(filter)
                refreshDerivedState(&state)
                return .none

            case let .excludedTagsChanged(tags):
                state.excludedTags = tags
                refreshDerivedState(&state)
                return .none

            case let .excludeTagMatchModeChanged(mode):
                state.excludeTagMatchMode = mode
                refreshDerivedState(&state)
                return .none

            case let .selectedFlagsChanged(flags):
                state.selectedFlags = flags
                refreshDerivedState(&state)
                return .none

            case let .includeFlagMatchModeChanged(mode):
                state.includeFlagMatchMode = mode
                refreshDerivedState(&state)
                return .none

            case let .excludedFlagsChanged(flags):
                state.excludedFlags = flags
                refreshDerivedState(&state)
                return .none

            case let .excludeFlagMatchModeChanged(mode):
                state.excludeFlagMatchMode = mode
                refreshDerivedState(&state)
                return .none

            case let .setFilterSheet(isPresented):
                state.isFilterSheetPresented = isPresented
                return .none

            case .gitHubStatsRefreshRequested:
                state.isGitFeaturesEnabled = appSettingsClient.gitFeaturesEnabled()
                guard state.isGitFeaturesEnabled else {
                    state.gitHubConnection = .disconnected
                    state.gitHubStats = nil
                    state.gitHubStatsErrorMessage = nil
                    state.isGitHubStatsLoading = false
                    return .none
                }
                state.gitHubConnection = gitHubStatsClient.loadConnectionStatus()
                if !state.gitHubConnection.isConnected {
                    state.gitHubStats = nil
                    state.gitHubStatsErrorMessage = nil
                    state.isGitHubStatsLoading = false
                }
                return refreshGitHubStatsEffect(state: &state)

            case let .gitHubStatsLoaded(stats):
                state.isGitHubStatsLoading = false
                state.gitHubStats = stats
                state.gitHubStatsErrorMessage = nil
                return .none

            case let .gitHubStatsFailed(message):
                state.isGitHubStatsLoading = false
                state.gitHubStatsErrorMessage = message
                return .none

            case .clearFilters:
                state.selectedRange = .week
                state.taskTypeFilter = .all
                state.setSelectedTag(nil)
                state.includeTagMatchMode = .all
                state.excludedTags = []
                state.excludeTagMatchMode = .any
                state.selectedFlags = []
                state.includeFlagMatchMode = .all
                state.excludedFlags = []
                state.excludeFlagMatchMode = .any
                state.selectedImportanceUrgencyFilter = nil
                state.advancedQuery = ""
                refreshDerivedState(&state)
                return .none
            }
        }
    }

    private enum CancelID {
        case dataRefreshDebounce
    }

    private func refreshDataEffect() -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                let notesEnabled = appSettingsClient.notesEnabled()
                let placesEnabled = appSettingsClient.placesEnabled()
                let awayEnabled = appSettingsClient.awayEnabled()

                let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                let logs = try context.fetch(FetchDescriptor<RoutineLog>())
                let focusSessions = try context.fetch(FetchDescriptor<FocusSession>())
                let sprintFocusSessions = try context.fetch(FetchDescriptor<SprintFocusSessionRecord>())
                let focusSessionEvents = try FocusSessionActionEvent.fetch(from: context)
                let boardSprints = try context.fetch(FetchDescriptor<BoardSprintRecord>())
                let sleepSessions = try context.fetch(FetchDescriptor<SleepSession>())
                let awaySessions = try context.fetch(FetchDescriptor<AwaySession>())
                let emotionLogs = try context.fetch(FetchDescriptor<EmotionLog>())
                let notes = try context.fetch(FetchDescriptor<RoutineNote>())
                let events = try context.fetch(FetchDescriptor<RoutineEvent>())
                let noteAttachments = try context.fetch(FetchDescriptor<RoutineNoteAttachment>())
                let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
                let places = try context.fetch(FetchDescriptor<RoutinePlace>())
                let placeCheckInSessions = try context.fetch(FetchDescriptor<PlaceCheckInSession>())

                send(.setData(
                    tasks: tasks,
                    logs: logs,
                    focusSessions: focusSessions,
                    sprintFocusSessions: sprintFocusSessions,
                    focusSessionEvents: focusSessionEvents,
                    boardSprints: boardSprints,
                    sleepSessions: awayEnabled ? sleepSessions : [],
                    awaySessions: awayEnabled ? awaySessions : [],
                    emotionLogs: emotionLogs,
                    notes: notesEnabled ? notes : [],
                    events: events,
                    noteAttachmentNoteIDs: notesEnabled ? Set(noteAttachments.map(\.noteID)) : [],
                    goals: goals,
                    places: placesEnabled ? places : [],
                    placeCheckInSessions: placesEnabled ? placeCheckInSessions : []
                ))
            } catch {
                send(.dataRefreshFailed)
            }
        }
    }

    private func refreshGitHubStatsEffect(
        state: inout State,
        skipGitLab: Bool = false
    ) -> Effect<Action> {
        let isGitHubConnected = state.gitHubConnection.isConnected
        guard state.isGitFeaturesEnabled else {
            state.isGitHubStatsLoading = false
            state.gitHubStatsErrorMessage = nil
            return .none
        }
        if isGitHubConnected {
            state.isGitHubStatsLoading = true
            state.gitHubStatsErrorMessage = nil
        }
        let range = state.selectedRange
        let isProfile = state.gitHubConnection.scope == .profile

        return .run { send in
            if isGitHubConnected {
                do {
                    let stats = try await self.gitHubStatsClient.fetchStats(range)
                    await send(.gitHubStatsLoaded(stats))
                } catch {
                    await send(.gitHubStatsFailed(error.localizedDescription))
                }
            }
            if isGitHubConnected, isProfile {
                do {
                    let data = try await self.gitHubStatsClient.fetchContributionYear()
                    GitHubWidgetService.writeAndReload(data)
                } catch {
                    NSLog("GitHubWidgetService: fetchContributionYear failed — \(error.localizedDescription)")
                }
            } else if isGitHubConnected {
                NSLog("GitHubWidgetService: skipping widget fetch — scope is not profile")
            }

            if !skipGitLab, self.gitLabStatsClient.loadConnectionStatus().isConnected {
                do {
                    let data = try await self.gitLabStatsClient.fetchContributionYear()
                    GitLabWidgetService.writeAndReload(data)
                } catch {
                    NSLog("GitLabWidgetService: fetchContributionYear failed — \(error.localizedDescription)")
                }
            } else if !skipGitLab {
                NSLog("GitLabWidgetService: skipping widget fetch — not connected")
            }
        }
    }

    private func refreshDerivedState(_ state: inout State) {
        let derivedState = StatsFeatureDerivedStateBuilder.build(
            tasks: state.tasks,
            logs: state.logs,
            focusSessions: state.focusSessions,
            sprintFocusSessions: state.sprintFocusSessions,
            focusSessionEvents: state.focusSessionEvents,
            boardSprints: state.boardSprints,
            sleepSessions: state.sleepSessions,
            awaySessions: state.awaySessions,
            emotionLogs: state.emotionLogs,
            notes: state.notes,
            events: state.events,
            noteAttachmentNoteIDs: state.noteAttachmentNoteIDs,
            goals: state.goals,
            selectedRange: state.selectedRange,
            taskTypeFilter: state.taskTypeFilter,
            selectedImportanceUrgencyFilter: state.selectedImportanceUrgencyFilter,
            advancedQuery: state.advancedQuery,
            selectedTags: state.effectiveSelectedTags,
            includeTagMatchMode: state.includeTagMatchMode,
            excludedTags: state.excludedTags,
            excludeTagMatchMode: state.excludeTagMatchMode,
            selectedFlags: state.selectedFlags,
            includeFlagMatchMode: state.includeFlagMatchMode,
            excludedFlags: state.excludedFlags,
            excludeFlagMatchMode: state.excludeFlagMatchMode,
            tagColors: state.tagColors,
            referenceDate: state.selectedRange.referenceDate(relativeTo: now),
            calendar: calendar
        )
        state.availableTags = derivedState.availableTags
        state.availableExcludeTags = derivedState.availableExcludeTags
        state.availableFlags = derivedState.availableFlags
        state.availableExcludeFlags = derivedState.availableExcludeFlags
        state.setSelectedTags(derivedState.selectedTags)
        state.excludedTags = derivedState.excludedTags
        state.selectedFlags = derivedState.selectedFlags
        state.excludedFlags = derivedState.excludedFlags
        state.filteredTaskCount = derivedState.filteredTaskCount
        state.filteredTaskIDs = derivedState.filteredTaskIDs
        state.metrics = derivedState.metrics
    }
}

extension AppFeature.State: AppFeatureTemporaryViewState {}

extension StatsFeature.State: AppStatsFeatureTemporaryViewState {}
