import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct AppFeature {

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .home
        var hasRestoredTemporaryViewState = false
        var isMacStatsSurfaceActive = false
        var pendingDeepLinkedTaskID: UUID?
        var pendingDeepLinkedSprintID: UUID?
        var home = HomeFeature.State()
        var goals = GoalsFeature.State()
        var timeline = TimelineFeature.State()
        var stats = StatsFeature.State()
        var settings = SettingsFeature.State()
        var backlog = BacklogFeature.State()
        var taskRanking = TaskRankingFeature.State()
    }

    @CasePathable
    enum Action: Equatable {
        case tabSelected(Tab)
        case home(HomeFeature.Action)
        case goals(GoalsFeature.Action)
        case timeline(TimelineFeature.Action)
        case stats(StatsFeature.Action)
        case settings(SettingsFeature.Action)
        case backlog(BacklogFeature.Action)
        case taskRanking(TaskRankingFeature.Action)
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
        Reduce { state, action in
            if let interaction = performanceInteraction(for: action) {
                RoutinaPerformanceProfiler.shared.recordInteraction(interaction)
            }

            switch action {
            case .tabSelected(let tab):
                state.selectedTab = tab
                persistTemporaryViewState(state)
                return .none
            case let .openDeepLink(deepLink):
                return handleDeepLink(deepLink, state: &state)
            case let .home(.tasksLoadedSuccessfully(tasks, _, _, _, _)):
                guard let taskID = state.pendingDeepLinkedTaskID,
                      tasks.contains(where: { $0.id == taskID }) else {
                    return .none
                }
                state.pendingDeepLinkedTaskID = nil
                state.selectedTab = .home
                persistTemporaryViewState(state)
                return .send(.home(.openTaskDeepLink(taskID)))
            case let .home(.sprintBoardLoaded(sprintBoardData)):
                return openPendingSprintDeepLinkIfPossible(sprintBoardData, state: &state)
            case let .home(.sprintBoardLoadedFromStorage(sprintBoardData, _)):
                return openPendingSprintDeepLinkIfPossible(sprintBoardData, state: &state)
            case let .home(.macSidebarModeChanged(mode)):
                let isEnteringStats = mode == .stats && !state.isMacStatsSurfaceActive
                state.isMacStatsSurfaceActive = mode == .stats
                return isEnteringStats ? .send(.stats(.dataRefreshRequested)) : .none
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
                let timelineBoardSprints = state.timeline.boardSprints
                let timelineAwaySessions = state.timeline.awaySessions
                let timelineFileAttachmentTaskIDs = state.timeline.fileAttachmentTaskIDs
                let timelineNoteAttachmentNoteIDs = state.timeline.noteAttachmentNoteIDs
                let statsTasks = state.stats.tasks
                let statsLogs = state.stats.logs
                let statsFocusSessions = state.stats.focusSessions
                let statsSprintFocusSessions = state.stats.sprintFocusSessions
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
                 .timeline(.excludedTagsChanged),
                 .timeline(.excludeTagMatchModeChanged),
                 .timeline(.selectedFlagsChanged),
                 .timeline(.includeFlagMatchModeChanged),
                 .timeline(.selectedImportanceUrgencyFilterChanged),
                 .timeline(.mediaFilterChanged),
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
                state.home.tagColors = appSettingsClient.tagColors()
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
        case .setAddRoutineSheet(true), .openAddTaskSheet, .openAddTaskInCustomSection:
            return .taskComposerOpened
        case .setAddRoutineSheet(false):
            return .taskComposerClosed
        case .taskListModeChanged, .taskListModeFilterChanged:
            return .taskListModeChanged
        case .setMacFilterDetailPresented(true):
            return .homeFilterOpened
        case .setMacFilterDetailPresented(false):
            return nil
        case .clearTaskListAndSharedFilters:
            return .homeFilterCleared
        case .clearTimelineAndSharedFilters:
            return .timelineFilterCleared
        case .selectedFilterChanged,
             .advancedQueryChanged,
             .selectedTagChanged,
             .selectedTagsChanged,
             .taskDetailTagFilterTapped,
             .includeTagMatchModeChanged,
             .selectedFlagsChanged,
             .includeFlagMatchModeChanged,
             .excludedFlagsChanged,
             .excludeFlagMatchModeChanged,
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
        case .markTaskDone, .confirmAssumedTaskDone:
            return .taskMarkedDone
        case .markTaskMissed, .markAssumedTaskMissed:
            return .taskMarkedMissed
        case .markTaskCanceled:
            return .taskMarkedCanceled
        case .pauseTask:
            return .taskPaused
        case .resumeTask:
            return .taskResumed
        case .planTask:
            return .taskPlanned
        case let .macSidebarModeChanged(mode):
            return RoutinaPerformanceInteraction.macSidebar(named: mode.rawValue)
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
        case .clearFilters:
            return .statsFilterCleared
        case .selectedRangeChanged,
             .taskTypeFilterChanged,
             .createdChartTaskTypeFilterChanged,
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
        state.hasRestoredTemporaryViewState = true

        switch deepLink {
        case let .task(taskID):
            state.selectedTab = .home
            state.pendingDeepLinkedSprintID = nil
            persistTemporaryViewState(state)

            guard state.home.routineTasks.contains(where: { $0.id == taskID }) else {
                state.pendingDeepLinkedTaskID = taskID
                return .send(.home(.onAppear))
            }

            state.pendingDeepLinkedTaskID = nil
            return .send(.home(.openTaskDeepLink(taskID)))
        case let .goal(goalID):
            state.selectedTab = .home
            state.pendingDeepLinkedTaskID = nil
            state.pendingDeepLinkedSprintID = nil
            persistTemporaryViewState(state)
            return .concatenate(
                .send(.home(.macSidebarModeChanged(.goals))),
                .send(.goals(.openGoalDeepLink(goalID)))
            )
        case let .note(noteID):
            guard appSettingsClient.notesEnabled() else { return .none }
            state.selectedTab = .home
            state.pendingDeepLinkedTaskID = nil
            state.pendingDeepLinkedSprintID = nil
            persistTemporaryViewState(state)
            return .send(.home(.openNoteDeepLink(noteID)))
        case let .event(eventID):
            state.selectedTab = .home
            state.pendingDeepLinkedTaskID = nil
            state.pendingDeepLinkedSprintID = nil
            persistTemporaryViewState(state)
            return .send(.home(.openEventDeepLink(eventID)))
        case let .sleep(sleepID):
            state.selectedTab = .home
            state.pendingDeepLinkedTaskID = nil
            state.pendingDeepLinkedSprintID = nil
            persistTemporaryViewState(state)
            return .send(.home(.openSleepDeepLink(sleepID)))
        case let .sprint(sprintID):
            state.selectedTab = .home
            state.pendingDeepLinkedTaskID = nil
            persistTemporaryViewState(state)

            guard state.home.sprintBoardData.sprints.contains(where: { $0.id == sprintID }) else {
                state.pendingDeepLinkedSprintID = sprintID
                return .send(.home(.onAppear))
            }

            state.pendingDeepLinkedSprintID = nil
            return .send(.home(.openSprintDeepLink(sprintID)))
        }
    }

    private func openPendingSprintDeepLinkIfPossible(
        _ sprintBoardData: SprintBoardData,
        state: inout State
    ) -> Effect<Action> {
        guard let sprintID = state.pendingDeepLinkedSprintID,
              sprintBoardData.sprints.contains(where: { $0.id == sprintID }) else {
            return .none
        }

        state.pendingDeepLinkedSprintID = nil
        state.selectedTab = .home
        persistTemporaryViewState(state)
        return .send(.home(.openSprintDeepLink(sprintID)))
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
        var createdChartTaskTypeFilter: StatsTaskTypeFilter = .all
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
        var tagSummaries: [RoutineTagSummary] = []
        var availableExcludeTags: [String] = []
        var availableFlags: [String] = []
        var availableExcludeFlags: [String] = []
        var tagColors: [String: String] = [:]
        var relatedTagRules: [RoutineRelatedTagRule] = []
        var taskCountForSelectedTypeFilter: Int = 0
        var filteredTaskCount: Int = 0
        var filteredTaskIDs: Set<UUID> = []
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
        case activeFocusRefreshTimerTick
        case dataRefreshFailed
        case onAppear
        case selectedRangeChanged(DoneChartRange)
        case taskTypeFilterChanged(StatsTaskTypeFilter)
        case createdChartTaskTypeFilterChanged(StatsTaskTypeFilter)
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
            case let .setData(tasks, logs, focusSessions, sprintFocusSessions, boardSprints, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions):
                state.hasLoadedDataSnapshot = true
                state.tasks = tasks
                state.logs = logs
                state.focusSessions = focusSessions
                state.sprintFocusSessions = sprintFocusSessions
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

            case .activeFocusRefreshTimerTick:
                let hasActiveUnpausedFocus = state.focusSessions.contains {
                    $0.state == .active && !$0.isPaused
                } || state.sprintFocusSessions.contains {
                    $0.isActive && !$0.isPaused
                }
                return hasActiveUnpausedFocus ? refreshDataEffect() : .none

            case .dataRefreshFailed:
                return .none

            case .onAppear:
                let activeFocusTimer = activeFocusRefreshTimerEffect()
                state.relatedTagRules = RoutineTagRelations.sanitized(
                    appSettingsClient.relatedTagRules()
                    + RoutineTagRelations.learnedRules(from: state.tasks.map(\.tags))
                )
                state.tagColors = appSettingsClient.tagColors()
                state.isGitFeaturesEnabled = appSettingsClient.gitFeaturesEnabled()
                guard !state.hasLoadedDataSnapshot else {
                    return activeFocusTimer
                }
                guard state.isGitFeaturesEnabled else {
                    state.gitHubConnection = .disconnected
                    state.isGitHubStatsLoading = false
                    state.gitHubStats = nil
                    state.gitHubStatsErrorMessage = nil
                    return .merge(refreshDataEffect(), activeFocusTimer)
                }
                state.gitHubConnection = gitHubStatsClient.loadConnectionStatus()
                if !state.gitHubConnection.isConnected {
                    state.isGitHubStatsLoading = false
                    state.gitHubStats = nil
                    state.gitHubStatsErrorMessage = nil
                }
                return .merge(
                    refreshDataEffect(),
                    refreshGitHubStatsEffect(state: &state),
                    activeFocusTimer
                )

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

            case let .createdChartTaskTypeFilterChanged(filter):
                state.createdChartTaskTypeFilter = filter
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
                state.createdChartTaskTypeFilter = .all
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
        case activeFocusRefreshTimer
    }

    private func activeFocusRefreshTimerEffect() -> Effect<Action> {
        .run { send in
            while !Task.isCancelled {
                try await continuousClock.sleep(for: .seconds(30))
                await send(.activeFocusRefreshTimerTick)
            }
        }
        .cancellable(id: CancelID.activeFocusRefreshTimer, cancelInFlight: true)
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
            } else {
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
            createdChartTaskTypeFilter: state.createdChartTaskTypeFilter,
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
        state.setSelectedTags(derivedState.selectedTags)
        state.excludedTags = derivedState.excludedTags
        state.selectedFlags = derivedState.selectedFlags
        state.excludedFlags = derivedState.excludedFlags
        state.tagSummaries = derivedState.tagSummaries
        state.availableExcludeTags = derivedState.availableExcludeTags
        state.availableFlags = derivedState.availableFlags
        state.availableExcludeFlags = derivedState.availableExcludeFlags
        state.taskCountForSelectedTypeFilter = derivedState.taskCountForSelectedTypeFilter
        state.filteredTaskCount = derivedState.filteredTaskCount
        state.filteredTaskIDs = derivedState.filteredTaskIDs
        state.metrics = derivedState.metrics
    }
}

extension AppFeature.State: AppFeatureTemporaryViewState {}

extension StatsFeature.State: AppStatsFeatureTemporaryViewState {}
